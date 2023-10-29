# dotfiles

# Usage

```bash

# Update inputs and commit lock file
nix flake update --commit-lock-file .

# NixOS rebuild home
sudo nixos-rebuild switch --flake github:johnPertoft/dotfiles#nixos-home

# NixOS rebuild work
sudo nixos-rebuild switch --flake github:johnPertoft/dotfiles#nixos-work

# Home-manager switch
nix run github:johnPertoft/dotfiles#switch-home

# Shell with ipython and ml packages
nix shell .#ipython
```
