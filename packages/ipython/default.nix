{ pkgs, ... }:
pkgs.buildEnv {
  name = "ipython";
  paths = [
    (pkgs.python3.withPackages (ps: with ps; [
      ipython
      jax
      jaxlib
      # jaxlibWithCuda
      jupyter
      matplotlib
      numpy
      pandas
      scikit-learn
      scipy
      torch
    ]))
  ];
  meta = {
    description = "Python environment for ml / data science stuff";
  };
}
