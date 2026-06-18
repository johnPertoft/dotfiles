{
  rust = {
    path = ./rust;
    description = "Rust dev + build environment (rust-overlay + crane, optional CUDA)";
  };

  python-ml-uv = {
    path = ./python-ml-uv;
    description = "Python ML dev environment (uv + PyPI wheels, CUDA via wheel index)";
  };

  python-ml-uv2nix = {
    path = ./python-ml-uv2nix;
    description = "Python ML dev + reproducible build (uv2nix, lockfile-driven, CUDA)";
  };

  default = {
    path = ./python-ml-uv;
    description = "Alias for python-ml-uv";
  };
}
