{ pkgs, lib, ... }: rec {
  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
      "discord"
      "google-chrome"
      "slack"
      "spotify"
      "steam"
      "steam-original"
      "vscode"
      "vscode-extension-github-copilot"
      "vscode-extension-MS-python-vscode-pylance"
      "vscode-extension-ms-vscode-remote-remote-ssh"
      "vscode-extension-ms-vsliveshare-vsliveshare"
      "zoom"
    ];
  };

  home = {
    stateVersion = "22.05";
    username = "john";
    homeDirectory = "/home/john";
    sessionVariables = {
      EDITOR = "vim";
      DOCKER_BUILDKIT = true;
      #LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib:$LD_LIBRARY_PATH";
    };
    packages = with pkgs; [
      awscli
      #bazel
      binutils
      coreutils-full
      curl
      discord
      dive
      fantasque-sans-mono
      ffmpeg-full
      file
      firefox
      gcc
      gnumake
      google-chrome
      google-cloud-sdk
      htop
      imagemagick
      jq
      kubectl
      kubectx
      nerdfonts
      nodejs
      nodePackages.npm
      obs-studio
      rclone
      ripgrep
      rsync
      rustup
      shellcheck
      slack
      spotify
      stdenv.cc.cc.lib
      steam
      transmission-gtk
      tree
      unzip
      vlc
      wget
      zip
      yarn
      zoom-us
    ];
  };

  fonts.fontconfig.enable = true;

  # TODO: Set keybinds?
  #dconf.settings = {}

  programs = {
    home-manager.enable = true;
    man.enable = true;
    vim.enable = true;
    bash.enable = true;
    zsh.enable = true;
    tmux.enable = true;
    starship = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      settings = {
        kubernetes.disabled = false;
        gcloud.format = "on [$symbol(@$domain)]($style) ";
      };
    };
    fzf = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
    };
    git = {
      enable = true;
      package = pkgs.gitFull;
      lfs.enable = true;
      extraConfig = {
        init.defaultBranch = "main";
        pull.ff = "only";
        push.autoSetupRemote = true;
      };
    };
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    vscode = {
      enable = true;
      extensions = with pkgs.vscode-extensions; [
        arrterian.nix-env-selector
        eamodio.gitlens
        github.copilot
        ms-azuretools.vscode-docker
        ms-python.python
        ms-python.vscode-pylance
        ms-toolsai.jupyter
        ms-vscode-remote.remote-ssh
        ms-vsliveshare.vsliveshare
      ];
      userSettings = {
        "files.autoSave" = "afterDelay";
        "editor.fontFamily" = "Hack Nerd Font";
        "editor.fontLigatures" = true;
        "editor.formatOnSave" = true;
        "editor.inlineSuggest.enabled" = true;
        "terminal.integrated.defaultProfile.linux" = "zsh";
        "terminal.integrated.defaultProfile.osx" = "zsh";
        "terminal.integrated.defaultProfile.windows" = "zsh";
        "github.copilot.enable" = {
          "*" = true;
          "yaml" = true;
          "plaintext" = true;
          "markdown" = true;
        };
      };
    };
  };
  
  # Hack to avoid VSCode complaining about non being able to write
  # to the settings file.
  # https://github.com/nix-community/home-manager/issues/1800#issuecomment-1059960604
  home.activation.beforeCheckLinkTargets = {
    after = [ ];
    before = [ "checkLinkTargets" ];
    data = ''
      rm -f ~/.config/Code/User/settings.json
    '';
  };
  home.activation.afterWriteBoundary = {
    after = [ "writeBoundary" ];
    before = [ ];
    data = ''
      cat ${(pkgs.formats.json {}).generate "settings.json" programs.vscode.userSettings} > ~/.config/Code/User/settings.json
    '';
  };
}
