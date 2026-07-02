{ nixpkgs, self, ... }:

nixpkgs.lib.nixosSystem {
  system = "aarch64-linux";
  modules = [
    ./configuration.nix
    ./hardware-configuration.nix
    # Service stack (Blocky, monitoring, Tailscale, Home Assistant). Keep this
    # commented for the very first SD image so it stays minimal — just boot +
    # SSH. Once the Pi is reachable, uncomment and `nixos-rebuild switch` to
    # build it natively.
    # ./services
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
