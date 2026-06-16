{ pkgs
, ...
}:
{
  # Security scanning / auditing tooling.
  home.packages = with pkgs; [
    lynis
    snyk
    syft
  ];
}
