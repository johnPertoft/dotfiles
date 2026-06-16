{ config
, pkgs
, lib
, self
, ...
}@inputs:
{

  # Set environment variables.
  home.sessionVariables = {
    EDITOR = "~/.nix-profile/bin/vim";
    VISUAL = "~/.nix-profile/bin/code";
    #TODO This screws up SSH on macOS.
    #SHELL = "fish";
  };

  # Register shell aliases.
  home.shellAliases = {
    ll = "ls -al";
    icat = "kitten icat";
  };

  # Enable user programs.
  programs = {
    home-manager.enable = true;
    man.enable = true;
    gpg.enable = true;
    #fd.enable = true;
    #poetry.enable = true;
    #alacritty.enable = true;
  };

  # Include additional user packages.
  home.packages = with pkgs; [
    act
    actionlint
    asdf-vm
    autossh
    cmake
    coreutils-full
    ctags
    curl
    delve
    duckdb
    fd
    fdupes
    file
    fx
    gcc
    gnumake
    go
    go-tools
    gopls
    hadolint
    htop
    iftop
    jq
    #keepassxc
    llama-cpp
    lynis
    mdcat
    ncdu_1
    nettools
    ninja
    nmap
    #nodejs
    #nodePackages.npm
    #nodePackages.prettier
    pandoc
    pass
    pdfgrep
    phoronix-test-suite
    #pipx
    postgresql
    pre-commit
    rclone
    restic
    ripgrep
    rsync
    runme
    rustup
    shellcheck
    snyk
    sqlitebrowser
    syft
    tree
    typst
    visidata
    wget
    wrk
    yarn
    yq
  ];

  # Avoid having ncdu look through cloud storage and network shares.
  xdg.configFile."ncdu/config".source = (
    pkgs.writeText "ncdu-config" ''
      --one-file-system
    ''
  );

  # Check for release version mismatch between Home Manager and nixpkgs.
  home.enableNixpkgsReleaseCheck = true;

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "22.11"; # Please read the comment before changing.
}
