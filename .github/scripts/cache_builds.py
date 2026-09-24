"""Record executed Nix builds and select bounded closures for Cachix publication."""

import argparse
from datetime import datetime, timezone
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys


MIB = 1024 * 1024
STORE_PATH = re.compile(r"/nix/store/[0-9a-z]{32}-[^/\s]+")
DAEMON_SOCKET = "/nix/var/determinate/determinate-nixd.socket"


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def run_json(command):
    return json.loads(subprocess.check_output(command, text=True))


def store_path(value):
    if not isinstance(value, str) or not STORE_PATH.fullmatch(value):
        raise ValueError(f"Invalid store path: {value!r}")
    return value


def parse_time(value):
    timestamp = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if timestamp.tzinfo is None:
        raise ValueError(f"Timestamp has no timezone: {value}")
    return timestamp


def recent_events(since):
    # Use the same local API as nix-installer-action's build summary, not
    # internal-json activity durations, which can include build-slot waiting.
    return run_json([
        "curl", "--fail", "--silent", "--show-error", "--max-time", "30",
        "--unix-socket", DAEMON_SOCKET, "--get",
        "--data-urlencode", f"since={since.isoformat()}",
        "http://localhost/events/recent",
    ])


def executed_builds(events, since, until):
    if not isinstance(events, list):
        raise ValueError("Expected an array from Determinate's events API")
    builds = {}
    for event in events:
        if not isinstance(event, dict):
            raise ValueError("Invalid build event")
        if event.get("c") != "BuiltPathResponseEventV1":
            if str(event.get("c", "")).startswith("BuiltPathResponseEvent"):
                raise ValueError(f"Unsupported build event: {event['c']}")
            continue
        if event.get("v") != "1":
            raise ValueError("Unsupported build event version")
        timing = event["timing"]
        if timing is None:
            continue
        start = parse_time(timing["startTime"])
        duration = timing["durationSeconds"]
        if (isinstance(duration, bool) or not isinstance(duration, (int, float))
                or not math.isfinite(duration) or duration < 0):
            raise ValueError(f"Invalid build duration: {duration!r}")
        if not since <= start <= until:
            continue
        drv = store_path(event["drv"])
        outputs = event["outputs"]
        if not drv.endswith(".drv") or not isinstance(outputs, list) or not outputs:
            raise ValueError(f"Invalid executed build: {event!r}")
        outputs = sorted({store_path(path) for path in outputs})
        # Deduplicate event replays; never add their durations together.
        if drv in builds:
            outputs = sorted(set(outputs) | set(builds[drv]["outputs"]))
            duration = max(duration, builds[drv]["seconds"])
        builds[drv] = {"drv": drv, "outputs": outputs, "seconds": duration}
    return sorted(builds.values(), key=lambda build: (-build["seconds"], build["drv"]))


def record_build(directory, command):
    directory.mkdir(parents=True, exist_ok=True)
    # Nix's execution timestamps have second resolution.
    since = datetime.now(timezone.utc).replace(microsecond=0)
    previous = recent_events(since)
    executed_builds(previous, since, since)
    previous = {json.dumps(event, sort_keys=True) for event in previous}
    with (directory / "build-result.json").open("w") as output:
        result = subprocess.run(command, stdout=output)
    until = datetime.now(timezone.utc)
    if result.returncode != 0:
        return result.returncode
    events = [event for event in recent_events(since)
              if json.dumps(event, sort_keys=True) not in previous]
    write_json(directory / "events.json", events)
    builds = executed_builds(events, since, until)
    write_json(directory / "builds.json", builds)
    print(f"Recorded {len(builds)} executed derivations; substituted paths excluded.")
    return 0


def derivations(paths):
    result = {}
    for offset in range(0, len(paths), 100):
        data = run_json(["nix", "derivation", "show", *paths[offset:offset + 100]])
        if data.get("version") != 4:
            raise ValueError("Expected Nix derivation JSON version 4")
        for name, drv in data["derivations"].items():
            result[store_path(f"/nix/store/{name}")] = drv
    if set(result) != set(paths):
        raise ValueError("Derivation metadata did not match the requested builds")
    return result


def closure(outputs):
    data = run_json([
        "nix", "path-info", "--recursive", "--json", "--json-format", "1", *outputs,
    ])
    if not isinstance(data, dict) or not set(outputs) <= data.keys():
        raise ValueError("Invalid runtime closure metadata")
    for path, info in data.items():
        store_path(path)
        size = info["narSize"]
        if isinstance(size, bool) or not isinstance(size, int) or size < 0:
            raise ValueError(f"Invalid NAR size for {path}")
    return {path: info["narSize"] for path, info in data.items()}


def missing_paths(cache, paths):
    by_hash = {path.split("/")[3].split("-", 1)[0]: path for path in paths}
    hashes = sorted(by_hash)
    missing = set()
    for offset in range(0, len(hashes), 1000):
        batch = hashes[offset:offset + 1000]
        # This is Cachix's own preflight: it excludes the destination and its
        # official NixOS upstream, but not arbitrary third-party substituters.
        response = run_json([
            "curl", "--fail-with-body", "--silent", "--show-error",
            "--retry", "3", "--max-time", "120",
            "--json", json.dumps(batch),
            f"https://cachix.org/api/v1/cache/{cache}/narinfo",
        ])
        if (not isinstance(response, list)
                or not all(isinstance(value, str) for value in response)
                or not set(response) <= set(batch)):
            raise ValueError("Invalid Cachix missing-path response")
        missing.update(by_hash[value] for value in response)
    return missing


def exclusion(build, drv, roots, minimum):
    if set(build["outputs"]) & roots:
        return "configuration root"
    if any("hash" in output for output in drv["outputs"].values()):
        return "fixed-output fetch/build"
    if re.search(r"(^|[-_])source($|[-_])", drv["name"]):
        return "source-like derivation"
    if build["seconds"] < minimum:
        return "below duration threshold"
    return None


def select_builds(builds, roots, metadata, get_closure, get_missing,
                  minimum, per_candidate, total_budget):
    reserved = set()
    selected = set()
    used = 0
    decisions = []
    for build in sorted(builds, key=lambda item: (-item["seconds"], item["drv"])):
        decision = dict(build)
        reason = exclusion(build, metadata[build["drv"]], roots, minimum)
        if reason is None:
            sizes = get_closure(build["outputs"])
            additional = get_missing(set(sizes)) - reserved
            if not additional <= sizes.keys():
                raise ValueError("Missing paths are outside the candidate's closure")
            cost = sum(sizes[path] for path in additional)
            decision["additional_nar_bytes"] = cost
            decision["additional_paths"] = len(additional)
            if not additional:
                reason = "already cached or covered by another selection"
            elif cost > per_candidate:
                reason = "candidate closure exceeds size limit"
            elif used + cost > total_budget:
                reason = "job upload budget exhausted"
            else:
                reserved.update(additional)
                selected.update(build["outputs"])
                used += cost
                reason = "selected"
        decision["reason"] = reason
        decisions.append(decision)
    return {
        "policy": {
            "minimum_seconds": minimum,
            "maximum_candidate_nar_bytes": per_candidate,
            "maximum_job_nar_bytes": total_budget,
        },
        "selected_outputs": sorted(selected),
        "additional_nar_bytes": used,
        "additional_paths": len(reserved),
        "decisions": decisions,
    }


def summary(report):
    counts = {}
    for item in report["decisions"]:
        counts[item["reason"]] = counts.get(item["reason"], 0) + 1
    lines = [
        "### Selective Cachix publication",
        "",
        f"Selected **{len(report['selected_outputs'])} outputs**; estimated additional "
        f"runtime dependencies: **{report['additional_nar_bytes'] / MIB:.2f} MiB NAR**.",
        "NAR sizes are uncompressed budget estimates, not Cachix-accounted storage.",
        "",
        "| Decision | Builds |",
        "| --- | ---: |",
        *[f"| {reason} | {count} |" for reason, count in sorted(counts.items())],
        "",
        "| Candidate | Build seconds | Additional MiB NAR | Decision |",
        "| --- | ---: | ---: | --- |",
    ]
    interesting = [item for item in report["decisions"]
                   if item["seconds"] >= report["policy"]["minimum_seconds"]]
    for item in interesting[:50]:
        name = item["drv"].split("/", 3)[3].split("-", 1)[1].removesuffix(".drv")
        size = item.get("additional_nar_bytes")
        formatted_size = "-" if size is None else f"{size / MIB:.2f}"
        lines.append(f"| `{name}` | {item['seconds']:.1f} | {formatted_size} "
                     f"| {item['reason']} |")
    lines += ["", "The JSON artifact contains every decision. Selection is not proof "
              "of publication; the separate upload step must succeed.", ""]
    return "\n".join(lines)


def select(directory, cache, minimum, candidate_mib, budget_mib):
    builds = json.loads((directory / "builds.json").read_text())
    results = json.loads((directory / "build-result.json").read_text())
    roots = {store_path(path) for result in results for path in result["outputs"].values()}
    if not roots:
        raise ValueError("The build did not report any configuration outputs")
    metadata = derivations([build["drv"] for build in builds])
    report = select_builds(
        builds, roots, metadata, closure, lambda paths: missing_paths(cache, paths),
        minimum, candidate_mib * MIB, budget_mib * MIB,
    )
    write_json(directory / "selection.json", report)
    (directory / "selected-paths.txt").write_text(
        "".join(path + "\n" for path in report["selected_outputs"])
    )
    text = summary(report)
    print(text)
    if "GITHUB_STEP_SUMMARY" in os.environ:
        with Path(os.environ["GITHUB_STEP_SUMMARY"]).open("a") as output:
            output.write(text)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="mode", required=True)
    build_parser = commands.add_parser("build")
    build_parser.add_argument("--directory", type=Path, required=True)
    build_parser.add_argument("command", nargs=argparse.REMAINDER)
    select_parser = commands.add_parser("select")
    select_parser.add_argument("--directory", type=Path, required=True)
    select_parser.add_argument("--cache", required=True)
    select_parser.add_argument("--minimum-seconds", type=int, default=60)
    select_parser.add_argument("--candidate-mib", type=int, default=250)
    select_parser.add_argument("--budget-mib", type=int, default=1024)
    args = parser.parse_args()
    if args.mode == "build":
        command = args.command[1:] if args.command[:1] == ["--"] else args.command
        if not command:
            parser.error("A nix build command is required")
        return record_build(args.directory, command)
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", args.cache):
        parser.error("Invalid cache name")
    if min(args.minimum_seconds, args.candidate_mib, args.budget_mib) <= 0:
        parser.error("All selection thresholds must be positive")
    select(args.directory, args.cache, args.minimum_seconds,
           args.candidate_mib, args.budget_mib)
    return 0


if __name__ == "__main__":
    sys.exit(main())
