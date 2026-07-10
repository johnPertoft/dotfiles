{ pkgs, ... }:

{
  # Headless BitTorrent daemon with a web UI on :9091. Managed by systemd and
  # configured declaratively here — no ad-hoc SSH sessions.
  services.transmission = {
    enable = true;
    # transmission_3's default was removed in 24.11; pick v4 explicitly. The
    # release note's data-loss caveat is about the 3->4 migration and doesn't
    # apply to this fresh install.
    package = pkgs.transmission_4;

    # Run under the shared `media` group so finished downloads are readable by
    # Jellyfin (already a member) and by pi. The module's activation script
    # owns the download dirs; downloadDirPermissions sets their mode.
    group = "media";
    downloadDirPermissions = "775";

    # Web UI / RPC stays Tailscale-only: openRPCPort = false keeps 9091 out of
    # the LAN firewall, and tailscale0 is a trusted interface, so only tailnet
    # clients reach it. (No auth set — network reachability is the control; add
    # a credentialsFile later if you want RPC user/pass as defense-in-depth.)
    openRPCPort = false;
    settings = {
      # Staging under /srv — the SAME filesystem as /srv/media — so the *arr
      # stack can later hardlink/rename into the library instantly (no copy),
      # and it sidesteps the daemon home's 750 lockout for reads.
      incomplete-dir = "/srv/downloads/incomplete";
      incomplete-dir-enabled = true;
      download-dir = "/srv/downloads/complete";

      rpc-bind-address = "0.0.0.0";
      rpc-whitelist-enabled = false;
      rpc-host-whitelist-enabled = false;
    };
  };

  # No firewall ports opened: the peer port (51413) is useless without a router
  # port-forward (there is none), and the web UI is reached over Tailscale.
}
