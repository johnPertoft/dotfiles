{ config
, pkgs
, lib
, self
, ...
}@inputs:
{

  # Set environment variables.
  home.sessionVariables = {
    EDITOR = "${config.home.homeDirectory}/.nix-profile/bin/vim";
    VISUAL = "${config.home.homeDirectory}/.nix-profile/bin/code";
    #TODO This screws up SSH on macOS.
    #SHELL = "fish";
  };

  # Register shell aliases.
  home.shellAliases = {
    ll = "ls -al";
  };

  # Enable user programs.
  programs = {
    home-manager.enable = true;
    man.enable = true;
    #fd.enable = true;
  };

  # Check for release version mismatch between Home Manager and nixpkgs.
  home.enableNixpkgsReleaseCheck = true;

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "22.11"; # Please read the comment before changing.
}
