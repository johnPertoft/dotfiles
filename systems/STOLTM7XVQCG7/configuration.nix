{ ... }:
{
  networking.hostName = "STOLTM7XVQCG7";

  system.primaryUser = "john.pertoft";

  # Tailscale client — reach the homelab (the Pi's Tailscale-only services)
  # over the tailnet. This is the tailscaled daemon (CLI, not the menu-bar
  # app); run `sudo tailscale up` once to authenticate.
  services.tailscale.enable = true;

  # Required. Increment when nix-darwin release notes say so.
  system.stateVersion = 6;
}
