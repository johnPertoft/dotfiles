# dotfiles

# Troubleshooting

## Nix not on PATH (macOS)

The Nix installer adds a shell hook to `/etc/bashrc` but sometimes skips `/etc/zshrc`. Since macOS uses zsh by default, nix won't be on your PATH in interactive terminals. Fix:

```bash
sudo tee -a /etc/zshrc << 'EOF'

# Nix
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
  . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi
# End Nix
EOF
```

Then open a new terminal and verify with `nix --version`.

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

# Project templates

Scaffold a dev + build environment for a new project. Each template is a
self-contained flake (dev shell via `nix develop` + `nix build`), works on
plain Linux/darwin and NixOS, and documents how to flip CUDA on.

```bash
# Rust (rust-overlay toolchain + crane build; optional CUDA)
nix flake init -t github:johnPertoft/dotfiles#rust

# Python ML, uv + PyPI wheels (light; CUDA via wheel index)
nix flake init -t github:johnPertoft/dotfiles#python-ml-uv

# Python ML, uv2nix (reproducible nix-built env from uv.lock; CUDA)
nix flake init -t github:johnPertoft/dotfiles#python-ml-uv2nix
```

Pick the Python version in the template's `flake.nix` (`python = pkgs.python312;`)
or the Rust toolchain in `rust-toolchain.toml`. See each template's `README.md`
for CUDA notes (NixOS / plain Linux / darwin differences).
