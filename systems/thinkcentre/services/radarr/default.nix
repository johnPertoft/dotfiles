{ ... }:

{
  services.radarr = {
    enable = true;
    # Same media group rationale as Sonarr: reads /srv/downloads/complete,
    # hardlinks into /srv/media/movies.
    group = "media";
  };

  # Web UI reachable over Tailscale only — admin interface.
  # Port 7878 is not opened in the LAN firewall.
}
