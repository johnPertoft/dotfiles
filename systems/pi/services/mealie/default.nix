{ ... }:

{
  # Mealie — self-hosted recipe manager & meal planner, on http://pi.local:9000
  # (LAN) and http://pi:9000 (tailnet). Runs as a native systemd service via the
  # NixOS module: the package is cached for aarch64, so there's no from-source
  # build on the Pi (unlike the container-only services). State (SQLite DB,
  # uploaded recipe images, backups) lives in the module's StateDirectory,
  # /var/lib/mealie, on the T7 SSD — so it survives reboots. SQLite is the
  # default backend; fine for a single household and avoids running a Postgres
  # process on the 4 GB box (flip database.createLocally if that ever changes).
  services.mealie = {
    enable = true;
    port = 9000;

    # settings become the container/app's environment variables.
    settings = {
      # Timezone drives the meal-plan calendar and recipe timestamps. The Pi
      # otherwise has no time.timeZone set (defaults to UTC).
      TZ = "Europe/Stockholm";

      # No open self-registration: the app is on the LAN, so keep account
      # creation admin-only. On first login use the default admin account
      # (changeme@example.com / MyPassword) and immediately change both.
      ALLOW_SIGNUP = "false";

      # Only affects generated share links / invite URLs, not where the app
      # binds. Pointed at the LAN name; tailnet access still works, its share
      # links just won't be clickable off-LAN (cosmetic).
      BASE_URL = "http://pi.local:9000";
    };
  };

  # LAN-exposed like Grafana/Jellyfin so recipes are reachable from a phone in
  # the kitchen without Tailscale. tailscale0 is already a trusted interface,
  # so this also covers tailnet access. Not internet-exposed (no router
  # port-forward to the Pi).
  networking.firewall.allowedTCPPorts = [ 9000 ];
}
