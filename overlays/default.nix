{ nixpkgs-unstable, ... }:
{
  nixpkgs-unstable = import ./nixpkgs-unstable.nix { inherit nixpkgs-unstable; };
  modules-closure = import ./modules-closure.nix { };
  pre-commit-darwin = import ./patches/pre-commit-darwin.nix;
}
