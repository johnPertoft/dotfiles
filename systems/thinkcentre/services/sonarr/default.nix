{ ... }:

{
  services.sonarr = {
    enable = true;
    # Run under the shared `media` group so Sonarr can read from
    # /srv/downloads/complete and hardlink into /srv/media/shows.
    # Both dirs are on the same filesystem, so imports are instant.
    group = "media";
  };

  # Web UI reachable over Tailscale only — this is an admin interface.
  # Household members will use Jellyseerr (not yet deployed) to request
  # content; they never need to touch Sonarr directly.
  # Port 8989 is not opened in the LAN firewall.
}
