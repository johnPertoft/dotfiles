{ nixpkgs, ... }:
{
  # Configure the `nix` program itself.
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    substituters = [
      "https://nix-community.cachix.org"
      # llm-agents.nix's prebuilt binaries (codex, claude-code, gemini-cli, …).
      # Replaces the old numtide.cachix.org cache, which it migrated away from.
      "https://cache.numtide.com"
      "https://devenv.cachix.org"
    ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
    ];
    cores = 0;
    max-jobs = "auto";
  };

  # Link old commands (nix-shell, nix-build, etc.) to use the same nixpkgs as the flake.
  nix.nixPath = [ "nixpkgs=${nixpkgs}" ];

  # Enable automatic garbage collection.
  nix.gc = {
    automatic = true;
    options = "--delete-older-than 30d";
  };
}
