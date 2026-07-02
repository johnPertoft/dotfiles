# Aggregates the Pi's service modules into one import. Toggled as a unit from
# ../default.nix so the first SD image can stay minimal (boot + SSH) and the
# whole stack gets switched on later, built natively on the Pi.
#
# Each service owns its own file, plus the firewall ports / mounts / supporting
# config files (e.g. grafana/dashboards) that belong to it.
{
  imports = [
    ./tailscale
    ./blocky
    ./prometheus
    ./loki
    ./alloy
    ./grafana
    ./home-assistant
  ];
}
