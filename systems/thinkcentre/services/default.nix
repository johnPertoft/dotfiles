# Aggregates the ThinkCentre's service modules into one import, mirroring the
# Pi's layout. Each service owns its own file plus the firewall ports / mounts /
# supporting config that belong to it.
#
# Compared to the Pi this box does NOT run the monitoring *hub*
# (Prometheus/Loki/Grafana stays on the Pi) — instead ./monitoring is a
# client that exposes node metrics and ships its journal to the Pi's hub.
{
  imports = [
    ./tailscale
    ./blocky
    ./jellyfin
    ./transmission
    ./mealie
    ./home-assistant
    ./monitoring
    ./www
  ];
}
