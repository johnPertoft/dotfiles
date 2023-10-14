{ config, pkgs, ... }:
{
  networking.hostName = "nixos";

  users.users.john = {
    isNormalUser = true;
    description = "John Pertoft";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    packages = with pkgs; [ ];
  };

  nixpkgs.config = {
    cudaSupport = true;
    cudnnSupport = true;
    allowUnfree = true;
  };
}
