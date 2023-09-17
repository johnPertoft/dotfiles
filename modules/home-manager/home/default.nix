{ config, pkgs, lib, nixpkgs, nixpkgs-unstable, ... }: {
  
  nix = {
    registry.nixpkgs.flake = nixpkgs;
    registry.nixpkgs-unstable.flake = nixpkgs-unstable;
  };

  home = {
    stateVersion = "22.11";
    enableNixpkgsReleaseCheck = true;
    sessionVariables = {
      DOCKER_BUILDKIT = "1";
      EDITOR = "code";
    };
  };

  fonts.fontconfig.enable = true;

  programs = {
    home-manager.enable = true;
    man.enable = true;
    bash.enable = true;
    zsh.enable = true;
    fish.enable = true;
    nushell.enable = true;
    tmux.enable = true;
    fzf = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      enableFishIntegration = true;
    };
    starship = {
      enable = true;
      enableZshIntegration = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      settings = {
        kubernetes.disabled = false;
        gcloud.format = "on [$symbol(@$domain)]($style) ";
      };
    };
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    gh = {
      enable = true;
      settings.git_protocol = "ssh";
      enableGitCredentialHelper = false;
    };
  }
}