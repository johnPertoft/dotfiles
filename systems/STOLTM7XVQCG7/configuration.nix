{ pkgs, ... }:
{
  networking.hostName = "STOLTM7XVQCG7";

  system.primaryUser = "john.pertoft";

  # Use Touch ID for sudo.
  security.pam.services.sudo_local.touchIdAuth = true;

  # Default interactive shells nix-darwin will manage.
  programs.zsh.enable = true;

  # System packages — most user-facing tools live in home-manager.
  environment.systemPackages = with pkgs; [
    clang
    coreutils
    findutils
    gcc-unwrapped
    git
    gnumake
    unixtools.watch
    vim
  ];

  # Deduplicate files in the nix store.
  nix.optimise.automatic = true;

  # Required. Increment when nix-darwin release notes say so.
  system.stateVersion = 6;
}
