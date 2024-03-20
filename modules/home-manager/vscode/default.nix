{ config, pkgs, lib, self, ... }:
let
  settings-directory =
    if pkgs.stdenv.hostPlatform.isDarwin
    then "$HOME/Library/Application Support/Code/User"
    else "$HOME/.config/Code/User";

  userSettings = builtins.fromJSON (builtins.readFile "${self}/modules/home-manager/vscode/settings.json");

  extensions = with pkgs.vscode-extensions; [
    eamodio.gitlens
    esbenp.prettier-vscode
    github.copilot
    hashicorp.terraform
    jnoortheen.nix-ide
    ms-azuretools.vscode-docker
    ms-python.python
    ms-python.vscode-pylance
    ms-toolsai.jupyter
    # ms-vscode-remote.remote-containers  # TODO: Only old version available in nixpkgs
    # ms-vscode-remote.remote-ssh  # TODO: Not compatible with non nixpkgs remote-containers?
    ms-vsliveshare.vsliveshare
    redhat.vscode-yaml
    rust-lang.rust-analyzer
    tamasfe.even-better-toml
  ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
    {
      name = "copilot-chat";
      publisher = "github";
      version = "0.8.0";
      sha256 = "IJ75gqsQj0Ukjlrqevum5AoaeZ5vOfxX/4TceXe+EIg=";
    }
    {
      name = "remote-containers";
      publisher = "ms-vscode-remote";
      version = "0.349.0";
      sha256 = "sha256-2cSa1gXCDN3vjUTLmJ3flZ8hvcSZERyBuFXZ6tGCKk8=";
    }
    {
      name = "remote-ssh";
      publisher = "ms-vscode-remote";
      version = "0.110.2024030815";
      sha256 = "sha256-ZgU1IxnZDEF/H6O4d86qjCysK/deiLlHDUCbLIvcT7E=";
    }
  ];
in
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    userSettings = userSettings;
    extensions = extensions;

    # We don't want VSCode to autoupdate extensions to avoid weird states.
    mutableExtensionsDir = false;
  };

  # VSCode settings as a mutable copy of the user settings defined here
  # to avoid write errors.
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
        mkdir -p "${settings-directory}"
        cat ${(pkgs.formats.json {}).generate "settings.json" userSettings} > "${settings-directory}/settings.json"
      '';
    };
  };
}
