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

  # Default startup setup when starting an IPython session.
  home.file.".ipython/profile_default/startup/setup.ipy".text = ''
    %pylab inline
    %load_ext autoreload
    %autoreload 2
  '';

  # Enable user programs.
  programs = {
    home-manager.enable = true;
    man.enable = true;
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
    gpg.enable = true;
    gitui.enable = true;
    pyenv.enable = true;
    #fd.enable = true;
    #poetry.enable = true;
    #alacritty.enable = true;
  };

  # Include additional user packages.
  home.packages = with pkgs; [
    act
    actionlint
    asdf-vm
    autoflake
    autossh
    black
    cmake
    commitizen
    cookiecutter
    copier
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
    git-filter-repo
    gnumake
    go
    go-tools
    gopls
    hadolint
    htop
    iftop
    isort
    jq
    jupyter
    #keepassxc
    llama-cpp
    lynis
    mdcat
    mypy
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
    pijul
    pipenv
    #pipx
    postgresql
    pre-commit
    pyenv
    pyupgrade
    rclone
    restic
    ripgrep
    rsync
    runme
    rustup
    shellcheck
    snyk
    spr
    sqlitebrowser
    syft
    tree
    typst
    uv
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
