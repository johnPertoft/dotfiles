{ nixpkgs, self, hermes-agent, ... }:

nixpkgs.lib.nixosSystem {
  system = "aarch64-linux";
  modules = [
    ./configuration.nix
    ./hardware-configuration.nix
    # Upstream Hermes Agent NixOS module (defines services.hermes-agent.*).
    # Imported here rather than in ./services because that's where the flake
    # `inputs` are in scope; the actual, scoped-down config lives in
    # ./services/hermes.
    hermes-agent.nixosModules.default
    # Service stack (Blocky, monitoring, Tailscale, Home Assistant). Built
    # natively on the Pi via `nixos-rebuild switch`; kept out of the very first
    # SD image so the bootstrap stayed minimal (just boot + SSH).
    ./services
    "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
    { nixpkgs.overlays = [ self.overlays.modules-closure ]; }
    { sdImage.compressImage = false; }
    self.modules.default
    self.nixosModules.default
    self.nixosModules.server
    {
      # Allow testing the config in a QEMU VM (e.g. from macOS), since the Pi
      # itself isn't always reachable. Cross-builds the aarch64 guest.
      virtualisation.vmVariant = {
        virtualisation.host.pkgs = nixpkgs.legacyPackages.x86_64-linux;
        virtualisation.memorySize = 2 * 1024; # 2 GB
        virtualisation.diskSize = 16 * 1024; # 16 GB
        boot.kernelPackages = nixpkgs.lib.mkForce nixpkgs.legacyPackages.aarch64-linux.linuxPackages;
      };
    }
  ];
}
