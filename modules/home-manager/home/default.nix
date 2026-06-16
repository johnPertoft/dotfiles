{ config
, pkgs
, lib
, self
, ...
}@inputs:
{

  # Set environment variables.
  home.sessionVariables = {
    EDITOR = "~/.nix-profile/bin/vim";
    VISUAL = "~/.nix-profile/bin/code";
    #TODO This screws up SSH on macOS.
    #SHELL = "fish";
  };

  # Register shell aliases.
  home.shellAliases = {
    ll = "ls -al";
    icat = "kitten icat";
  };

  # Enable user programs.
  programs = {
    home-manager.enable = true;
    man.enable = true;
    gpg.enable = true;
    #fd.enable = true;
    #poetry.enable = true;
    #alacritty.enable = true;
  };

  # Packages that don't (yet) belong to a focused module: native-build
  # prerequisites, lint/CI/security tooling, cross-language helpers, and a
  # few specialised one-offs.
  home.packages = with pkgs; [
    act
    actionlint
    asdf-vm
    cmake
    ctags
    gcc
    gnumake
    hadolint
    #keepassxc
    llama-cpp
    lynis
    ninja
    #pipx
    pre-commit
    shellcheck
    snyk
    syft
  ];

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
