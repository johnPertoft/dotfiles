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
