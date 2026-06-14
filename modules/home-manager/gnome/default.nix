{ ... }:
{
  # Manage GNOME via dconf. The Linux analogue of the reference's
  # targets.darwin.defaults block on macOS. Only meaningful on a NixOS host
  # running GNOME.
  dconf.settings = {
    # Register custom keybindings. Note: this overwrites any custom
    # keybindings set through GNOME Settings — declare them all here.
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
      ];
    };

    # Ctrl+Alt+T launches kitty.
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      name = "Terminal";
      binding = "<Control><Alt>t";
      command = "kitty";
    };
  };
}
