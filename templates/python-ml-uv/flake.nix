{
  description = "Python ML dev environment (uv + PyPI wheels)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { nixpkgs
    , flake-utils
    , ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        inherit (pkgs) lib stdenv;

        # ----------------------------------------------------------------
        # Knobs
        # ----------------------------------------------------------------
        # Pick the interpreter. uv installs everything else into a venv from
        # PyPI wheels (CUDA-enabled torch wheels bundle their own CUDA libs;
        # select the index in pyproject.toml -> [[tool.uv.index]]).
        python = pkgs.python312;

        # Runtime libs that manylinux wheels (numpy, torch, ...) expect to
        # dlopen at import time but don't ship themselves.
        runtimeLibs = [
          pkgs.stdenv.cc.cc.lib # libstdc++ / libgcc
          pkgs.zlib
        ];

        libPath = lib.makeLibraryPath runtimeLibs;
      in
      {
        # `uv build` is the build path here (PEP 517 wheel/sdist). For a
        # *pure* nix-built artifact, use the python-ml-uv2nix template instead.
        apps.build = {
          type = "app";
          program = toString (
            pkgs.writeShellScript "uv-build" ''
              exec ${pkgs.uv}/bin/uv build "$@"
            ''
          );
        };

        devShells.default = pkgs.mkShell {
          packages = [
            python
            pkgs.uv
          ];

          env = {
            # Keep uv from trying to download/manage its own interpreter.
            UV_PYTHON = "${python}/bin/python";
            UV_PYTHON_DOWNLOADS = "never";
          };

          shellHook = ''
            # Let manylinux wheels find their runtime deps. On NixOS the GPU
            # driver is added so CUDA wheels can dlopen libcuda.so; on plain
            # Linux the host driver path must already be present (see README).
            export LD_LIBRARY_PATH="${libPath}${lib.optionalString stdenv.hostPlatform.isLinux ":/run/opengl-driver/lib"}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

            # Create / sync the venv on entry.
            uv sync --frozen 2>/dev/null || uv sync
            source .venv/bin/activate
          '';
        };
      }
    );
}
