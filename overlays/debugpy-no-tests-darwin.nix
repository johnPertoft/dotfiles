_final: prev:
prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
  # debugpy (pulled in by the vscode ms-python.python extension) fails several
  # tests on Darwin, e.g. test_lldb_command expects a bare `lldb` while nixpkgs
  # patches in the store path. It isn't cached either, so the suite would also
  # add a long local build. Applied to the nixpkgs-unstable import that
  # provides vscode-extensions.
  #
  # TODO: Remove once Hydra builds debugpy on aarch64-darwin again
  # (NixOS/nixpkgs#572564 fixes the lldb test).
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (_pyFinal: pyPrev: {
      debugpy = pyPrev.debugpy.overridePythonAttrs (_: {
        doCheck = false;
        dontUsePytestCheck = true;
      });
    })
  ];
}
