{ pkgs, self, nix-darwin, ... }: pkgs.writeShellApplication {
  name = "switch-system";
  runtimeInputs =
    if pkgs.stdenv.hostPlatform.isLinux
    then [ pkgs.nixos-rebuild ]
    else [ nix-darwin.packages.${pkgs.system}.darwin-rebuild ];
  text =
    if pkgs.stdenv.hostPlatform.isLinux
    then "sudo nixos-rebuild switch --flake ${self}"
    else "darwin-rebuild switch --flake ${self}"
  ;
}


# { pkgs, self, ... }: {
#   type = "app";
#   program = (pkgs.writeScript "switch-system" ''
#     set -exuo pipefail
#     sudo nixos-rebuild switch --flake ${self}
#     nixos-version
#   '').outPath;
# }
