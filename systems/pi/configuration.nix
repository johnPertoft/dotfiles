{ config
, pkgs
, lib
, ...
}:

{
  hardware.enableRedistributableFirmware = true;

  boot = {
    # The Pi has no ZFS pool; disabling it silences the forceImportRoot warning
    # and trims the SD image.
    supportedFilesystems.zfs = lib.mkForce false;
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

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
    options = [ "noatime" ];
  };

  networking = {
    hostName = "pi";

    wireless = {
      enable = true;
      interfaces = [ "wlan0" ];
      # Also honor an imperative /etc/wpa_supplicant.conf (seeded onto the card
      # by install.sh) so a headless Pi can join WiFi on first boot without a
      # password in the repo.
      allowAuxiliaryImperativeNetworks = true;
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

    # SSH (port 22) is opened by the openssh module. Service-specific ports
    # (DNS, Grafana, ...) live in services.nix.
    firewall.allowedUDPPorts = [
      5353 # mDNS (avahi), so `pi.local` resolves
    ];
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
      openssh.authorizedKeys.keyFiles = [
        ./john.pertoft.pub
      ];
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
