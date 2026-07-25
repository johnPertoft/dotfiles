{ config, ... }:

{
  # Monitoring CLIENT (not a hub). The Prometheus/Loki/Grafana hub lives on
  # another host (currently `pi`); this box just:
  #   1. exposes a node exporter for the hub's Prometheus to scrape, and
  #   2. ships its systemd journal to the hub's Loki via Alloy.
  #
  # ┌─ HUB-SIDE FOLLOW-UP (deferred — not part of this work) ───────────────────┐
  # │ Neither leg works until the hub is wired to accept this box: its Loki +   │
  # │ Prometheus currently bind 127.0.0.1 only, so they need to                 │
  # │   • Loki: bind its HTTP listener on the tailscale interface (or 0.0.0.0   │
  # │     behind the trusted tailscale0 firewall) so remote pushes land, and    │
  # │   • Prometheus: add a scrape target `thinkcentre:9100` (tailnet name).    │
  # │ Until then Alloy just retries harmlessly and the exporter sits idle.      │
  # └──────────────────────────────────────────────────────────────────────────┘

  # Node metrics. Bound to all interfaces but only reachable over the trusted
  # tailscale0 (9100 is not opened on the LAN firewall), so the hub scrapes it
  # over the tailnet.
  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "0.0.0.0";
    enabledCollectors = [ "systemd" ];
  };

  # Grafana Alloy ships the systemd journal into the hub's Loki (promtail's
  # successor). The endpoint uses the hub's Tailscale MagicDNS name so it
  # follows that host if its LAN IP changes. Config kept inline to interpolate
  # this box's host name.
  services.alloy.enable = true;
  environment.etc."alloy/config.alloy".text = ''
    loki.write "default" {
      endpoint {
        // `pi` = the current monitoring hub host (Tailscale MagicDNS).
        url = "http://pi:3100/loki/api/v1/push"
      }
    }

    loki.relabel "journal" {
      forward_to = []
      rule {
        source_labels = ["__journal__systemd_unit"]
        target_label  = "unit"
      }
      // Map the numeric journal priority (0-7) to a keyword label so the
      // Grafana "Services" dashboard can filter by severity. Each rule only
      // replaces on a match (a non-matching "replace" leaves the target as-is),
      // so exactly one keyword wins per log line.
      rule {
        source_labels = ["__journal_priority"]
        target_label  = "priority"
        regex         = "0"
        replacement   = "emerg"
      }
      rule {
        source_labels = ["__journal_priority"]
        target_label  = "priority"
        regex         = "1"
        replacement   = "alert"
      }
      rule {
        source_labels = ["__journal_priority"]
        target_label  = "priority"
        regex         = "2"
        replacement   = "crit"
      }
      rule {
        source_labels = ["__journal_priority"]
        target_label  = "priority"
        regex         = "3"
        replacement   = "err"
      }
      rule {
        source_labels = ["__journal_priority"]
        target_label  = "priority"
        regex         = "4"
        replacement   = "warning"
      }
      rule {
        source_labels = ["__journal_priority"]
        target_label  = "priority"
        regex         = "5"
        replacement   = "notice"
      }
      rule {
        source_labels = ["__journal_priority"]
        target_label  = "priority"
        regex         = "6"
        replacement   = "info"
      }
      rule {
        source_labels = ["__journal_priority"]
        target_label  = "priority"
        regex         = "7"
        replacement   = "debug"
      }
    }

    loki.source.journal "journal" {
      forward_to    = [loki.write.default.receiver]
      relabel_rules = loki.relabel.journal.rules
      max_age       = "12h"
      labels        = {
        job  = "systemd-journal",
        host = "${config.networking.hostName}",
      }
    }
  '';
}
