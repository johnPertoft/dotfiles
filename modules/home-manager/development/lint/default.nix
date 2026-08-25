{ pkgs
, ...
}:
{
  # Linters and the pre-commit framework that orchestrates them.
  home.packages = with pkgs; [
    actionlint
    hadolint
    (pre-commit.overridePythonAttrs (_: {
      doCheck = false;
      dontUsePytestCheck = true;
      nativeCheckInputs = [ ];
      preCheck = "";
    }))
    shellcheck
  ];
}
