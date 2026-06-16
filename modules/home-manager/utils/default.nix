{ pkgs
, ...
}:
{
  # General-purpose command-line utilities — single-purpose tools with no
  # config beyond their package, grouped here to keep the home module a
  # lean profile base.
  home.packages = with pkgs; [
    autossh
    coreutils-full
    curl
    fd
    fdupes
    file
    fx
    htop
    iftop
    jq
    mdcat
    ncdu_1
    nettools
    nmap
    pandoc
    pass
    pdfgrep
    phoronix-test-suite
    rclone
    restic
    ripgrep
    rsync
    runme
    tree
    typst
    wget
    wrk
    yq
  ];

  # Avoid having ncdu look through cloud storage and network shares.
  xdg.configFile."ncdu/config".source = (
    pkgs.writeText "ncdu-config" ''
      --one-file-system
    ''
  );
}
