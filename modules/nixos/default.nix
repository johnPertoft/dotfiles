{ ... }:
{
  desktop = import ./desktop.nix;
  cuda = import ./cuda.nix;
  default = import ./configuration.nix;
}
