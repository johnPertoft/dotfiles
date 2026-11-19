{ nix-darwin, nixpkgs-darwin, self, ... }:

nix-darwin.lib.darwinSystem {
  system = "aarch64-darwin";
  modules = [
    ./configuration.nix
    self.darwinModules.default
    self.darwinModules.homebrew
    self.modules.default
    # self.modules.default points <nixpkgs> at the shared `nixpkgs` input;
    # use the darwin channel this system is actually built from.
    ({ lib, ... }: { nix.nixPath = lib.mkForce [ "nixpkgs=${nixpkgs-darwin}" ]; })
  ];
}
