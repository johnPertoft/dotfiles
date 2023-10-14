{ self, ... }:
home-manager.lib.homeManagerConfiguration {
  #pkgs = nixpkgs.legacyPackages.x86_64-linux;
  pkgs = import nixpkgs {
    inherit system};
      modules= [
    ./home.nix
      self. homeModules. default
      ];
      }
