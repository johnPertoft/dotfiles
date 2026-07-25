{ ... }:

{
  # Mealie — self-hosted recipe manager & meal planner, on
  # http://thinkcentre.local:9000 (LAN) and http://thinkcentre:9000 (tailnet).
  # Runs as a native systemd service via the NixOS module. State (SQLite DB,
  # uploaded recipe images, backups) lives in the module's StateDirectory,
  # /var/lib/mealie. SQLite is the default backend and fine for a single
  # household (flip database.createLocally to move to a local Postgres).
  services.mealie = {
    enable = true;
    port = 9000;

    # settings become the app's environment variables.
    settings = {
      TZ = "Europe/Stockholm";

      # No open self-registration: the app is on the LAN, so keep account
      # creation admin-only. On first login use the default admin account
      # (changeme@example.com / MyPassword) and immediately change both.
      ALLOW_SIGNUP = "false";

      # Only affects generated share links / invite URLs, not where the app
      # binds. Pointed at the LAN name; tailnet access still works.
      BASE_URL = "http://thinkcentre.local:9000";
    };
  };

  # LAN-exposed like Jellyfin so recipes are reachable from a phone in the
  # kitchen without Tailscale. tailscale0 is already a trusted interface, so
  # this also covers tailnet access.
  networking.firewall.allowedTCPPorts = [ 9000 ];
}
