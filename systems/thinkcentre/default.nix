{ nixpkgs, self, ... }:

nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    ./configuration.nix
    ./hardware-configuration.nix
    # Service stack (Tailscale, Blocky, Jellyfin, Transmission, Mealie, Home
    # Assistant, the monitoring client, and the www landing page): one module
    # per service, aggregated by ./services.
    ./services
    self.modules.default
    self.nixosModules.default
    self.nixosModules.server
    {
      # Smoke-test the service stack in a QEMU VM, e.g.
      #   nixos-rebuild build-vm --flake .#thinkcentre && ./result/bin/run-*-vm
      # The vmVariant supplies its own disk/boot and networking, so the real
      # host's fileSystems and static IP don't apply here.
      virtualisation.vmVariant = {
        virtualisation.memorySize = 4 * 1024; # 4 GB
        virtualisation.diskSize = 16 * 1024; # 16 GB
      };
    }
  ];
}
