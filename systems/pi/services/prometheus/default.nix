{ config, ... }:

{
  # Keep Prometheus' TSDB in RAM to spare the SD card from constant writes.
  fileSystems."/var/lib/prometheus2/data" = {
    fsType = "tmpfs";
    options = [ "size=1G" ];
  };

  # Metrics database. Scrapes the node exporter and Blocky. Bound to localhost;
  # reach it through Grafana.
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
}
