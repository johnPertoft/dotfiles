{ home-manager
, nixpkgs
, nix-index-database
, system
, self
, ...
}@inputs:

home-manager.lib.homeManagerConfiguration {
  extraSpecialArgs = inputs;
  pkgs = import nixpkgs {
    inherit system;
    overlays = [
      self.overlays.nixpkgs-unstable
      self.overlays.pre-commit-darwin
    ];
  };
  modules = (import ../common.nix inputs) ++ [
    ./home.nix
  ];
}
