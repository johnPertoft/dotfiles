{ ... }:
{
  desktop = import ./desktop.nix;
  server = import ./server.nix;
  cuda = import ./cuda.nix;
  gaming = import ./gaming.nix;
  default = import ./configuration.nix;
}
