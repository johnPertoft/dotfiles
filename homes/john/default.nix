{ self, ... }:
home-manager.lib.homeManagerConfiguration {
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  modules = [
    self.homeModules.default
  ];
}
