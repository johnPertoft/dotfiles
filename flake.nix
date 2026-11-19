{
  description = "A nix config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # Same release branch as `nixpkgs`, but this channel only advances once
    # Hydra has built the revision for darwin. `nixos-26.05` is gated on Linux
    # tests alone and can point at revisions with no darwin binaries yet, which
    # turns a routine update into hours of local source builds on the Mac.
    nixpkgs-darwin.url = "github:nixos/nixpkgs/nixpkgs-26.05-darwin";

    nix-darwin = {
      url = "github:lnl7/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Daily-rebuilt AI coding agent CLIs (claude-code, codex, gemini-cli, …).
    # Not following nixpkgs so we get the upstream-built binaries from the
    # numtide cache rather than rebuilding against our pin.
    llm-agents.url = "github:numtide/llm-agents.nix";

    flake-utils.url = "github:numtide/flake-utils";

    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self
    , nixpkgs
    , nixpkgs-unstable
    , nixpkgs-darwin
    , flake-utils
    , ...
    }@inputs:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      # Darwin builds use the darwin-gated channel; everything downstream
      # (homes, packages, checks) receives it as `nixpkgs`.
      nixpkgsFor = system: if nixpkgs.lib.hasSuffix "darwin" system then nixpkgs-darwin else nixpkgs;

      mkSystem =
        system:
        let
          pinned = nixpkgsFor system;
          # Drop the separate name so it doesn't add a second nixpkgs to the
          # home-manager flake registry (built from all inputs).
          args = (builtins.removeAttrs inputs [ "nixpkgs-darwin" ]) // {
            inherit system;
            nixpkgs = pinned;
          };
        in
        {
          legacyPackages.homeConfigurations = import ./homes args;
          packages = import ./packages args;
          checks = import ./pre-commit.nix args;
          formatter = pinned.legacyPackages.${system}.nixfmt;
          devShells.default = import ./shell.nix {
            pkgs = pinned.legacyPackages.${system};
            shellHook = self.checks.${system}.pre-commit-check.shellHook;
            buildInputs = self.checks.${system}.pre-commit-check.enabledPackages;
          };
        };
    in
    flake-utils.lib.eachSystem systems mkSystem
    // {
      inherit (import ./systems inputs) nixosConfigurations darwinConfigurations;

      darwinModules = import ./modules/nix-darwin inputs;

      nixosModules = import ./modules/nixos inputs;

      homeModules = import ./modules/home-manager inputs;

      modules = import ./modules inputs;

      overlays = import ./overlays inputs;
    };
}
