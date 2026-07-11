{ config, ... }:

{
  # Keep Prometheus' TSDB in RAM to spare the SD card from constant writes.
  fileSystems."/var/lib/prometheus2/data" = {
    fsType = "tmpfs";
    options = [ "size=1G" ];
  };

  # Metrics database. Scrapes the node exporter, Blocky, and smartctl. Bound to
  # localhost; reach it through Grafana.
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
      {
        job_name = "smartctl";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.smartctl.port}" ];
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
    # SMART health for the root disk (the Samsung T7 USB SSD is the box's single
    # point of failure). Autodiscovers disks. Bound to localhost; scraped above.
    # NOTE: SMART over the USB bridge may need an explicit device type — if the
    # exporter reports no attributes after deploy, add e.g.
    #   devices = [ "/dev/sda -d sat" ];
    exporters.smartctl = {
      enable = true;
      listenAddress = "127.0.0.1";
    };
  };
}
