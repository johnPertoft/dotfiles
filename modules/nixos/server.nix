{ config, pkgs, ... }:
{
  # Configure key-based remote SSH access.
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "no";
  services.openssh.settings.PasswordAuthentication = false;
  # PasswordAuthentication alone isn't enough: with UsePAM the keyboard-
  # interactive method still routes through PAM to the password, so a password
  # login remains possible. Disable it too to make SSH genuinely key-only.
  services.openssh.settings.KbdInteractiveAuthentication = false;

  # Insist all users are declaratively defined.
  users.mutableUsers = false;

  # Clear out the default user environment.
  environment.defaultPackages = [ ];

  # Skip installing documentation on the server.
  documentation.enable = false;
  documentation.doc.enable = false;
  documentation.info.enable = false;
  documentation.man.enable = false;
  documentation.nixos.enable = false;

  # Skip the program that suggests installable software.
  programs.command-not-found.enable = false;

  # Disable desktop-specific functionality.
  xdg.autostart.enable = false;
  xdg.icons.enable = false;
  xdg.mime.enable = false;
  xdg.sounds.enable = false;
}
