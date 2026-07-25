{ ... }:

{
  # Home Assistant runs as a pinned upstream container (its image tracks HA's
  # fast release cadence better than the NixOS module). It manages its own
  # config under /var/lib/home-assistant and persists it there — set it up via
  # the web UI at http://thinkcentre.local:8123.
  #
  # If you later attach USB Zigbee/Z-Wave/Bluetooth radios to this box, pass
  # them through by adding e.g.
  #   devices = [ "/dev/ttyUSB0:/dev/ttyUSB0" ];
  # (or the stable /dev/serial/by-id path) and matching udev access.
  #
  # To layer in *declarative* config, drop files in this dir and mount them,
  # e.g. a themes folder:  "${./themes}:/config/themes:ro"
  virtualisation.podman.enable = true;
  virtualisation.oci-containers = {
    backend = "podman";
    containers.home-assistant = {
      image = "ghcr.io/home-assistant/home-assistant:stable";
      volumes = [
        "/var/lib/home-assistant:/config"
        "/etc/localtime:/etc/localtime:ro"
        "/run/dbus:/run/dbus:ro" # Bluetooth / device discovery
      ];
      extraOptions = [
        "--network=host" # HA listens on 0.0.0.0:8123; also needed for discovery
        "--privileged"
      ];
    };
  };

  # Ensure the persistent config directory exists before the container starts.
  systemd.tmpfiles.rules = [
    "d /var/lib/home-assistant 0750 root root -"
  ];

  networking.firewall.allowedTCPPorts = [ 8123 ];
}
