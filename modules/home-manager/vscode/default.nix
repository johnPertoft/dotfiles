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
    ms-vscode-remote.remote-ssh
    ms-vsliveshare.vsliveshare
    redhat.vscode-yaml
    rust-lang.rust-analyzer
    tamasfe.even-better-toml
  ];
in
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    userSettings = userSettings;
    extensions = extensions;
  };

  home.activation = {
    beforeCheckLinkTargets = {
      after= [ ];
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
