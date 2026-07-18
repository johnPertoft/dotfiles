{ config
, pkgs
, lib
, self
, ...
}:
let
  # junegunn's official "preview anything" helper (bat for text, tree for dirs,
  # chafa for images). Wrapped so the tools it needs are on PATH regardless of
  # what's installed globally.
  fzf-preview =
    let
      src = pkgs.fetchurl {
        # Pinned to a release tag (not master) so the hash can't drift under us.
        url = "https://raw.githubusercontent.com/junegunn/fzf/v0.74.0/bin/fzf-preview.sh";
        hash = "sha256-DkoKSJtUfap13Y7u/WtShgZ3QBsrd1T938txoYZdRVI=";
        executable = true;
      };
    in
    pkgs.writeShellScriptBin "fzf-preview.sh" ''
      export PATH="${lib.makeBinPath [ pkgs.bat pkgs.file pkgs.chafa pkgs.coreutils ]}:$PATH"
      export BAT_THEME="ansi"
      exec ${src} "$@"
    '';
in
{
  programs.fzf = {
    enable = true;
    tmux.enableShellIntegration = config.programs.tmux.enable;
    defaultOptions = [ "--height 100%" ];

    # CTRL-T: file picker with rich content/image previews.
    fileWidgetCommand = "fd --type f --color=always";
    fileWidgetOptions = [
      "--ansi"
      "--preview '${lib.getExe fzf-preview} {}'"
      "--bind 'focus:transform-preview-label:echo {}'"
      "--bind '?:toggle-preview'"
    ];

    # ALT-C: directory picker with a tree preview.
    changeDirWidgetCommand = "fd --type d --color=always";
    changeDirWidgetOptions = [
      "--ansi"
      "--preview 'tree -C {}'"
      "--bind 'focus:transform-preview-label:echo {}'"
      "--bind '?:toggle-preview'"
    ];

    # CTRL-R: history, preview hidden by default (? to peek).
    historyWidgetOptions = [
      "--preview 'echo {}'"
      "--preview-window hidden"
      "--bind '?:toggle-preview'"
    ];
  };

  home.packages = with pkgs; [
    fzf-git-sh
    bat
    tree
    self.packages.${pkgs.stdenv.hostPlatform.system}.fzf-open
    self.packages.${pkgs.stdenv.hostPlatform.system}.fzf-jq
  ];

  #home.shellAliases = {
  #  "." = "${self.packages.${pkgs.stdenv.hostPlatform.system}.fzf-open}/bin/fzf-open";
  #};

  programs.zsh.initContent = ''
    fzf-rg() {
      ${self.packages.${pkgs.stdenv.hostPlatform.system}.fzf-ripgrep}/bin/fzf-ripgrep "$BUFFER"
      zle reset-prompt
    }
    zle -N fzf-rg
    bindkey '^F' fzf-rg

    fzf-open() {
      ${self.packages.${pkgs.stdenv.hostPlatform.system}.fzf-open}/bin/fzf-open "$BUFFER"
      zle reset-prompt
    }
    zle -N fzf-open
    bindkey '^P' fzf-open

    fzf-blame() {
      ${self.packages.${pkgs.stdenv.hostPlatform.system}.fzf-git-blame}/bin/fzf-git-blame "$BUFFER"
      zle reset-prompt
    }
    zle -N fzf-blame
    bindkey '^B' fzf-blame
  '';

  programs.bash.initExtra = ''
    fzf-rg() {
        ${self.packages.${pkgs.stdenv.hostPlatform.system}.fzf-ripgrep}/bin/fzf-ripgrep "$READLINE_LINE"
    }
    bind -x '"\C-f": fzf-rg'

    fzf-open() {
        ${self.packages.${pkgs.stdenv.hostPlatform.system}.fzf-open}/bin/fzf-open "$READLINE_LINE"
    }
    bind -x '"\C-p": fzf-open'

    fzf-blame() {
        ${self.packages.${pkgs.stdenv.hostPlatform.system}.fzf-git-blame}/bin/fzf-git-blame "$READLINE_LINE"
    }
    bind -x '"\C-b": fzf-blame'
  '';
}
