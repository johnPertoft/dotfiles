{
  description = "A nix config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
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
        # legacyPackages.homeConfigurations = {
        # TODO
        # }
      };
    in
    flake-utils.lib.eachDefaultSystem mkSystem // {
      nixosConfigurations = {
        nixos-home = import ./hosts/nixos/home-desktop inputs;
        nixos-work = import ./hosts/nixos/work-desktop inputs;
      };
      nixosModules = import ./modules/nixos inputs;

      #homeModules = import ./home-manager inputs;

      # TODO: Have this here?
      # homeConfigurations = {
      #   "john@x86_64-linux" = inputs.home-manager.lib.homeManagerConfiguration {
      #     #pkgs = nixpkgs-unstable.legacyPackages.x86_64-linux;
      #     pkgs = nixpkgs.legacyPackages.x86_64-linux;
      #     modules = [ ./home-manager/home.nix ];
      #   };
      # };
    };
}
