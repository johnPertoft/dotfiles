# The Pi's service stack: Tailscale, Blocky DNS adblocking, and the
# Grafana/Prometheus/Loki monitoring stack.
#
# This is imported separately from the base config (see default.nix) so the
# *first* image can be built minimal — just enough to boot and SSH in — and
# these heavier services get switched on later, built natively on the Pi
# itself. Comment the import out for the initial build, then re-enable and
# `nixos-rebuild switch` once the Pi is reachable.
{ config
, pkgs
, lib
, ...
}:

{
  # Keep Prometheus' TSDB in RAM to spare the SD card from constant writes.
  fileSystems."/var/lib/prometheus2/data" = {
    fsType = "tmpfs";
    options = [ "size=1G" ];
  };

  networking.firewall = {
    allowedTCPPorts = [
      53 # DNS (Blocky)
      3000 # Grafana
    ];
    allowedUDPPorts = [
      53 # DNS (Blocky)
    ];
    # Everything reachable over Tailscale is trusted (Grafana, SSH, etc.).
    trustedInterfaces = [ "tailscale0" ];
  };

  # Remote access to the Pi (and, if you `tailscale up --advertise-routes`, the
  # rest of the LAN). The module opens its own UDP port; tailscale0 is trusted
  # by the firewall above. Run `sudo tailscale up` once after the first boot.
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
  };

  # Network-wide DNS ad/tracker blocking. Point a device's DNS at 192.168.0.2
  # (or hand it out via Tailscale DNS) to filter ads. Metrics are exported for
  # Prometheus on the HTTP port below.
  services.blocky = {
    enable = true;
    settings = {
      ports.dns = 53;
      ports.http = 4000;
      prometheus.enable = true;
      caching = {
        minTime = "5m";
        maxTime = "30m";
        prefetching = true;
      };
      upstreams.groups.default = [ "https://one.one.one.one/dns-query" ];
      bootstrapDns = {
        upstream = "https://one.one.one.one/dns-query";
        ips = [
          "1.1.1.1"
          "1.0.0.1"
        ];
      };
      blocking = {
        blackLists.ads = [
          "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
          "https://big.oisd.nl/domainswild"
        ];
        clientGroupsBlock.default = [ "ads" ];
      };
    };
  };

  # Metrics database. Scrapes the node exporter and Blocky. Bound to localhost;
  # reach it through Grafana. Its TSDB lives on tmpfs (see fileSystems above).
  services.prometheus = {
    enable = true;
    listenAddress = "127.0.0.1";
    globalConfig = {
      scrape_interval = "15s";
      evaluation_interval = "15s";
    };
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ];
            labels.instance = config.networking.hostName;
          }
        ];
      }
      {
        job_name = "blocky";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString config.services.blocky.settings.ports.http}" ];
            labels.instance = config.networking.hostName;
          }
        ];
      }
    ];
    exporters.node = {
      enable = true;
      listenAddress = "127.0.0.1";
      enabledCollectors = [ "systemd" ];
    };
  };

  # Log aggregation. Single-binary filesystem-backed Loki, fed the systemd
  # journal by Alloy (below). Both bound to localhost and queried via Grafana.
  services.loki = {
    enable = true;
    configuration = {
      auth_enabled = false;
      server = {
        http_listen_address = "127.0.0.1";
        http_listen_port = 3100;
        grpc_listen_port = 9096;
      };
      common = {
        instance_addr = "127.0.0.1";
        path_prefix = "/var/lib/loki";
        storage.filesystem = {
          chunks_directory = "/var/lib/loki/chunks";
          rules_directory = "/var/lib/loki/rules";
        };
        replication_factor = 1;
        ring.kvstore.store = "inmemory";
      };
      schema_config.configs = [
        {
          from = "2024-01-01";
          store = "tsdb";
          object_store = "filesystem";
          schema = "v13";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }
      ];
      analytics.reporting_enabled = false;
    };
  };

  # Grafana Alloy ships the systemd journal into Loki (promtail's successor).
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

  # Dashboards. Bound to all interfaces and exposed on the LAN (firewall port
  # 3000) and over Tailscale. Prometheus + Loki datasources are provisioned.
  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "0.0.0.0";
        http_port = 3000;
        domain = "${config.networking.hostName}.local";
      };
      analytics.reporting_enabled = false;
      # 26.05 dropped the built-in default; read a host-generated key so no
      # secret is committed. Generated by the grafana-secret-key service below.
      security.secret_key = "$__file{/var/lib/grafana/secret_key}";
    };
    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          access = "proxy";
          url = "http://127.0.0.1:${toString config.services.prometheus.port}";
          isDefault = true;
          uid = "prometheus";
        }
        {
          name = "Loki";
          type = "loki";
          access = "proxy";
          url = "http://127.0.0.1:3100";
          uid = "loki";
        }
      ];
    };
  };

  # Generate Grafana's secret_key on first boot if absent, so it stays out of
  # the repo. Runs before grafana.service and persists across rebuilds.
  systemd.services.grafana-secret-key = {
    wantedBy = [ "multi-user.target" ];
    before = [ "grafana.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      key=/var/lib/grafana/secret_key
      if [ ! -f "$key" ]; then
        mkdir -p /var/lib/grafana
        ${pkgs.openssl}/bin/openssl rand -hex 32 > "$key"
        chown grafana:grafana "$key"
        chmod 600 "$key"
      fi
    '';
  };
}
