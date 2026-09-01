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

  inherit (import ../../lib/mutable-merge.nix { inherit pkgs lib; })
    mkMutableMerge jqMerge jqDiff;

  # Mirrors the userDir computation in the upstream home-manager vscode module.
  # The home.file key uses the absolute path as the key on both platforms.
  vscodeSettingsPath =
    if pkgs.stdenv.hostPlatform.isDarwin
    then "${config.home.homeDirectory}/Library/Application Support/Code/User/settings.json"
    else "${config.xdg.configHome}/Code/User/settings.json";
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

  # Suppress the read-only symlink that programs.vscode generates — the
  # activation script below writes a mutable copy instead, so VS Code can
  # write back to it (e.g. extension defaults, setting migrations).
  home.file."${vscodeSettingsPath}".enable = lib.mkForce false;

  home.activation.mergeVscodeSettings = mkMutableMerge {
    label = "vscode settings.json";
    nixFile = config.home.file."${vscodeSettingsPath}".source;
    liveFile = vscodeSettingsPath;
    mergeCmd = jqMerge;
    diffCmd = jqDiff;
  };
}
