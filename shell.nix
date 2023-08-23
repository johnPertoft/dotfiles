{ pkgs ? import <nixpkgs> { }, shellHook, ... }:
pkgs.mkShell {
  name = "home-manager";
  inherit shellHook;
  packages = with pkgs; [
    git
    home-manager
    nixpkgs-fmt
  ];
  meta = {
    description = "Dotfiles dev shell";
  };
}