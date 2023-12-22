{ config, pkgs, ... }: {
  # Boot sequence settings.
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    loader.efi.efiSysMountPoint = "/boot/efi";
  };

  # Configure Nix program itself.
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    substituters = [
      "https://cuda-maintainers.cachix.org"
      "https://nixpkgs-unfree.cachix.org"
      "https://numtide.cachix.org"
    ];
    trusted-public-keys = [
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs="
      "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
    ];
  };

  # Enable automatic garbage collection.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Enable networking.
  networking.networkmanager.enable = true;

  # Select locale, time zone and default keyboard layout.
  console.keyMap = "sv-latin1";
  time.timeZone = "Europe/Stockholm";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "sv_SE.UTF-8";
    LC_IDENTIFICATION = "sv_SE.UTF-8";
    LC_MEASUREMENT = "sv_SE.UTF-8";
    LC_MONETARY = "sv_SE.UTF-8";
    LC_NAME = "sv_SE.UTF-8";
    LC_NUMERIC = "sv_SE.UTF-8";
    LC_PAPER = "sv_SE.UTF-8";
    LC_TELEPHONE = "sv_SE.UTF-8";
    LC_TIME = "sv_SE.UTF-8";
  };

  # Enable real-time audio for PipeWire.
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;

  # Enable OpenGL.
  hardware.opengl.enable = true;

  #hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.beta;
  #hardware.nvidia.modesetting.enable = true;

  # Set default shell for all users.
  users.defaultUserShell = pkgs.fish;

  # Set a basic default environment for all users.
  environment = {
    systemPackages = with pkgs; [
      vim
      gnomeExtensions.appindicator
    ];
    shells = [ pkgs.fish ];
    variables = {
      EDITOR = "vim";
      # TODO https://github.com/NixOS/nixpkgs/issues/32580
      WEBKIT_DISABLE_COMPOSITING_MODE = "1";
    };
  };

  # Add programs available for all users.
  programs = {
    command-not-found.enable = true;
    fish.enable = true;
    steam.enable = true;

    # TODO: testing
    nix-ld = {
      enable = true;
      libraries = with pkgs; [
        stdenv.cc.cc
        zlib
        fuse3
        icu
        zlib
        nss
        openssl
        curl
        expat
      ];
    };
  };

  # TODO: Where should this go?
  # To run ark-client we need cargo in the steam fhs environment.
  nixpkgs.config.packageOverrides = pkgs: {
    steam = pkgs.steam.override {
      extraPkgs = pkgs: with pkgs; [
        cargo
      ];
    };
  };

  # Enable system-wide services.
  services = {
    xserver = {
      enable = true;
      videoDrivers = [ "nvidia" ];
      displayManager.gdm.enable = true;
      desktopManager.gnome.enable = true;
      layout = "se";
    };
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = false;
    };
    flatpak.enable = true;
    openssh.enable = false;
    plex.enable = false;
    printing.enable = false;
    udev.packages = [ pkgs.gnome.gnome-settings-daemon ];
  };

  services.tailscale.enable = true;
  #networking.nameservers = [ "100.100.100.100" "8.8.8.8" "1.1.1.1" ];
  #networking.search = [ "example.ts.net" ];

  # Enable Docker container runtime.
  virtualisation.docker = {
    enable = true;
    enableNvidia = true;
  };

  # Enable virtualbox.
  virtualisation.virtualbox.host.enable = true;
  users.extraGroups.vboxusers.members = [ "john" ];

  # Auto-update system packages periodically.
  system.autoUpgrade = {
    enable = true;
    flake = "nixpkgs";
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.11"; # Did you read the comment?
}
