# Python ML template (uv2nix, reproducible)

Lockfile-driven, fully reproducible Python env built by nix from `uv.lock` via
[uv2nix](https://github.com/pyproject-nix/uv2nix). You still author deps with
`uv` (PyPI wheels — so CUDA-enabled torch wheels bundle their own CUDA), but the
environment and the build artifact are produced by nix.

## Usage

```bash
nix develop          # editable dev shell (project installed editable)
nix build            # reproducible venv closure -> ./result
nix run              # runs the `app` entry point from the built venv

uv add <pkg>         # add a dep, then:
uv lock              # refresh uv.lock (nix reads it)
```

With direnv: `direnv allow`.

## Choosing the Python version

`python = pkgs.python312;` in `flake.nix` (keep `requires-python` consistent).

## CUDA vs CPU

Selected via the torch wheel index in `pyproject.toml` and baked into
`uv.lock` (`uv lock` after changing it). Default: `cu124` on Linux, CPU/MPS
elsewhere. For CPU-only on Linux use `https://download.pytorch.org/whl/cpu`.

If a wheel fails to find a system lib at import, add it under
`pyprojectOverrides` in `flake.nix` (there's a commented torch example).

Driver notes:

- **NixOS** — driver from `/run/opengl-driver/lib` is on `LD_LIBRARY_PATH`.
- **plain Linux** — host NVIDIA driver must be reachable;
  [`nix-ld`](https://github.com/Mic92/nix-ld) /
  [`nixGL`](https://github.com/nix-community/nixGL).
- **darwin** — no CUDA; CPU/MPS only.
