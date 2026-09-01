{
  description = "Python ML dev + reproducible build (uv2nix, lockfile-driven)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs
    , flake-utils
    , pyproject-nix
    , uv2nix
    , pyproject-build-systems
    , ...
    }:
    let
      inherit (nixpkgs) lib;

      # Load the uv workspace (reads pyproject.toml + uv.lock).
      workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };

      # Prefer prebuilt wheels — important for ML: CUDA-enabled torch wheels
      # bundle their own CUDA runtime, so nothing heavy is compiled.
      overlay = workspace.mkPyprojectOverlay {
        sourcePreference = "wheel";
      };

      # Fixups for wheels that dlopen libs they don't declare. manylinux
      # wheels (torch, numpy, ...) need libstdc++ etc.; the pyproject.nix
      # build infra autoPatchelfs them — extra libs go here.
      pyprojectOverrides = final: prev: {
        # Example (uncomment + adjust if a wheel fails to find a lib):
        # torch = prev.torch.overrideAttrs (old: {
        #   buildInputs = (old.buildInputs or [ ]) ++ [
        #     final.pkgs.zlib
        #     final.pkgs.stdenv.cc.cc.lib
        #   ];
        # });
      };
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Pick the interpreter here (keep `requires-python` in pyproject.toml
        # consistent).
        python = pkgs.python312;

        pythonSet = (pkgs.callPackage pyproject-nix.build.packages { inherit python; }).overrideScope (
          lib.composeManyExtensions [
            pyproject-build-systems.overlays.default
            overlay
            pyprojectOverrides
          ]
        );

        # Reproducible, nix-built virtual environment with all deps.
        venv = pythonSet.mkVirtualEnv "app-env" workspace.deps.default;
      in
      {
        # `nix build` -> a closure containing the full venv (your app + deps).
        packages.default = venv;

        # `nix run` -> run the app's entry point from that venv.
        apps.default = {
          type = "app";
          program = "${venv}/bin/app";
        };

        # Editable dev shell: the project is installed editable, deps come
        # from the pinned set. Uses uv only for resolution, never for installs.
        devShells.default =
          let
            editableOverlay = workspace.mkEditablePyprojectOverlay {
              root = "$REPO_ROOT";
            };
            editablePythonSet = pythonSet.overrideScope (
              lib.composeManyExtensions [
                editableOverlay
                (final: prev: {
                  app = prev.app.overrideAttrs (old: {
                    src = lib.fileset.toSource {
                      root = old.src;
                      fileset = lib.fileset.unions [
                        (old.src + "/pyproject.toml")
                        (old.src + "/README.md")
                        (old.src + "/src")
                      ];
                    };
                    nativeBuildInputs = old.nativeBuildInputs ++ final.resolveBuildSystem { editables = [ ]; };
                  });
                })
              ]
            );
            editableVenv = editablePythonSet.mkVirtualEnv "app-dev-env" workspace.deps.all;
          in
          pkgs.mkShell {
            packages = [
              editableVenv
              pkgs.uv
            ];

            env = {
              UV_NO_SYNC = "1";
              UV_PYTHON = "${editableVenv}/bin/python";
              UV_PYTHON_DOWNLOADS = "never";
            };

            shellHook = ''
              unset PYTHONPATH
              export REPO_ROOT=$(git rev-parse --show-toplevel)
              # On plain Linux a host NVIDIA driver must be reachable for CUDA
              # wheels; NixOS exposes it under /run/opengl-driver (see README).
              ${lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
                export LD_LIBRARY_PATH="/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
              ''}
            '';
          };
      }
    );
}
