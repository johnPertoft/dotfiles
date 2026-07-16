{ ... }:

{
  # Media server. Runs as the `jellyfin` user; library data lives in
  # /var/lib/jellyfin and the transcode/cache in /var/cache/jellyfin.
  #
  # The cache is left on disk rather than a tmpfs, this Pi boots from a 1 TB SSD
  # and only has 4 GB RAM shared with the other services, so a multi-GB transcode
  # cache in RAM would risk OOM.
  services.jellyfin.enable = true;

  # Declarative media layout. One folder per library type under /srv/media.
  # A `media` group lets `pi` drop files here (e.g. over scp) while the
  # `jellyfin` service user reads them; the setgid bit (2775) makes new files
  # inherit the `media` group so Jellyfin can always read whatever lands here.
  users.groups.media = { };
  users.users.jellyfin.extraGroups = [ "media" ];
  users.users.pi.extraGroups = [ "media" ];
  systemd.tmpfiles.rules = [
    "d /srv/media        2775 pi media -"
    "d /srv/media/movies 2775 pi media -"
    "d /srv/media/shows  2775 pi media -"
    "d /srv/media/music  2775 pi media -"
  ];

  # Web UI, reachable on the LAN and (trusted) over Tailscale. Client
  # auto-discovery ports (UDP 1900/7359) are intentionally left closed.
  networking.firewall.allowedTCPPorts = [ 8096 ];
}
