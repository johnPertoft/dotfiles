{
  description = "A nix config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-darwin = {
      url = "github:lnl7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-23.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, ... }@inputs:
    let
      mkSystem = system: {
        formatter = nixpkgs.legacyPackages.${system}.nixpkgs-fmt;
        checks = import ./pre-commit.nix (inputs // { inherit system; });
        devShells.default = import ./shell.nix {
          pkgs = nixpkgs.legacyPackages.${system};
          shellHook = self.checks.${system}.pre-commit-check.shellHook;
        };
        packages = import ./packages (inputs // { inherit system; });
        legacyPackages.homeConfigurations = import ./home.nix (inputs // { inherit system; });
      };
    in
    flake-utils.lib.eachDefaultSystem mkSystem // {
      nixosModules = import ./modules/nixos inputs;
      nixosConfigurations = {
        nixos-home = import ./hosts/nixos/home-desktop inputs;
        nixos-work = import ./hosts/nixos/work-desktop inputs;
      };
      homeModules = import ./modules/home-manager inputs;
    };
}
