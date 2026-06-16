{ pkgs
, ...
}:
{
  # Linters and the pre-commit framework that orchestrates them.
  home.packages = with pkgs; [
    actionlint
    hadolint
    pre-commit
    shellcheck
  ];
}
