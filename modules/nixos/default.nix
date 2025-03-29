{ ... }:
{
  desktop = import ./desktop.nix;
  cuda = import ./cuda.nix;
  vpn = import ./vpn.nix;
  default = import ./configuration.nix;
}
