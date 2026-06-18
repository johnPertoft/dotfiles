{ pkgs
, ...
}:
{
  # GnuPG for key management, signing, and encryption.
  programs.gpg.enable = true;

  # Security scanning / auditing tooling.
  home.packages = with pkgs; [
    lynis
    snyk
    syft
  ];
}
