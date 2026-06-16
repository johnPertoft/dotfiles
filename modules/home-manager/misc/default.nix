{ pkgs
, ...
}:
{
  # Uncategorised packages that don't (yet) warrant a focused module:
  # linters (actionlint/hadolint/shellcheck) + pre-commit, native-build
  # prerequisites (gcc/cmake/gnumake/ninja), and a few cross-language
  # helpers / one-offs (act, ctags, asdf-vm).
  home.packages = with pkgs; [
    act
    actionlint
    asdf-vm
    cmake
    ctags
    gcc
    gnumake
    hadolint
    ninja
    pre-commit
    shellcheck
  ];
}
