{ pkgs, ... }:
{
  # Use Touch ID for sudo.
  security.pam.services.sudo_local.touchIdAuth = true;

  # Default interactive shells nix-darwin will manage.
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    enableSyntaxHighlighting = true;
  };

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

  # Global shell aliases.
  environment.shellAliases = {
    show-system = "nix derivation show /run/current-system";
    switch-system = "nh darwin switch .";
    list-generations = "nix-env --list-generations";
  };
}
