{ config
, pkgs
, lib
, ...
}:
{
  home.username = "john";
  home.homeDirectory = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/john" else "/home/john";
  programs.git.userName = "John Pertoft";
  programs.git.userEmail = "john.pertoft@gmail.com";
  # services.auto-upgrade = {
  #   enable = true;
  #   flake = "github:johnPertoft/dotfiles";
  # };
}
