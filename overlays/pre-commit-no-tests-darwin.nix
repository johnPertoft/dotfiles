_final: prev:
prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
  # Nixpkgs includes dotnet-sdk in pre-commit's test inputs even though its
  # .NET tests are disabled. The source-built .NET VMR is not consistently
  # available from the binary cache on Darwin, turning a routine update into
  # a multi-hour local build. Keep the upstream package unchanged elsewhere.
  #
  # TODO: Remove this overlay when nixpkgs no longer retains dotnet-sdk while
  # the .NET tests are disabled, or the Darwin VMR is reliably cached.
  pre-commit = prev.pre-commit.overridePythonAttrs (_: {
    doCheck = false;
    dontUsePytestCheck = true;
    nativeCheckInputs = [ ];
    preCheck = "";
  });
}
