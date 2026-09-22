{ config, pkgs, ... }:
{
  nix.settings.substituters = [
    "https://cache.nixos-cuda.org"
  ];

  nix.settings.trusted-public-keys = [
    "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
  ];

  nixpkgs.config = {
    cudaSupport = true;
    cudnnSupport = true;
    allowUnfree = true;
  };

  # Open kernel module is required on Blackwell (RTX 50xx) and newer.
  hardware.nvidia.open = true;
  # hardware.nvidia.modesetting.enable = true;
  # hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.production;
  hardware.nvidia-container-toolkit.enable = true;

  services.xserver.videoDrivers = [ "nvidia" ];

  environment.systemPackages = with pkgs; [
    cudatoolkit
    cudaPackages.cudnn
  ];
}
