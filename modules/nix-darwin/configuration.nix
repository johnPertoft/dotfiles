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

  # Needed in addition to home-manager's `programs.fish.enable`: that one only
  # writes ~/.config/fish, while this puts fish in the *system* profile so
  # /run/current-system/sw/bin/fish exists — which is the path environment.shells
  # below points at.
  programs.fish.enable = true;

  # Add fish to /etc/shells so `chsh` accepts it. The seven default macOS
  # shells are preserved automatically by nix-darwin, so this only appends.
  #
  # Selecting the login shell stays manual, once per machine:
  #   chsh -s /run/current-system/sw/bin/fish
  # The declarative users.users.<name>.shell isn't used because its activation
  # is gated on users.knownUsers, and that option is documented as being for
  # accounts nix-darwin may freely create and delete.
  environment.shells = with pkgs; [ fish ];

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

  # Lower the nix-daemon's scheduling and IO priority so builds don't make
  # foreground apps (editor, browser) feel laggy.
  nix.daemonProcessType = "Background";
  nix.daemonIOLowPriority = true;

  # Global shell aliases.
  environment.shellAliases = {
    show-system = "nix derivation show /run/current-system";
    switch-system = "nh darwin switch .";
    list-generations = "nix-env --list-generations";
  };

  # Homebrew baseline. Requires brew to already be installed (nix-darwin
  # doesn't install it — bootstrap with the install.sh from brew.sh once
  # per machine). Casks/brews/taps are declared in the dedicated
  # nix-darwin/homebrew module. `cleanup = "none"` leaves manually
  # installed brews/casks alone.
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "none";
    };
  };
}
