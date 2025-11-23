{ config
, pkgs
, lib
, ...
}:

# let
#   grafanaDashboards = lib.mapAttrs' (
#     name: value:
#     lib.nameValuePair ("grafana/dashboards/" + name) {
#       source = ./grafana/dashboards/${name};
#       group = "grafana";
#       user = "grafana";
#     }
#   ) (builtins.readDir ./grafana/dashboards);

#   alertManagerTemplates = lib.mapAttrs' (
#     name: value:
#     lib.nameValuePair ("alertmanager/templates/" + name) {
#       source = ./prometheus/alertmanager/templates/${name};
#       group = "alertmanager";
#       user = "alertmanager";
#     }
#   ) (builtins.readDir ./prometheus/alertmanager/templates);

#   configFiles = {
#     "home-assistant/configuration.yaml" = {
#       source = ./home-assistant/configuration.yaml;
#       group = "home-assistant";
#       user = "home-assistant";
#       mode = "0644";
#     };
#   };
# in
{
  hardware.enableRedistributableFirmware = true;

  boot = {
    kernelPackages = pkgs.linuxKernel.packages.linux_rpi4;
    initrd.availableKernelModules = [
      "xhci_pci"
      "usbhid"
      "usb_storage"
    ];
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
    tmp = {
      cleanOnBoot = true;
      useTmpfs = true;
      tmpfsSize = "2G";
    };
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" ];
    };

    "/var/lib/prometheus2/data" = {
      fsType = "tmpfs";
      options = [ "size=1G" ];
    };

    "/var/cache/jellyfin/transcodes" = {
      fsType = "tmpfs";
      options = [ "size=2G" ];
    };
  };

  # environment.etc = configFiles // grafanaDashboards // alertManagerTemplates;

  networking = {
    hostName = "pi";

    wireless = {
      enable = true;
      interfaces = [ "wlan0" ];
    };

    defaultGateway = {
      address = "192.168.0.1";
      interface = "wlan0";
    };

    interfaces."wlan0" = {
      ipv4.addresses = [
        {
          address = "192.168.0.2";
          prefixLength = 24;
        }
      ];
    };

    firewall = {
      allowedTCPPorts = [
        80 # HTTP
        443 # HTTPS
        53 # DNS
      ];
      allowedUDPPorts = [
        53 # DNS
        67 # DHCP server
        68 # DHCP client
        5353 # mDNS
        2049 # NFS
      ];
    };
  };

  services.fail2ban = {
    enable = true;
    jails = {
      ssh-iptables = ''
        enabled = true
        filter = sshd
        maxretry = 3
        findtime = 600
        bantime = 3600
      '';
    };
  };

  users.users = {
    pi = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
    };
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
    };
  };

  services.journald.storage = "volatile";


  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
