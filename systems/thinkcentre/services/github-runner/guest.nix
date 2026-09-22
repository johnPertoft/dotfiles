{ config, lib, pkgs, modulesPath, hostNixSettings, ... }:

{
  imports = [ (modulesPath + "/virtualisation/qemu-vm.nix") ];

  networking = {
    hostName = "thinkcentre-nix-runner";
    useDHCP = false;
    enableIPv6 = false;
    interfaces.eth0.ipv4.addresses = [{
      address = "10.0.2.15";
      prefixLength = 24;
    }];
    defaultGateway = "10.0.2.2";
    nameservers = [ "1.1.1.1" "9.9.9.9" ];
    firewall.enable = true;
  };

  virtualisation = {
    cores = 2;
    memorySize = 4 * 1024;
    diskSize = 100 * 1024;
    diskImage = "/var/lib/github-runner-vm/runner.qcow2";
    graphics = false;
    qemu.forceAccel = true;
    qemu.options = [
      "-monitor unix:/run/github-runner-vm/monitor,server=on,wait=off"
    ];

    # Only the guest's boot closure is copied; no host store or daemon access.
    useNixStoreImage = true;
    mountHostNixStore = false;
    writableStore = false;
    fileSystems = lib.mkForce {
      "/" = {
        device = config.virtualisation.rootDevice;
        fsType = "ext4";
      };
      "/nix/.ro-store" = {
        device = "/dev/disk/by-label/nix-store";
        fsType = "erofs";
        neededForBoot = true;
        options = [ "ro" ];
      };
    };
    sharedDirectories = lib.mkForce { };
    forwardPorts = [ ];

    credentials.github-token = {
      mechanism = "fw_cfg";
      source = "/run/credentials/github-runner-vm.service/github-token";
    };
  };

  boot.initrd.systemd.enable = true;
  boot.initrd.kernelModules = [ "qemu_fw_cfg" ];
  # Seed a real persistent store instead of an overlay whose lower layer would
  # disappear on upgrades, breaking cached closures referencing the old image.
  boot.initrd.systemd.services.seed-nix-store = {
    description = "Copy missing boot closure paths into the persistent Nix store";
    requiredBy = [ "initrd.target" "initrd-find-nixos-closure.service" ];
    before = [ "initrd.target" "initrd-find-nixos-closure.service" ];
    after = [ "initrd-fs.target" ];
    unitConfig = {
      DefaultDependencies = false;
      RequiresMountsFor = [ "/sysroot/nix/.ro-store" "/sysroot/nix/store" ];
    };
    serviceConfig.Type = "oneshot";
    path = [ pkgs.coreutils ];
    script = ''
      set -euo pipefail
      mkdir -p /sysroot/nix/store
      # An interrupted copy must never appear as a complete store path.
      rm -rf /sysroot/nix/.boot-store-staging
      for source in /sysroot/nix/.ro-store/*; do
        target="/sysroot/nix/store/$(basename "$source")"
        if [[ ! -e "$target" && ! -L "$target" ]]; then
          cp -a "$source" /sysroot/nix/.boot-store-staging
          mv /sysroot/nix/.boot-store-staging "$target"
        fi
      done
    '';
  };
  boot.tmp.useTmpfs = false;
  # This guest intentionally has no interactive login or deployment access.
  users.mutableUsers = false;
  users.allowNoPasswordLogin = true;
  users.users.root.hashedPassword = "!";
  services.getty.autologinUser = lib.mkForce null;
  services.openssh.enable = false;
  documentation.enable = false;
  system.stateVersion = "26.05";

  nix.settings = {
    inherit (hostNixSettings) substituters trusted-public-keys;
    experimental-features = [ "nix-command" "flakes" ];
    sandbox = true;
    trusted-users = [ "root" ];
    max-jobs = 1;
    cores = 2;
    auto-optimise-store = true;
    min-free = 5 * 1024 * 1024 * 1024;
    max-free = 10 * 1024 * 1024 * 1024;
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Keep the registration PAT root-only, outside the job's credentials directory.
  systemd.services.github-runner-token = {
    description = "Provision GitHub runner registration credential";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ImportCredential = [ "github-token" ];
      RuntimeDirectory = "github-runner-token";
      RuntimeDirectoryMode = "0700";
    };
    script = ''
      install -m 0600 "$CREDENTIALS_DIRECTORY/github-token" /run/github-runner-token/token
    '';
  };

  services.github-runners.dotfiles = {
    enable = true;
    url = "https://github.com/johnPertoft/dotfiles";
    name = "thinkcentre-nix-1";
    extraLabels = [ "nix" "homelab" ];
    tokenFile = "/run/github-runner-token/token";
    tokenType = "access";
    replace = true;
    ephemeral = false;
    nodeRuntimes = [ "node24" ];
    workDir = "/var/lib/github-runner-work";
    extraPackages = with pkgs; [ curl jq ];
    serviceOverrides = {
      StateDirectory = [ "github-runner-work" ];
      Restart = lib.mkForce "on-failure";
      RestartSec = "30s";
    };
  };
  systemd.services.github-runner-dotfiles = {
    requires = [ "github-runner-token.service" ];
    after = [ "github-runner-token.service" ];
  };

  # Boot and runner diagnostics are available in the host VM service's journal.
  services.journald.extraConfig = ''
    ForwardToConsole=yes
    MaxLevelConsole=info
    SystemMaxUse=256M
  '';
}
