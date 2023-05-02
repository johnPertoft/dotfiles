{ config, pkgs, lib, ... }: {
  imports = [
    ./vscode.nix
    ./vim.nix
    ./git.nix
  ];

  home = {
    stateVersion = "22.11";
    userName = "john";
    homeDirectory = "/home/john";
    enableNixpkgsReleaseCheck = true;
    sessionVariables = {
      DOCKER_BUILDKIT = true;
      EDITOR = "vim";
    };
  };

  # TODO
  # home.shellAliases = {}

  fonts.fontconfig.enable = true;

  # TODO: Set keybinds?
  #dconf.settings = {}

  home.packages = with pkgs; [
    awscli
    bazel
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
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}