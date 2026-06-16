{ ... }:
{
  # Brew-managed apps — proprietary macOS GUIs that aren't packaged in
  # nixpkgs. Requires the base homebrew block in
  # modules/nix-darwin/configuration.nix to enable Homebrew itself.
  homebrew.casks = [
    # OpenAI's Codex desktop app — ships as a .dmg, not in nixpkgs.
    "codex-app"
  ];
}
