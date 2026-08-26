{ nixpkgs-unstable, ... }:
{
  nixpkgs-unstable = import ./nixpkgs-unstable.nix { inherit nixpkgs-unstable; };
  modules-closure = import ./modules-closure.nix { };
  pre-commit-no-tests-darwin = import ./pre-commit-no-tests-darwin.nix;
}
