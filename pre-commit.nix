{ nixpkgs, pre-commit-hooks, system, ... }:
let
  pkgs = nixpkgs.legacyPackages.${system};
in
{
  pre-commit-check = pre-commit-hooks.lib.${system}.run {
    package = pkgs.pre-commit.overridePythonAttrs (_: {
      doCheck = false;
      dontUsePytestCheck = true;
      nativeCheckInputs = [ ];
      preCheck = "";
    });

    src = ./.;
    hooks = {
      actionlint.enable = true;
      nixpkgs-fmt.enable = true;
      prettier = {
        enable = true;
        excludes = [ "flake.lock" ];
      };
      shellcheck = {
        enable = true;
        excludes = [ ".envrc" ];
      };
      shfmt.enable = true;
    };
  };
}
