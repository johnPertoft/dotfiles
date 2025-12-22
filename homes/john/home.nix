{ config
, pkgs
, lib
, ...
}:
{
  home.username = "john";
  home.homeDirectory = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/john" else "/home/john";
  programs.git.settings.userName = "John Pertoft";
  programs.git.settings.userEmail = "john.pertoft@gmail.com";
}
