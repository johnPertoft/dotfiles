{ config, lib, pkgs, ... }:

let
  tokenFile = "/etc/nixos-secrets/github-runner.token";
  guest = import "${pkgs.path}/nixos/lib/eval-config.nix" {
    system = "x86_64-linux";
    specialArgs.hostNixSettings = config.nix.settings;
    modules = [ ./guest.nix ];
  };
  vm = guest.config.system.build.vm;
in
{
  system.build.github-runner-vm = vm;

  systemd.services.github-runner-vm = {
    description = "Isolated GitHub Actions runner VM";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    unitConfig.ConditionPathExists = tokenFile;

    environment = {
      TMPDIR = "/var/cache/github-runner-vm";
      USE_TMPDIR = "1";
      QEMU_NET_OPTS = "ipv6=off";
    };

    serviceConfig = {
      ExecStart = lib.getExe vm;
      ExecStop = pkgs.writeShellScript "stop-github-runner-vm" ''
        set -euo pipefail
        printf 'system_powerdown\n' |
          ${pkgs.socat}/bin/socat -T 1 - UNIX-CONNECT:/run/github-runner-vm/monitor
        while kill -0 "$MAINPID" 2>/dev/null; do
          sleep 1
        done
      '';
      Restart = "on-failure";
      RestartSec = "30s";
      TimeoutStopSec = "2min";

      DynamicUser = true;
      SupplementaryGroups = [ "kvm" ];
      StateDirectory = "github-runner-vm";
      StateDirectoryMode = "0700";
      CacheDirectory = "github-runner-vm";
      CacheDirectoryMode = "0700";
      RuntimeDirectory = "github-runner-vm";
      RuntimeDirectoryMode = "0700";
      WorkingDirectory = "/var/lib/github-runner-vm";
      LoadCredential = "github-token:${tokenFile}";
      UMask = "0077";

      CPUQuota = "200%";
      MemoryMax = "5G";
      Nice = 10;
      IOWeight = 25;

      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" ];
      DevicePolicy = "closed";
      DeviceAllow = [ "/dev/kvm rw" ];

      # Filter QEMU's outbound sockets, not guest-controlled firewall rules.
      # Public DNS in the guest avoids forwarding DNS to the host/LAN.
      IPAddressDeny = [
        "localhost"
        "link-local"
        "multicast"
        "0.0.0.0/8"
        "10.0.0.0/8"
        "172.16.0.0/12"
        "192.168.0.0/16"
        "100.64.0.0/10"
        "fc00::/7"
      ];
    };
  };

  # The homelab smoke-test VM must not start a second registered runner.
  virtualisation.vmVariant.systemd.services.github-runner-vm.enable = false;
}
