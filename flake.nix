{
  description = "A nix config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";

    nix-darwin = {
      url = "github:lnl7/nix-darwin/nix-darwin-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , ...
    }@inputs:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      mkSystem = system: {
        legacyPackages.homeConfigurations = import ./homes (inputs // { inherit system; });
        packages = import ./packages (inputs // { inherit system; });
        checks = import ./pre-commit.nix (inputs // { inherit system; });
        formatter = nixpkgs.legacyPackages.${system}.nixfmt-rfc-style;
        devShells.default = import ./shell.nix {
          pkgs = nixpkgs.legacyPackages.${system};
          shellHook = self.checks.${system}.pre-commit-check.shellHook;
          buildInputs = self.checks.${system}.pre-commit-check.enabledPackages;
        };
      };
    in
    flake-utils.lib.eachSystem systems mkSystem
    // {
      nixosConfigurations = {
        nixos-home = import ./hosts/nixos/home-desktop inputs;
        nixos-work = import ./hosts/nixos/work-desktop inputs;
      };
      nixosModules = import ./modules/nixos inputs;
      # darwinConfigurations = import ./systems inputs;
      # darwinModules = import ./modules/nix-darwin inputs;
      homeModules = import ./modules/home-manager inputs;
      # modules = import ./modules inputs;
      # overlays = import ./overlays inputs;
      # templates = import ./templates inputs;
    };
}
