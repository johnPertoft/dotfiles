# Aggregates the ThinkCentre's service modules into one import. Each service
# owns its own file plus the firewall ports / mounts / supporting config that
# belong to it.
#
# Note: this box does NOT run the monitoring *hub* (Prometheus/Loki/Grafana) —
# ./monitoring is a client that exposes node metrics and ships its journal to
# the monitoring host.
{
  imports = [
    ./tailscale
    ./blocky
    ./jellyfin
    ./transmission
    ./sonarr
    ./radarr
    ./mealie
    ./home-assistant
    ./monitoring
    ./www
  ];
}
