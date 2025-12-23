{ config
, pkgs
, lib
, ...
}:
{
  home.username = "john";
  home.homeDirectory = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/john" else "/home/john";
  programs.git.settings.user.name = "John Pertoft";
  programs.git.settings.user.email = "john.pertoft@gmail.com";
}
