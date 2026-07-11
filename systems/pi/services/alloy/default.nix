{ config, ... }:

{
  # Grafana Alloy ships the systemd journal into Loki (promtail's successor).
  # The config is kept inline (rather than a separate .alloy file) so it can
  # interpolate the host name; extract it to a file if it grows.
  services.alloy.enable = true;
  environment.etc."alloy/config.alloy".text = ''
    loki.write "default" {
      endpoint {
        url = "http://127.0.0.1:3100/loki/api/v1/push"
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
