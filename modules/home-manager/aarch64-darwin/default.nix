{ config
, pkgs
, lib
, ...
}:
{
  # Mac-only utilities live with the Darwin per-system module so any home
  # built on Darwin gets them without having to import each one explicitly.
  imports = [ ../macos-spotlight-apps ];

  nixpkgs.config = {
    allowUnfreePredicate =
      pkg:
      builtins.elem (lib.getName pkg) [
        "claude-code"
        "terraform"
        "vscode"
      ];
  };

  home.packages = with pkgs; [
    colima
    net-news-wire
    stats
    iterm2
  ];

  # Use the Apple-patched system ssh so options like UseKeychain in
  # ~/.ssh/config don't trip up nix's upstream OpenSSH.
  programs.git.settings.core.sshCommand = "/usr/bin/ssh";

  # Create wrapper apps so Spotlight (cmd+space) can find Nix-installed GUI apps.
  services.macos-spotlight-apps.enable = true;

  # Make sure the screenshots directory exists before screencapture writes there.
  home.file."Pictures/Screenshots/.keep".text = "";

  # Declarative macOS preferences. Find domain/key by changing a setting in
  # System Settings, then diffing `defaults read` before and after.
  targets.darwin.defaults = {
    "com.apple.dock" = {
      autohide = true;
      show-recents = false;
      show-process-indicators = false;
      static-only = true;
    };

    "com.apple.finder" = {
      AppleShowAllExtensions = true;
      AppleShowAllFiles = true;
      ShowPathBar = true;
      ShowStatusBar = true;
    };

    "com.apple.desktopservices" = {
      DSDontWriteNetworkStores = true;
      DSDontWriteUSBStores = true;
    };

    "com.apple.screencapture".location = "~/Pictures/Screenshots";

    "com.apple.menuextra.clock".Show24Hour = true;

    # Disable system-wide autocorrect and "smart" substitutions.
    NSGlobalDomain = {
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
    };
  };
}
