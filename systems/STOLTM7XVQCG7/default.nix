{ nix-darwin, self, ... }:

nix-darwin.lib.darwinSystem {
  system = "aarch64-darwin";
  modules = [
    ./configuration.nix
    self.darwinModules.default
    self.modules.default
  ];
}
