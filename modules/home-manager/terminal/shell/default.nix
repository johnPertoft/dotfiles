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
