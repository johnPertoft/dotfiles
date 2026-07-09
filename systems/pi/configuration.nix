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
    # Stock aarch64 kernel (in the binary cache, so no from-source build). The
    # Pi has already booted it from the T7, so it's proven on this hardware.
    # Re-enable the vendor kernel only if some peripheral needs it:
    # kernelPackages = pkgs.linuxKernel.packages.linux_rpi4;
    initrd.availableKernelModules = [
      "xhci_pci"
      "usbhid"
      "usb_storage"
      "uas" # the Samsung T7 speaks USB Attached SCSI
      "pcie-brcmstb" # Pi4 PCIe bus — the USB3 controller hangs off it
      "reset-raspberrypi" # loads the VL805 USB3 controller firmware
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
      # Honor an imperative config at /etc/wpa_supplicant/imperative.conf (seed
      # it with `wpa_passphrase`) so the Pi joins WiFi without a password in the
      # repo.
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

    # With a static address there's no DHCP to hand us a resolver, so set one
    # explicitly or /etc/resolv.conf ends up empty and name resolution breaks
    # (routing still works, so you can ping 8.8.8.8 but not resolve hosts).
    # Public resolvers keep DNS decoupled from Blocky during bring-up; once
    # Blocky is confirmed running you can prepend "127.0.0.1" to route the Pi's
    # own lookups through the adblocker too.
    nameservers = [ "1.1.1.1" "1.0.0.1" ];

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

  # Passwordless sudo for wheel. Intended as SSH-agent auth (pam_ssh_agent_auth),
  # but that module is broken on this aarch64 build (dlopen fails with
  # "undefined symbol: __multf3"), and the accounts are key-only with no
  # password to fall back on. Since key-only SSH (no password/console login) is
  # already the sole path onto the box, the private key is effectively the root
  # credential, so passwordless sudo doesn't meaningfully widen access.
  security.sudo.wheelNeedsPassword = false;

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
