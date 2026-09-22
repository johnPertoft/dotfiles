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
skipped. Each target has its own concurrency group, and a failed build does not
cancel its siblings. The Pi is not included; Linux and macOS jobs use native
runners without emulation.

CI keeps the existing Nix installer and Cachix actions. There are no custom
actions or detection scripts. Each selected target is requested on every run,
and Nix substitutes cached outputs where available. This deliberately avoids
separate change-detection logic.

All builds read public binary caches. Uploads remain explicitly opt-in through
the `publish_cache` manual input and are still limited to the ThinkCentre row.
The desktop and home closures include proprietary applications; review their
redistribution terms and storage requirements before enabling public uploads for
those rows. Pull requests never publish. See the
[ThinkCentre cache setup](systems/thinkcentre/README.md#ci-builds-and-cachix)
for the repository secret and manual publishing command.
