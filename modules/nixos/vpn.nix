{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    gpclient
  ];
}
