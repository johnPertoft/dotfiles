{ config
, pkgs
, lib
, ...
}:
{

  # TODO Set this if not NixOS but still Linux.
  # targets.genericLinux.enable = true;

  nixpkgs.config = {
    allowUnfreePredicate =
      pkg:
      builtins.elem (lib.getName pkg) [
        "discord"
        "dropbox"
        "google-chrome"
        "reaper"
        "slack"
        "spotify"
        "steam-original"
        "steam"
        "steam-unwrapped"
        "vscode"
        "terraform"
        "firefox-bin"
        "firefox-bin-unwrapped"
      ];
    permittedInsecurePackages = [
      "electron-28.3.3"
      "electron-27.3.11"
    ];
  };

  home.shellAliases = {
    open = "xdg-open";
  };

  home.packages =
    with pkgs;
    [
      chromium
      deja-dup
      discord
      distrobox
      dropbox
      element-desktop
      firefox
      google-chrome
      keepassxc
      logseq
      marker
      obs-studio
      #okular
      peek
      reaper
      signal-desktop
      slack
      spotify
      stdenv.cc.cc.lib
      steam
      telegram-desktop
      transmission_4-gtk
      vlc
      wineWowPackages.full
      yabridge
      yabridgectl
      zlib
    ]
    ++ (with pkgs.gnomeExtensions; [
      blur-my-shell
      caffeine
      hue-lights
      system-monitor
      vitals
    ]);

  # Use `dconf watch /` to track stateful changes you are doing, then set them here.
  dconf.settings = {
    "org/gnome/shell" = {
      enabled-extensions = [
        "appindicatorsupport@rgcjonas.gmail.com"
        "apps-menu@gnome-shell-extensions.gcampax.github.com"
        "blur-my-shell@aunetx"
        "caffeine@patapon.info"
        "hue-lights@chlumskyvaclav.gmail.com"
        "places-menu@gnome-shell-extensions.gcampax.github.com"
        "system-monitor@gnome-shell-extensions.gcampax.github.com"
        "Vitals@CoreCoding.com"
      ];
    };
  };
}
