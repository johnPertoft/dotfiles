# dotfiles

# Usage

1. Be on NixOS or install nix with flakes

2. ```
   nix run .#switch-system
   ```

3. ```
   # First time
   nix-shell -p home-manager

   nix run .#switch-home
   ```

4. ```
   # Update inputs
   nix flake update --commit-lock-file .
   ```

## TODO

```bash
# TODO: fix this so we can run nix run .#switch-system nixos-home instead.
sudo nixos-rebuild switch --flake .#nixos-home
nix run .#switch-home
nix shell .#ipython
```
