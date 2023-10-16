{ pkgs, lib, ... }: {
  home.packages = with pkgs; [
    act
    actionlint
    awscli
    binutils
    black
    buildah
    buildkit
    cachix
    cmake
    comma
    coreutils-full
    curl
    dive
    docker-client
    docker-slim
    fantasque-sans-mono
    ffmpeg-full
    file
    firefox
    gcc
    gnumake
    gnupg
    google-chrome
    (google-cloud-sdk.withExtraComponents (with google-cloud-sdk.components; [
      gke-gcloud-auth-plugin
    ]))
    htop
    imagemagick
    isort
    jq
    kind
    kubectl
    kubectx
    kubernetes-helm
    minikube
    mypy
    nerdfonts
    ninja
    nix-init
    nix-tree
    nix-diff
    nix-info
    nixfmt
    nixpkgs-fmt
    nodejs
    nodePackages.npm
    nodePackages.prettier
    pdfgrep
    pdm
    pipenv
    pipx
    podman
    poetry
    postgresql
    pre-commit
    python3
    python3Packages.pip
    python3Packages.tensorboard
    rclone
    ripgrep
    rsync
    rustup
    shellcheck
    slack
    spotify
    skaffold
    terraform
    transmission-gtk
    tree
    wget
    zip
    yarn
    zoom-us
  ] ++ (with pkgs.gnomeExtensions;
    [
      blur-my-shell
      hue-lights
      rounded-window-corners
    ]);

  # Use `dconf watch /` to track stateful changes you are doing, then set them here.
  dconf.settings = {
    "org/gnome/shell" = {
      enabled-extensions = [
        "appindicatorsupport@rgcjonas.gmail.com"
        "apps-menu@gnome-shell-extensions.gcampax.github.com"
        "blur-my-shell@aunetx"
        "hue-lights@chlumskyvaclav.gmail.com"
        "places-menu@gnome-shell-extensions.gcampax.github.com"
        "rounded-window-corners@yilozt"
      ];
    };
  };

  nixpkgs.config = {
    allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
      "discord"
      "dropbox"
      "google-chrome"
      "slack"
      "spotify"
      "vscode"
      "vscode-extension-github-copilot"
      "vscode-extension-MS-python-vscode-pylance"
      "vscode-extension-ms-vscode-cpptools"
      "vscode-extension-ms-vscode-remote-remote-ssh"
      "vscode-extension-ms-vsliveshare-vsliveshare"
      "zoom"
    ];
  };
}
