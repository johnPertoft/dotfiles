{ pkgs, self, ... }: {
  type = "app";
  program = (pkgs.writeScript "switch-home" ''
    set -exuo pipefail
    #home-manager switch --flake ${self}
    home-manager switch --flake .#$(whoami)@${pkgs.system}
    home-manager packages
  '').outPath;
}
