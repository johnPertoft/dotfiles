{ pkgs ? import <nixpkgs> { }, shellHook ? "", ... }:
pkgs.mkShell {
  name = "home-manager";
  inherit shellHook;
  packages = with pkgs; [
    git
    home-manager
    nix-diff
    nix-info
    nixpkgs-fmt
  ];
  meta = {
    description = "Home Manager dev shell";
  };
}
