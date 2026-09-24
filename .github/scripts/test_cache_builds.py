from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import cache_builds as cache


NOW = datetime(2026, 1, 1, tzinfo=timezone.utc)


def path(name):
    return f"/nix/store/{'0' * 32}-{name}"


def event(name="package", seconds=90, **overrides):
    return {
        "v": "1", "c": "BuiltPathResponseEventV1", "drv": path(name + ".drv"),
        "outputs": [path(name)],
        "timing": {"startTime": NOW.isoformat(), "durationSeconds": seconds},
        **overrides,
    }


class CommandLineTest(unittest.TestCase):
    def test_default_policy(self):
        argv = ["cache_builds.py", "select", "--directory", "report",
                "--cache", "johnpertoft"]
        with patch.object(cache.sys, "argv", argv), patch.object(cache, "select") as select:
            self.assertEqual(cache.main(), 0)
        select.assert_called_once_with(Path("report"), "johnpertoft", 300, 1024, 1024)


class EventsTest(unittest.TestCase):
    def parse(self, events):
        return cache.executed_builds(events, NOW, NOW + timedelta(minutes=5))

    def test_only_successful_timed_builds(self):
        builds = self.parse([
            event(), event("download", timing=None),
            event("failed", c="BuildFailureResponseEventV1"),
        ])
        self.assertEqual([build["outputs"] for build in builds], [[path("package")]])

    def test_deduplicates_without_adding_elapsed_times(self):
        self.assertEqual(self.parse([event(), event()])[0]["seconds"], 90)

    def test_excludes_events_outside_invocation(self):
        early = event(timing={"startTime": (NOW - timedelta(seconds=1)).isoformat(),
                              "durationSeconds": 100})
        late = event(timing={"startTime": (NOW + timedelta(days=1)).isoformat(),
                             "durationSeconds": 100})
        self.assertEqual(self.parse([early, late]), [])

    def test_multiple_outputs(self):
        outputs = [path("package"), path("package-dev")]
        self.assertEqual(self.parse([event(outputs=outputs)])[0]["outputs"], outputs)
        self.assertEqual(self.parse([event(), event(outputs=[path("package-dev")])])[0]["outputs"],
                         outputs)

    def test_rejects_invalid_or_changed_telemetry(self):
        invalid = [
            event(v="2"), event(c="BuiltPathResponseEventV2"),
            event(seconds=-1), event(seconds=float("nan")), event(seconds=True),
            event(outputs=["not a store path"]), event(outputs=[]),
        ]
        for record in invalid:
            with self.subTest(record=record), self.assertRaises(ValueError):
                self.parse([record])
        with self.assertRaises(ValueError):
            self.parse({})

    def test_failed_command_preserves_status_without_selecting(self):
        with tempfile.TemporaryDirectory() as temp, patch.object(
            cache, "recent_events", return_value=[]
        ), patch.object(cache.subprocess, "run", return_value=subprocess.CompletedProcess([], 7)):
            self.assertEqual(cache.record_build(Path(temp), ["nix", "build"]), 7)
            self.assertFalse((Path(temp) / "builds.json").exists())

    def test_preexisting_events_in_same_second_are_not_reused(self):
        record = event(timing={"startTime": datetime.now(timezone.utc).replace(
            microsecond=0).isoformat(), "durationSeconds": 0})
        with tempfile.TemporaryDirectory() as temp, patch.object(
            cache, "recent_events", return_value=[record]
        ), patch.object(cache.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)):
            self.assertEqual(cache.record_build(Path(temp), ["nix", "build"]), 0)
            self.assertEqual(json.loads((Path(temp) / "builds.json").read_text()), [])


class SelectionTest(unittest.TestCase):
    def setUp(self):
        self.builds = cache.executed_builds(
            [event("slow", 120), event("other", 90), event("fast", 59)],
            NOW, NOW + timedelta(minutes=5),
        )
        self.metadata = {
            build["drv"]: {"name": build["outputs"][0].split("-", 1)[1],
                           "outputs": {"out": {"path": build["outputs"][0]}}}
            for build in self.builds
        }
        self.closures = {
            path("slow"): {path("slow"): 10, path("shared"): 100, path("official"): 5000},
            path("other"): {path("other"): 20, path("shared"): 100},
        }

    def select(self, limit=250, budget=1024, roots=None):
        return cache.select_builds(
            self.builds, set(roots or []), self.metadata,
            lambda outputs: self.closures[outputs[0]],
            lambda paths: paths - {path("official")},
            60, limit, budget,
        )

    def test_threshold_and_shared_dependencies(self):
        result = self.select()
        self.assertEqual(result["selected_outputs"], [path("other"), path("slow")])
        self.assertEqual(result["additional_nar_bytes"], 130)
        self.assertEqual(result["additional_paths"], 3)
        self.assertEqual(result["decisions"][-1]["reason"], "below duration threshold")

    def test_duration_boundary_is_inclusive(self):
        self.builds[-1]["seconds"] = 60
        self.closures[path("fast")] = {path("fast"): 1}
        self.assertIn(path("fast"), self.select()["selected_outputs"])

    def test_configuration_root_is_never_selected(self):
        result = self.select(roots=[path("slow")])
        self.assertEqual(result["decisions"][0]["reason"], "configuration root")
        self.assertNotIn(path("slow"), result["selected_outputs"])

    def test_fixed_output_and_source_exclusions(self):
        self.metadata[path("slow.drv")]["outputs"] = {"out": {"hash": "sha256-example"}}
        self.metadata[path("other.drv")]["name"] = "project-source"
        result = self.select()
        self.assertEqual(result["selected_outputs"], [])
        self.assertEqual([item["reason"] for item in result["decisions"][:2]],
                         ["fixed-output fetch/build", "source-like derivation"])

    def test_large_third_party_dependency_cannot_bypass_cap(self):
        self.closures[path("slow")][path("cuda")] = 10000
        result = self.select()
        self.assertEqual(result["decisions"][0]["reason"],
                         "candidate closure exceeds size limit")
        self.assertEqual(result["selected_outputs"], [path("other")])

    def test_total_budget_and_boundary(self):
        result = self.select(limit=110, budget=110)
        self.assertEqual(result["selected_outputs"], [path("slow")])
        self.assertEqual(result["decisions"][1]["reason"], "job upload budget exhausted")

    def test_fully_cached_candidates_are_not_pushed(self):
        result = cache.select_builds(
            self.builds, set(), self.metadata, lambda outputs: {outputs[0]: 10},
            lambda paths: set(), 60, 250, 1024,
        )
        self.assertEqual(result["selected_outputs"], [])
        self.assertEqual(result["additional_nar_bytes"], 0)

    def test_no_executed_builds(self):
        result = cache.select_builds([], set(), {}, None, None, 60, 250, 1024)
        self.assertEqual(result["selected_outputs"], [])
        self.assertIn("0 outputs", cache.summary(result).replace("**", ""))


@unittest.skipUnless(os.environ.get("NIX_CACHE_INTEGRATION") == "1",
                     "Requires the CI Determinate Nix daemon")
class IntegrationTest(unittest.TestCase):
    def test_real_builds_queueing_cache_hits_and_failures(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            # Raw derivations avoid stdenv setup and use only bash/coreutils.
            expression = root / "probe.nix"
            expression.write_text("""
              let
                flake = builtins.getFlake %s;
                pkgs = flake.inputs.nixpkgs.legacyPackages.${builtins.currentSystem};
                make = name: script: builtins.derivation {
                  name = name + "-%s";
                  system = builtins.currentSystem;
                  builder = "${pkgs.bash}/bin/bash";
                  args = [ "-c" script ];
                };
                short = make "cache-probe-short" "${pkgs.coreutils}/bin/sleep 2; echo done > $out";
                long = make "cache-probe-long" "${pkgs.coreutils}/bin/sleep 4; echo done > $out";
              in {
                root = make "cache-probe-root" "echo ${short} ${long} > $out";
                failure = make "cache-probe-failure" "exit 7";
              }
            """ % (json.dumps(str(Path.cwd())), root.name))
            base = ["nix", "build", "--impure", "--file", str(expression), "--json",
                    "--max-jobs", "1", "--builders", "", "--no-link"]
            self.assertEqual(cache.record_build(root / "first", base + ["root"]), 0)
            builds = json.loads((root / "first" / "builds.json").read_text())
            probes = {build["drv"].split("cache-probe-", 1)[1].split("-", 1)[0]: build
                      for build in builds if "cache-probe-" in build["drv"]}
            self.assertEqual(set(probes), {"short", "long", "root"})
            self.assertGreaterEqual(probes["short"]["seconds"], 1)
            self.assertLess(probes["short"]["seconds"], 5)
            self.assertGreaterEqual(probes["long"]["seconds"], 3)
            self.assertLess(probes["long"]["seconds"], 7)
            metadata = cache.derivations([build["drv"] for build in probes.values()])
            self.assertEqual(len(metadata), 3)
            for build in probes.values():
                self.assertTrue(set(build["outputs"]) <= cache.closure(build["outputs"]).keys())
            cache.select(root / "first", "johnpertoft",
                         int(probes["short"]["seconds"]) + 1, 1, 1)
            selection = json.loads((root / "first" / "selection.json").read_text())
            self.assertEqual(selection["selected_outputs"], probes["long"]["outputs"])
            self.assertLess(selection["additional_nar_bytes"], cache.MIB)
            self.assertEqual(cache.record_build(root / "cached", base + ["root"]), 0)
            cached = json.loads((root / "cached" / "builds.json").read_text())
            self.assertFalse(any("cache-probe-" in build["drv"] for build in cached))
            self.assertNotEqual(cache.record_build(root / "failed", base + ["failure"]), 0)
            self.assertFalse((root / "failed" / "builds.json").exists())


if __name__ == "__main__":
    unittest.main()
