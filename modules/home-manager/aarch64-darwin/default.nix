{ config
, pkgs
, lib
, ...
}:
{
  nixpkgs.config = {
    allowUnfreePredicate =
      pkg:
      builtins.elem (lib.getName pkg) [
        "claude-code"
        "terraform"
        "vscode"
      ];
  };

  home.packages = with pkgs; [
    colima
    net-news-wire
    stats
    iterm2
  ];

  # Use the Apple-patched system ssh so options like UseKeychain in
  # ~/.ssh/config don't trip up nix's upstream OpenSSH.
  programs.git.settings.core.sshCommand = "/usr/bin/ssh";

  # Create wrapper apps so Spotlight (cmd+space) can find Nix-installed GUI apps.
  services.macos-spotlight-apps.enable = true;
}
