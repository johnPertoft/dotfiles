{ ... }:
{
  # Interactive shell environment: the shells themselves plus the prompt
  # and closely-coupled shell integrations (file manager, direnv).
  programs = {
    fish.enable = true;
    zsh = {
      enable = true;
      autocd = true;
    };
    nushell.enable = true;
    bash = {
      enable = true;
      shellOptions = [
        "autocd"
        "cdspell"
        "dirspell"
        "checkhash"
        "checkjobs"
        "extglob"
        "globstar"
        "histappend"
      ];
    };
    nnn.enable = true;
    starship = {
      enable = true;
      enableTransience = true;
      settings = {
        add_newline = true;
        format = "$directory$git_branch$git_state$git_status$nix_shell$line_break$character";
        right_format = "$cmd_duration";
        directory = {
          truncation_length = 3;
          truncate_to_repo = true;
        };
        nix_shell = {
          format = "via [$symbol$state]($style) ";
          symbol = "❄️ ";
        };
        cmd_duration = {
          min_time = 500; # ms; only show for commands slower than this
        };
        character = {
          success_symbol = "[❯](bold green)";
          error_symbol = "[❯](bold red)"; # red prompt on non-zero exit
        };
      };
    };
    direnv = {
      enable = true;
      nix-direnv.enable = true;
      config = {
        global.hide_env_diff = true;
      };
    };
  };
}
