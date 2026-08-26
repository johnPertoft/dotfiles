{ nixpkgs, pre-commit-hooks, self, system, ... }:
let
  pkgs = nixpkgs.legacyPackages.${system}.extend self.overlays.pre-commit-no-tests-darwin;
in
{
  pre-commit-check = pre-commit-hooks.lib.${system}.run {
    package = pkgs.pre-commit;

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
