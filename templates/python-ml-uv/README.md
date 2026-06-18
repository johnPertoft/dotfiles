# Python ML template (uv + PyPI wheels)

A light, fast dev environment matching the usual ML workflow: nix supplies the
interpreter, [uv](https://github.com/astral-sh/uv) manages everything else into
a `.venv` from PyPI wheels. CUDA-enabled torch wheels bundle their own CUDA
runtime, so there's nothing heavy to build.

> For a **fully reproducible, nix-built** artifact (`nix build`), use the
> `python-ml-uv2nix` template instead. This template's build path is `uv build`.

## Usage

```bash
nix develop            # python + uv; creates/syncs .venv and activates it
uv run python -m app   # run the sample
uv add <pkg>           # add a dependency
nix run .#build        # uv build -> ./dist (wheel + sdist)
```

With direnv: `direnv allow`.

## Choosing the Python version

One line in `flake.nix`: `python = pkgs.python312;` (and keep
`requires-python` in `pyproject.toml` consistent).

## CUDA vs CPU

Selected via the torch wheel index in `pyproject.toml`
(`[[tool.uv.index]]` + `[tool.uv.sources]`):

- Default: CUDA (`cu124`) wheels on Linux, CPU wheels elsewhere (darwin uses
  MPS).
- For CPU-only on Linux, point the index at
  `https://download.pytorch.org/whl/cpu`.

Runtime driver notes:

- **NixOS** — the GPU driver in `/run/opengl-driver/lib` is added to
  `LD_LIBRARY_PATH` automatically.
- **plain Linux** — the host NVIDIA driver (`libcuda.so`) must be reachable;
  use [`nix-ld`](https://github.com/Mic92/nix-ld) or
  [`nixGL`](https://github.com/nix-community/nixGL).
- **darwin** — no CUDA; torch falls back to CPU/MPS.
