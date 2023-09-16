{ nixpkgs, self, ... }:
nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    ./configuration.nix
    ./hardware-configuration.nix
    self.nixosModules.default
  ];
}
