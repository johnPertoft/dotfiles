{ config, ... }:

{
  # Monitoring CLIENT (not a hub). The Prometheus/Loki/Grafana hub stays on the
  # Pi; this box just:
  #   1. exposes a node exporter for the Pi's Prometheus to scrape, and
  #   2. ships its systemd journal to the Pi's Loki via Alloy.
  #
  # ┌─ PI-SIDE FOLLOW-UP (deferred — do NOT edit the Pi as part of this work) ──┐
  # │ Neither leg works until the Pi is wired to accept this box, because the   │
  # │ Pi's Loki + Prometheus currently bind 127.0.0.1 only:                     │
  # │   • Loki: bind its HTTP listener on the tailscale interface (or 0.0.0.0   │
  # │     behind the trusted tailscale0 firewall) so remote pushes land.        │
  # │   • Prometheus: add a scrape target `thinkcentre:9100` (tailnet name).    │
  # │ Until then Alloy just retries harmlessly and the exporter sits idle.      │
  # └──────────────────────────────────────────────────────────────────────────┘

  # Node metrics. Bound to all interfaces but only reachable over the trusted
  # tailscale0 (9100 is not opened on the LAN firewall), so the Pi scrapes it
  # over the tailnet.
  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "0.0.0.0";
    enabledCollectors = [ "systemd" ];
  };

  # Grafana Alloy ships the systemd journal into the Pi's Loki (promtail's
  # successor). Endpoint is the Pi over Tailscale MagicDNS so it follows the Pi
  # if its LAN IP changes at cutover. Config kept inline to interpolate the host
  # name; identical relabel rules to the Pi's Alloy so both feed the same
  # dashboards.
  services.alloy.enable = true;
  environment.etc."alloy/config.alloy".text = ''
    loki.write "default" {
      endpoint {
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
