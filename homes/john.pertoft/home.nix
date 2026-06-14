{ config
, pkgs
, lib
, ...
}:
{
  home.username = "john.pertoft";
  home.homeDirectory = "/Users/john.pertoft";
  programs.git.settings.user.name = "John Pertoft";
  programs.git.settings.user.email = "john.pertoft@king.com";

  # Keep ~/.local/bin on PATH so `uv tool install`-style work tools work.
  home.sessionPath = [ "$HOME/.local/bin" ];
}
