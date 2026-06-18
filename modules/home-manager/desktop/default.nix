# Grouping namespace for desktop-environment / WM modules and desktop
# integration. Each subdirectory is exposed as self.homeModules.desktop.<name>
# so homes opt in per environment (e.g. gnome is defined here but only
# enabled on a NixOS/GNOME host). Add future DEs/WMs (sway, hyprland,
# kde, ...) as new subdirs and they register automatically.
import ../discover.nix ./.
