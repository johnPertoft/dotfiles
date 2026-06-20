{ pkgs
, ...
}:
{
  # Native-build prerequisites used across C/C++ and other compiled tooling.
  home.packages = with pkgs; [
    ccache
    cmake
    gcc
    gnumake
    ninja
  ];
}
