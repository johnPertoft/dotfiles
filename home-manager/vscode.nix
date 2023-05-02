{ config, pkgs, lib, ... }: rec {
  nixpkgs.config = {
    allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
      "vscode"
      "vscode-extension-github-copilot"
      "vscode-extension-MS-python-vscode-pylance"
      "vscode-extension-ms-vscode-remote-remote-ssh"
      "vscode-extension-ms-vsliveshare-vsliveshare"
    ];
  };

  programs.vscode = {
    enable = true;
    extensions = with pkgs.vscode-extensions; [
      arrterian.nix-env-selector
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
    userSettings = {
      "files.autoSave" = "afterDelay";
      "editor.fontFamily" = "Hack Nerd Font";
      "editor.fontLigatures" = true;
      "editor.formatOnSave" = true;
      "editor.inlineSuggest.enabled" = true;
      "terminal.integrated.defaultProfile.linux" = "zsh";
      "terminal.integrated.defaultProfile.osx" = "zsh";
      "terminal.integrated.defaultProfile.windows" = "zsh";
      "github.copilot.enable" = {
        "*" = true;
        "yaml" = true;
        "plaintext" = true;
        "markdown" = true;
      };
    };
  };

  # Hack to avoid VSCode complaining about non being able to write
  # to the settings file.
  # https://github.com/nix-community/home-manager/issues/1800#issuecomment-1059960604
  home.activation.beforeCheckLinkTargets = {
    after = [ ];
    before = [ "checkLinkTargets" ];
    data = ''
      rm -f ~/.config/Code/User/settings.json
    '';
  };
  home.activation.afterWriteBoundary = {
    after = [ "writeBoundary" ];
    before = [ ];
    data = ''
      mkdir -p ~/.config/Code/User
      cat ${(pkgs.formats.json {}).generate "settings.json" programs.vscode.userSettings} > ~/.config/Code/User/settings.json
    '';
  };
}
