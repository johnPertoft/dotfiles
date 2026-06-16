{ pkgs
, ...
}:
{
  programs.pyenv.enable = true;

  # Default startup setup when starting an IPython session.
  home.file.".ipython/profile_default/startup/setup.ipy".text = ''
    %pylab inline
    %load_ext autoreload
    %autoreload 2
  '';

  home.packages = with pkgs; [
    autoflake
    black
    cookiecutter
    copier
    isort
    jupyter
    mypy
    pipenv
    pyupgrade
    uv
  ];
}
