{
  description = "Rust dev + build environment (rust-overlay + crane)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    crane.url = "github:ipetkov/crane";
  };

  outputs =
    { nixpkgs
    , flake-utils
    , rust-overlay
    , crane
    , ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        # ----------------------------------------------------------------
        # Knobs
        # ----------------------------------------------------------------
        # Flip this to wire CUDA (cudatoolkit + env) into the toolchain.
        # Only takes effect on Linux; ignored on darwin (no CUDA there).
        # Useful for crates like `cudarc` / `candle`.
        cudaSupport = false;

        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay) ];
          config.allowUnfree = cudaSupport;
        };

        inherit (pkgs) lib stdenv;
        cudaEnabled = cudaSupport && stdenv.hostPlatform.isLinux;

        # The toolchain (channel/version/components/targets) is pinned in
        # ./rust-toolchain.toml — edit that one file to change Rust version.
        rustToolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;

        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;

        cudaPkgs = lib.optionals cudaEnabled [
          pkgs.cudaPackages.cudatoolkit
        ];

        # On NixOS the GPU driver lives here; on plain Linux the host driver
        # must already be on the system path (see README notes on nix-ld).
        cudaLibPath = lib.optionalString cudaEnabled (
          lib.makeLibraryPath [
            pkgs.cudaPackages.cudatoolkit
            "/run/opengl-driver"
          ]
        );

        commonArgs = {
          src = craneLib.cleanCargoSource ./.;
          strictDeps = true;
          buildInputs = cudaPkgs;
          nativeBuildInputs = cudaPkgs;
        }
        // lib.optionalAttrs cudaEnabled {
          CUDA_ROOT = "${pkgs.cudaPackages.cudatoolkit}";
        };

        cargoArtifacts = craneLib.buildDepsOnly commonArgs;

        crate = craneLib.buildPackage (commonArgs // { inherit cargoArtifacts; });
      in
      {
        packages.default = crate;

        checks.default = crate;

        devShells.default = craneLib.devShell {
          packages =
            with pkgs;
            [
              rust-analyzer
              cargo-watch
              cargo-edit
            ]
            ++ cudaPkgs;

          shellHook = lib.optionalString cudaEnabled ''
            export CUDA_ROOT="${pkgs.cudaPackages.cudatoolkit}"
            export LD_LIBRARY_PATH="${cudaLibPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
          '';
        };
      }
    );
}
