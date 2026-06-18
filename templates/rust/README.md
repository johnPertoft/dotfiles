# Rust template

Dev shell + reproducible build for Rust, using
[rust-overlay](https://github.com/oxalica/rust-overlay) for the toolchain and
[crane](https://github.com/ipetkov/crane) for cached cargo builds.

## Usage

```bash
nix develop          # dev shell with the toolchain + cargo-watch/edit, rust-analyzer
nix build            # builds the crate -> ./result/bin/app
nix flake check      # builds + runs checks
```

With direnv: `direnv allow` and the shell loads automatically.

## Choosing the Rust version

Edit `rust-toolchain.toml` — it is the single source of truth. Set `channel`
to `"stable"`, `"nightly"`, a dated nightly (`"nightly-2025-01-01"`), or an
exact release (`"1.89.0"`). Add cross targets under `targets`.

## CUDA

Set `cudaSupport = true` at the top of `flake.nix`. This wires
`cudaPackages.cudatoolkit` into the build/dev shell and sets `CUDA_ROOT` +
`LD_LIBRARY_PATH` — useful for crates like `cudarc` / `candle`.

- Only takes effect on **Linux** (ignored on darwin; no CUDA there).
- On **NixOS** the GPU driver is picked up from `/run/opengl-driver`.
- On **plain Linux** the host NVIDIA driver (`libcuda.so`) must be reachable.
  The cleanest fix is [`nix-ld`](https://github.com/Mic92/nix-ld) or running
  via [`nixGL`](https://github.com/nix-community/nixGL).
