# dotfiles
1. Be on NixOS or install nix with flakes
2. ```
   nix run .#switch-system
   ```
3. ```
   # First time
   nix-shell -p home-manager

   nix run .#switch-home
   ```