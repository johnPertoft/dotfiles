{ pkgs, lib, ... }:
{
  # Default applications for XDG mime/scheme handlers. Centralized here so
  # the choice of which terminal/browser/etc. wins is in one place, not
  # spread across the per-app modules where they'd silently fight.
  xdg.mimeApps = lib.mkIf pkgs.stdenv.isLinux {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/terminal" = "kitty.desktop";
    };
  };
}
