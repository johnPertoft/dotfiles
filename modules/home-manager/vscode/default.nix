{ config, pkgs, lib, self, ... }:
let
  settings-directory =
    if pkgs.stdenv.hostPlatform.isDarwin
    then "$HOME/Library/Application Support/Code/User"
    else "$HOME/.config/Code/User";

  extensions = with pkgs.vscode-extensions; [
    eamodio.gitlens
    github.copilot
    matklad.rust-analyzer
    ms-azuretools.vscode-docker
    ms-python.python
    ms-python.vscode-pylance
    ms-toolsai.jupyter
    ms-vscode-remote.remote-ssh
    ms-vsliveshare.vsliveshare
  ];
in
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
  }

#   home.activation = {
#     # TODO
#   };
}