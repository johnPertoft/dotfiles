{ config
, pkgs
, lib
, nix-vscode-extensions
, ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;

  defaultExtensions = {
    "remote.SSH.defaultExtensions" = map (x: x.vscodeExtUniqueId) extensions;
  };
  userSettings = (builtins.fromJSON (builtins.readFile ./settings.json)) // defaultExtensions;
  keybindings = builtins.fromJSON (builtins.readFile ./keybindings.json);

  extensions = import ./extensions.nix {
    inherit pkgs;
    vscode-extensions = nix-vscode-extensions.extensions.${system};
  };
in
{
  programs.vscode = {
    enable = true;
    profiles.default = {
      inherit
        userSettings
        extensions
        keybindings
        ;
      enableUpdateCheck = false;
      enableExtensionUpdateCheck = false;
    };
    mutableExtensionsDir = false;
    package = if pkgs.config.allowUnfreePredicate "vscode" then pkgs.vscode else pkgs.vscodium;
  };
}
