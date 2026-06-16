{ pkgs
, ...
}:
{
  # Discover fonts installed through home.packages.
  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    fantasque-sans-mono
    jetbrains-mono
    maple-mono.variable
    victor-mono
  ];
}
