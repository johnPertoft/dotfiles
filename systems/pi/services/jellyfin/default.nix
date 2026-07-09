{ ... }:

{
  # Media server. Runs as the `jellyfin` user; library data lives in
  # /var/lib/jellyfin and the transcode/cache in /var/cache/jellyfin.
  #
  # Unlike the reference config, the cache is left on disk rather than a tmpfs:
  # that tmpfs existed to spare an SD card from write churn, but this Pi boots
  # from a 1 TB SSD (writes are cheap) and only has 4 GB RAM shared with the
  # other services — a multi-GB transcode cache in RAM would risk OOM.
  services.jellyfin.enable = true;

  # Where to keep media. Add this as a library in the web UI
  # (Dashboard -> Libraries). World-readable so the jellyfin user can read
  # whatever gets dropped here.
  systemd.tmpfiles.rules = [
    "d /srv/media 0755 root root -"
  ];

  # Web UI, reachable on the LAN and (trusted) over Tailscale. Client
  # auto-discovery ports (UDP 1900/7359) are intentionally left closed — reach
  # it by URL / Tailscale instead.
  networking.firewall.allowedTCPPorts = [ 8096 ];
}
