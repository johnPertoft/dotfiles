{ config
, pkgs
, lib
, ...
}:

{
  # Lenovo ThinkCentre — headless x86_64 homelab server: media (HW-transcoded
  # Jellyfin), downloads, recipes, home automation, and DNS adblocking, with
  # room for the future *arr stack. Key-only SSH, declarative users, rebuilt
  # with `nixos-rebuild switch`.
  #
  # A normal UEFI x86_64 install (systemd-boot, wired Ethernet via DHCP) — see
  # hardware-configuration.nix for the disk/boot layout once the machine exists.

  hardware.enableRedistributableFirmware = true;

  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    tmp.cleanOnBoot = true;
  };

  networking = {
    hostName = "thinkcentre";

    # Wired-only, static — the Pi's pattern (systems/pi/configuration.nix:55-75)
    # minus the wireless half. Static rather than DHCP because this box serves
    # LAN DNS: Blocky's address is what the router and clients point at, so it
    # can't be allowed to move with a lease.
    #
    # `eno2` is the onboard NIC (verified on the box with `ip -br link` — note
    # it is eno2, not eno1). The WiFi card (wlo1) is deliberately left
    # unconfigured: nothing here enables NetworkManager or wpa_supplicant, so
    # there is NO wireless fallback. If the Ethernet run dies, recovery is at
    # the console. During bring-up the box ran on the installer's
    # NetworkManager WiFi profile; this replaces it.
    #
    # .3 for now. It moves to .2 at DNS cutover, once the Pi's Blocky is retired
    # and the router/clients are re-pointed here — see README.
    interfaces."eno2".ipv4.addresses = [
      {
        address = "192.168.0.3";
        prefixLength = 24;
      }
    ];

    defaultGateway = {
      address = "192.168.0.1";
      interface = "eno2";
    };

    # Every interface is either statically addressed or deliberately unused, so
    # there is nothing for dhcpcd to do — without this it would also keep
    # retrying on the unconfigured WiFi card.
    useDHCP = false;

    # With a static address there's no DHCP to hand us a resolver, so set one
    # explicitly or /etc/resolv.conf ends up empty and name resolution breaks
    # (routing still works, so you can ping 8.8.8.8 but not resolve hosts).
    # Public resolvers keep DNS decoupled from Blocky during bring-up; once
    # Blocky is confirmed healthy you can prepend "127.0.0.1" to route this
    # box's own lookups through the adblocker too.
    nameservers = [ "1.1.1.1" "1.0.0.1" ];

    # SSH (22) is opened by the openssh module; service ports live in each
    # service's own module under ./services.
    firewall.allowedUDPPorts = [
      5353 # mDNS (avahi), so `thinkcentre.local` resolves
    ];
  };

  # Intel CPU microcode updates (paired with enableRedistributableFirmware).
  hardware.cpu.intel.updateMicrocode = true;

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
    john = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      # `users.mutableUsers = false` (modules/nixos/server.nix) wipes any
      # imperative password on activation, so without a password option there
      # is no console login at all and the SSH key below is the only way in.
      #
      # The hash lives on the box, NOT in this (public) repo — a $6$ hash is
      # offline-crackable once published, and git history is forever. Seed it
      # with, as root:
      #   mkdir -p /etc/nixos-secrets
      #   mkpasswd -m sha-512 > /etc/nixos-secrets/john.pw
      #   chmod 0600 /etc/nixos-secrets/john.pw
      # The file is re-read on EVERY activation, so it must exist before the
      # next `nixos-rebuild switch` or john ends up with no password at all.
      hashedPasswordFile = "/etc/nixos-secrets/john.pw";
      openssh.authorizedKeys.keyFiles = [
        # TODO: this is the *work* key (john.pertoft@king.com) and is the SOLE
        # way onto the box (key-only SSH). Swap it for a personal keypair —
        # additively, to avoid lockout: add the new key, rebuild, verify it logs
        # in, then remove this one.
        ./john.pertoft.pub
      ];
    };
  };

  # Passwordless sudo for wheel. The accounts are key-only (no password, no
  # console login), so the SSH private key is already the root credential —
  # passwordless sudo doesn't meaningfully widen access. (Could switch to
  # pam_ssh_agent_auth on x86_64 later if wanted.)
  security.sudo.wheelNeedsPassword = false;

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
    };
  };

  # This value determines the NixOS release from which the default settings for
  # stateful data were taken. Leave it at the release of the first install.
  system.stateVersion = "26.05";
}
