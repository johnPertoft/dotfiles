# dotfiles

# Usage

```bash

# Update inputs and commit lock file
nix flake update --commit-lock-file .

# NixOS rebuild home (local)
nh os switch .
# sudo nixos-rebuild switch --flake .#home-desktop

# NixOS rebuild home (remote)
nh os switch github:johnPertoft/dotfiles
# sudo nixos-rebuild switch --flake github:johnPertoft/dotfiles#home-desktop

# nix-darwin rebuild work mbp (local)
nh darwin switch .
# sudo darwin-rebuild switch --flake .#STOLTM7XVQCG7

# nix-darwin rebuild work mbp (remote)
nh darwin switch github:johnPertoft/dotfiles
# sudo darwin-rebuild switch --flake github:johnPertoft/dotfiles#STOLTM7XVQCG7

# Home-manager switch (local)
nh home switch .
# nix run .#switch-home

# Home-manager switch (remote)
nh home switch github:johnPertoft/dotfiles
# nix run github:johnPertoft/dotfiles#switch-home

# Shell with ipython and ml packages
nix shell .#ipython
```

## CI builds

The workflow in `.github/workflows/check.yaml` uses a fixed, inline matrix:

| Target             | Flake output                                                                        | Runner        |
| ------------------ | ----------------------------------------------------------------------------------- | ------------- |
| ThinkCentre system | `nixosConfigurations.thinkcentre.config.system.build.toplevel`                      | Ubuntu x86-64 |
| Desktop system     | `nixosConfigurations.home-desktop.config.system.build.toplevel`                     | Ubuntu x86-64 |
| Desktop home       | `legacyPackages.x86_64-linux.homeConfigurations.john.activationPackage`             | Ubuntu x86-64 |
| MacBook system     | `darwinConfigurations.STOLTM7XVQCG7.system`                                         | macOS ARM64   |
| MacBook home       | `legacyPackages.aarch64-darwin.homeConfigurations."john.pertoft".activationPackage` | macOS ARM64   |

Home Manager is standalone here: building a NixOS or nix-darwin system does not
build the corresponding home configuration. The home jobs build the activation
packages and their Nix-managed dependencies without activating anything.
Homebrew casks, Flatpak/container images, and other applications downloaded at
activation time or runtime are not included in these Nix closures.

Pushes to `main` and the initial `fix/ci-build` branch, pull requests targeting
`main`, and manual runs use this matrix. Documentation-only pushes/PRs are
skipped. Each target and trigger type has its own concurrency group: automatic
runs cannot cancel manual upload experiments, and a failed build does not
cancel its siblings. The Pi is not included; Linux and macOS jobs use native
runners without emulation.

CI keeps the existing Nix installer and Cachix actions. There are no custom
actions or change-detection scripts. Each target is requested on every run,
and Nix substitutes cached outputs where available.

CI appends the Numtide agent and CUDA caches through `NIX_CONFIG`, which is read
after the user-level configuration written by the Cachix action. This keeps
those caches available alongside Cachix rather than accidentally replacing them.
The desktop uses the current CUDA cache at `https://cache.nixos-cuda.org`.

### Selective binary caching

The Linux jobs record successful, actually executed derivations using
Determinate Nix's local build-events API. Downloaded/substituted paths are not
candidates. CI uses the recorded execution duration, not the time spent waiting
for a build slot, downloading dependencies, or evaluating the flake. The check
job exercises real builds, a cached repeat, and a failure to detect incompatible
telemetry changes.

`.github/scripts/cache_builds.py` selects candidates using these workflow settings:

| Setting               | Default | Meaning                                            |
| --------------------- | ------- | -------------------------------------------------- |
| `CACHE_MIN_SECONDS`   | 300     | Minimum successful build duration                  |
| `CACHE_CANDIDATE_MIB` | 1024    | Maximum additional runtime closure per candidate   |
| `CACHE_BUDGET_MIB`    | 1024    | Maximum additional runtime closures per matrix job |

The selector excludes the requested system/Home Manager roots, fixed-output
derivations (including source fetches), and source-like derivation names. It
considers the slowest builds first. Size budgets use **uncompressed NAR bytes**,
not compressed Cachix storage usage, and count shared dependencies once per job.
These are conservative per-run estimates, not an account-wide storage quota or
a retention policy.

Cachix recursively uploads each selected output's runtime dependencies. The
selector uses Cachix's missing-path API to budget everything that would be
added, excluding paths already in the destination or the official NixOS cache.
Dependencies in CUDA, Numtide, or other third-party caches still count against
the budget. A locally compiled package with a large uncached CUDA closure can
therefore be skipped rather than filling the cache.

Successful pushes to **`main` publish selected Linux outputs automatically**.
Manual runs publish only with `publish_cache=true`; branch pushes and pull
requests remain read-only. MacBook jobs remain read-only. Every successful Linux
build reports selected/skipped candidates in its job summary, with detailed
JSON and the selected output paths retained as a seven-day Actions artifact.
No eligible candidates is a valid result and uploads nothing.

Manual runs can override the duration threshold with `minimum_build_seconds`
(positive whole seconds) to tune or exercise the filter without changing the
five-minute policy for pushes/PRs. For example, add
`-f minimum_build_seconds=15` to the manual publishing command below; the closure
size limits remain unchanged.

Set `build_targets=desktop` on a manual run to build only the desktop system and
desktop Home Manager configuration. The default `all` and all push/PR runs retain
the full matrix. This is an explicit target selector, not change detection.

Hosts with the configured Cachix URL/key substitute matching package outputs
normally; small uncached configuration derivations still build locally. Use an
exact commit whose relevant CI build and publication succeeded. Matching inputs
and architecture are required, and garbage collection can still remove entries.
No pins are created. The cache is public, so selected packages and dependencies
must be suitable for public redistribution. See the
[ThinkCentre cache setup](systems/thinkcentre/README.md#ci-builds-and-cachix)
for the repository secret and manual publishing command.

#### End-to-end cache probe

An opt-in synthetic probe exercises publication and retrieval without compiling
a large application:

```sh
gh workflow run check.yaml --ref fix/ci-build \
  -f build_targets=cache-probe -f publish_cache=true
# After merging, use --ref main instead.
```

`.github/cache-probe.nix` sleeps ten seconds longer than the selected duration
threshold (310 seconds by default) and writes a tiny marker file. Its name
includes the workflow run ID and attempt, so a new attempt executes the builder
rather than reusing an older probe. The threshold must be between 1 and 900
seconds for this probe.

A cheap wrapper references the slow output, allowing the ordinary selector to
exclude the requested root while selecting the slow dependency. CI requires
that exact output to be selected and publishes it through the normal upload
step. A separate fresh-runner job then retrieves the reported store path with
local and remote builds disabled, only this Cachix cache configured, and signature
checking enabled. It also compares the downloaded marker with the producer's
run ID/attempt.

This tests the caching pipeline, not compiler performance. It is not included in
the normal host matrix and does not change installed configurations. The tiny
probe is not pinned and is subject to normal Cachix garbage collection.
