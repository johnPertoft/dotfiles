{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    globalprotect-openconnect
  ];
}
