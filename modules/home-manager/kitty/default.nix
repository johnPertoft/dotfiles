{ pkgs, lib, ... }:
{
  home.packages = with pkgs; [
    maple-mono.variable
  ];

  programs.kitty = {
    enable = true;

    # https://sw.kovidgoyal.net/kitty/conf.html
    settings = {
      scrollback_lines = 10000;
      enable_audio_bell = false;
      update_check_interval = 0;
      tab_bar_edge = "top";
      tab_bar_style = "powerline";
      tab_powerline_style = "angled";
      term = "xterm-256color";
    };

    # kitty_mod defaults to ctrl+shift on Linux and cmd on macOS, so these
    # bindings work on both platforms.
    keybindings = {
      "kitty_mod+1" = "goto_tab 1";
      "kitty_mod+2" = "goto_tab 2";
      "kitty_mod+3" = "goto_tab 3";
      "kitty_mod+4" = "goto_tab 4";
      "kitty_mod+5" = "goto_tab 5";
      "kitty_mod+6" = "goto_tab 6";
      "kitty_mod+7" = "goto_tab 7";
      "kitty_mod+8" = "goto_tab 8";
      "kitty_mod+9" = "goto_tab 9";
    };

    # https://github.com/kovidgoyal/kitty-themes
    themeFile = "gruvbox-dark-soft";

    font = {
      name = "Maple Mono";
      size = 14;
    };
  };

  # Make kitty the value of $TERMINAL on Linux. Honored by i3/sway, neovim
  # :term, dmenu wrappers, etc. No equivalent on macOS — kitty has to be
  # set as the default from its own app menu. The xdg-mime side of "default
  # terminal" lives in modules/home-manager/xdg.
  home.sessionVariables = lib.mkIf pkgs.stdenv.isLinux {
    TERMINAL = "kitty";
  };
}
