{ config
, pkgs
, lib
, nix-vscode-extensions
, ...
}:
let
  settings-directory =
    if pkgs.stdenv.hostPlatform.isDarwin then
      "$HOME/Library/Application Support/Code/User"
    else
      "$HOME/.config/Code/User";
  defaultExtensions = {
    "remote.SSH.defaultExtensions" = map (x: x.vscodeExtUniqueId) extensions;
  };
  userSettings = (builtins.fromJSON (builtins.readFile ./settings.json)) // defaultExtensions;
  userTasks = builtins.fromJSON (builtins.readFile ./tasks.json);

  extensions = import ./extensions.nix {
    inherit pkgs;
    vscode-extensions = nix-vscode-extensions.extensions.${pkgs.system};
  };
in
{
  programs.vscode = {
    inherit
      userSettings
      userTasks
      extensions
      ;
    enable = true;
    enableUpdateCheck = false;
    enableExtensionUpdateCheck = false;
    mutableExtensionsDir = false;
    package = if pkgs.config.allowUnfreePredicate "vscode" then pkgs.vscode else pkgs.vscodium;
  };

  # Copy VS Code settings into the default location as a mutable copy.
  home.activation = {
    beforeCheckLinkTargets = {
      after = [ ];
      before = [ "checkLinkTargets" ];
      data = ''
        if [ -f "${settings-directory}/settings.json" ]; then
          rm "${settings-directory}/settings.json"
        fi
      '';
    };

    afterWriteBoundary = {
      after = [ "writeBoundary" ];
      before = [ ];
      data = ''
        cat ${
          (pkgs.formats.json { }).generate "settings.json" userSettings
        } > "${settings-directory}/settings.json"
      '';
    };
  };
}

# { config, pkgs, lib, self, ... }:
# let
#   settings-directory =
#     if pkgs.stdenv.hostPlatform.isDarwin
#     then "$HOME/Library/Application Support/Code/User"
#     else "$HOME/.config/Code/User";

#   userSettings = builtins.fromJSON (builtins.readFile "${self}/modules/home-manager/vscode/settings.json");

#   extensions = with pkgs.vscode-extensions; [
#     eamodio.gitlens
#     esbenp.prettier-vscode
#     # github.copilot
#     hashicorp.terraform
#     jnoortheen.nix-ide
#     ms-azuretools.vscode-docker
#     ms-python.python
#     ms-python.vscode-pylance
#     ms-toolsai.jupyter
#     # ms-vscode-remote.remote-containers  # TODO: Only old version available in nixpkgs
#     # ms-vscode-remote.remote-ssh  # TODO: Not compatible with non nixpkgs remote-containers?
#     ms-vsliveshare.vsliveshare
#     redhat.vscode-yaml
#     rust-lang.rust-analyzer
#     tamasfe.even-better-toml
#   ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
#     {
#       name = "copilot";
#       publisher = "github";
#       version = "1.195.0";
#       sha256 = "sha256-Hu+QfKu6mHp7+AkZgv7mSViO1SP93gkOBHMdSzYnloQ=";
#     }
#     {
#       name = "copilot-chat";
#       publisher = "github";
#       version = "0.16.2024052402";
#       sha256 = "sha256-DB0nCVQJuOnjXt41NjdOCD/a13HvjvWDfay3RoL6VUE=";
#     }
#     {
#       name = "remote-containers";
#       publisher = "ms-vscode-remote";
#       version = "0.366.0";
#       sha256 = "sha256-Etc/rjwJ47pRjyuLOCf2czlstHs4t71ooC+SvAFzZFY=";
#     }
#     {
#       name = "remote-ssh";
#       publisher = "ms-vscode-remote";
#       version = "0.112.2024051615";
#       sha256 = "sha256-vnfqb8Bc7UkAUkfNVhazRSubYl/jinaD9wTcxyjwu1k=";
#     }
#   ];
# in
# {
#   programs.vscode = {
#     enable = true;
#     package = pkgs.vscode;
#     userSettings = userSettings;
#     extensions = extensions;

#     # We don't want VSCode to autoupdate extensions to avoid weird states.
#     mutableExtensionsDir = false;
#   };

#   # VSCode settings as a mutable copy of the user settings defined here
#   # to avoid write errors.
#   home.activation = {
#     beforeCheckLinkTargets = {
#       after = [ ];
#       before = [ "checkLinkTargets" ];
#       data = ''
#         if [ -f "${settings-directory}/settings.json" ]; then
#           rm "${settings-directory}/settings.json"
#         fi
#       '';
#     };

#     afterWriteBoundary = {
#       after = [ "writeBoundary" ];
#       before = [ ];
#       data = ''
#         mkdir -p "${settings-directory}"
#         cat ${(pkgs.formats.json {}).generate "settings.json" userSettings} > "${settings-directory}/settings.json"
#       '';
#     };
#   };
# }
