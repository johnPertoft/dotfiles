# ⚠️  PLACEHOLDER — this file is NOT the real hardware config.
#
# The ThinkCentre isn't physically here yet, so this stub exists only so the
# flake still *evaluates* (`nix flake check` / CI evaluate every host's
# toplevel, and that requires a root filesystem + platform). Everything below is
# fake but eval-valid.
#
# On the real box, first install, run:
#     sudo nixos-generate-config --root /mnt      # (during install)
#   or, once booted:
#     sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
# and REPLACE this whole file with the generated one (real fileSystems by
# UUID/label, initrd modules, CPU microcode, etc.). The bootloader lives in
# configuration.nix, so leave that alone.
{ lib, ... }:

{
  # Fake root + ESP so evaluation succeeds. Overwritten by the generated config.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
