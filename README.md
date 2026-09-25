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

The `CI` workflow in `.github/workflows/ci.yaml` uses a fixed, inline matrix:

| Target             | Flake output                                                                        | Runner        |
| ------------------ | ----------------------------------------------------------------------------------- | ------------- |
| ThinkCentre system | `nixosConfigurations.thinkcentre.config.system.build.toplevel`                      | Ubuntu x86-64 |
| Pi system          | `nixosConfigurations.pi.config.system.build.toplevel`                               | Ubuntu ARM64  |
| Desktop system     | `nixosConfigurations.home-desktop.config.system.build.toplevel`                     | Ubuntu x86-64 |
| Desktop home       | `legacyPackages.x86_64-linux.homeConfigurations.john.activationPackage`             | Ubuntu x86-64 |
| MacBook system     | `darwinConfigurations.STOLTM7XVQCG7.system`                                         | macOS ARM64   |
| MacBook home       | `legacyPackages.aarch64-darwin.homeConfigurations."john.pertoft".activationPackage` | macOS ARM64   |

Home Manager is standalone here: building a NixOS or nix-darwin system does not
build the corresponding home configuration. The home jobs build the activation
packages and their Nix-managed dependencies without activating anything.
Homebrew casks, Flatpak/container images, and other applications downloaded at
activation time or runtime are not included in these Nix closures.

Flake checks run on pushes to `main`, pull requests targeting `main`, and manual
runs. The full build matrix runs only on main pushes and manual runs, after the
checks succeed; pull requests run checks without full configuration builds.
Documentation-only pushes/PRs are skipped.
Each target and trigger type has its own concurrency group: automatic
runs cannot cancel manual upload experiments, and a failed build does not
cancel its siblings. Linux and macOS jobs use native
runners without emulation.

The Pi job builds its NixOS system closure, not an SD image, and does not deploy
or boot it. There is no Pi-specific Home Manager configuration in this matrix.
It uses the same selective publication policy as the other Linux targets.

CI uses the Nix installer and Cachix actions. There are no custom
actions or change-detection scripts. Each target is requested on every build run,
and Nix substitutes cached outputs where available.

CI appends the Numtide agent and CUDA caches through `NIX_CONFIG`, which is read
after the user-level configuration written by the Cachix action. This keeps
those caches available alongside Cachix rather than accidentally replacing them.
The desktop uses the current CUDA cache at `https://cache.nixos-cuda.org`.

The weekly lockfile updater explicitly dispatches `ci.yaml` after a successful
push, with cache publication enabled on `main`. Its `GITHUB_TOKEN` has
`actions: write` permission for this dispatch; pushes made with that token do
not themselves trigger push-based CI. Manual updater runs dispatch CI on the
same ref, without publication when outside `main`. No additional token is needed.

### Selective binary caching

The Linux jobs record successful, actually executed derivations using
Determinate Nix's local build-events API. Downloaded/substituted paths are not
candidates. CI uses the recorded execution duration, not the time spent waiting
for a build slot, downloading dependencies, or evaluating the flake.

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

Successful CI builds from **main pushes and weekly updates publish selected
Linux outputs automatically**. Other manual runs publish only with
`publish_cache=true`. Pull requests only run checks, and non-main branch pushes
do not trigger CI. MacBook jobs remain read-only. Every successful Linux
build reports selected/skipped candidates in its job summary, with detailed
JSON and the selected output paths retained as a seven-day Actions artifact.
No eligible candidates is a valid result and uploads nothing.

Manual runs can override the duration threshold with `minimum_build_seconds`
(positive whole seconds) to tune or exercise the filter without changing the
five-minute policy for main pushes. The closure size limits remain unchanged.

Every build run includes all six targets, including manual runs.

Hosts with the configured Cachix URL/key substitute matching package outputs
normally; small uncached configuration derivations still build locally. Use an
exact commit whose relevant CI build and publication succeeded. Matching inputs
and architecture are required, and garbage collection can still remove entries.
No pins are created. The cache is public, so selected packages and dependencies
must be suitable for public redistribution. See the
[ThinkCentre cache setup](systems/thinkcentre/README.md#ci-builds-and-cachix)
for the repository secret and manual publishing command.
