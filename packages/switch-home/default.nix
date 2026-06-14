{ pkgs
, self
, home-manager
, ...
}:
pkgs.writeShellApplication {
  name = "switch-home";
  runtimeInputs = [ home-manager.packages.${pkgs.stdenv.hostPlatform.system}.home-manager ];
  text = "home-manager switch --flake ${self} \"$@\"";
}
