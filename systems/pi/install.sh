#!/usr/bin/env bash
# Build the minimal Pi SD/USB image, write it to a device, and (optionally)
# seed WiFi credentials so a headless first boot can join the network.
#
# Run this on an aarch64-capable Linux builder (e.g. home-desktop, which has
# `boot.binfmt.emulatedSystems = [ "aarch64-linux" ]`). macOS can't build it.
#
# The service stack (Tailscale/Blocky/monitoring) is intentionally left out of
# the first image — see README.md. Enable it after the first boot.
set -euo pipefail

cd "$(dirname "$0")/../.."

# Build the SD image (uncompressed, per sdImage.compressImage = false).
nix build .#nixosConfigurations.pi.config.system.build.sdImage --print-build-logs
image=$(find -L result/sd-image -name '*.img' -type f)
[[ -f $image ]] || {
	echo "Error: no image found under result/sd-image" >&2
	exit 1
}

# Write the image to the target device.
echo "Available devices:"
lsblk
read -rp "Enter target device (WHOLE device, e.g. /dev/sda): " device
[[ -b $device ]] || {
	echo "Error: '$device' is not a block device" >&2
	exit 1
}
read -rp "This will ERASE $device. Type 'yes' to continue: " confirm
[[ $confirm == yes ]] || {
	echo "Aborted."
	exit 1
}
sudo dd if="$image" of="$device" bs=4M status=progress oflag=sync
sync

# Optionally seed WiFi so the headless Pi can join the network on first boot.
# configuration.nix sets allowAuxiliaryImperativeNetworks, so wpa_supplicant
# honors this imperative config in addition to any declarative networks.
echo
echo "Remove and reinsert the device so NIXOS_SD mounts, then press Enter"
echo "(or press Enter now to skip WiFi setup and use Ethernet instead)."
read -r

read -rp "WiFi SSID (leave blank to skip): " ssid
if [[ -n $ssid ]]; then
	read -rsp "WiFi password: " psk
	echo
	mount="/run/media/$USER/NIXOS_SD"
	[[ -d $mount ]] || read -rp "NIXOS_SD not at $mount — enter its mount path: " mount
	[[ -d $mount ]] || {
		echo "Error: '$mount' does not exist" >&2
		exit 1
	}
	sudo mkdir -p "$mount/etc/wpa_supplicant"
	sudo tee "$mount/etc/wpa_supplicant/imperative.conf" >/dev/null <<-EOF
		network={
		  ssid="$ssid"
		  psk="$psk"
		}
	EOF
	sync
	echo "Wrote $mount/etc/wpa_supplicant/imperative.conf"
fi

echo
echo "Done. Insert the device into the Pi and power it on, then: ssh pi@192.168.0.2"
