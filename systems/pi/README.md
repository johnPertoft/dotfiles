# Raspberry Pi (NixOS)

Headless Raspberry Pi 4 running NixOS. Static IP `192.168.0.2` on `wlan0`,
hostname `pi`. Reachable as `pi.local` (mDNS) or `192.168.0.2`.

The config is split so the **first image is minimal** (just boots + lets you
SSH in); the full service stack (Tailscale, Blocky DNS adblocking, and the
Grafana/Prometheus/Loki monitoring stack) is switched on afterwards and built
natively on the Pi. See `configuration.nix` (base), `services.nix` (the stack),
and `default.nix` (the toggle).

## Prerequisites

- **A Linux aarch64 builder.** macOS can't build a Linux SD image. Use the
  `home-desktop` (x86_64 NixOS) box — it already has
  `boot.binfmt.emulatedSystems = [ "aarch64-linux" ]`, so it can build aarch64
  images under emulation (slow, but mostly pulls from the binary cache).
- **WiFi credentials.** The config declares `wlan0` but ships **no PSK**, so a
  headless Pi won't join WiFi on its own. Either connect **Ethernet** for the
  first boot, or seed WiFi on the card (see below).

## 1. Build the SD/USB image

On `home-desktop`, from a checkout of this repo:

```sh
nix build .#nixosConfigurations.pi.config.system.build.sdImage --print-build-logs
# -> ./result/sd-image/nixos-sd-image-*-aarch64-linux.img   (uncompressed raw image)
```

The service stack is commented out in `default.nix`, so this image is minimal
by design. Leave it that way for the first build.

## 2. Write the image to USB/SD

```sh
lsblk                       # identify the target device, e.g. /dev/sda — DOUBLE CHECK
img=$(find -L result/sd-image -name '*.img' -type f)
sudo dd if="$img" of=/dev/sdX bs=4M status=progress oflag=sync
sync
```

`dd` to the **whole device** (`/dev/sdX`), not a partition (`/dev/sdX1`).
The image labels its root partition `NIXOS_SD`, which is what the config's
`fileSystems."/"` expects — booting from USB works the same as SD.

## 3. (Optional) Seed WiFi before first boot

`configuration.nix` sets `networking.wireless.allowAuxiliaryImperativeNetworks
= true`, so the NixOS-managed wpa_supplicant also honors an imperative
`/etc/wpa_supplicant.conf` on the device — no WiFi password goes into the repo.

`install.sh` prompts for the SSID/password and writes this file for you. Manual
equivalent (re-insert the card so `NIXOS_SD` mounts):

```sh
sudo mkdir -p /run/media/$USER/NIXOS_SD/etc
sudo tee /run/media/$USER/NIXOS_SD/etc/wpa_supplicant.conf <<'EOF'
network={
  ssid="YOUR_SSID"
  psk="YOUR_WIFI_PASSWORD"
}
EOF
sync
```

Or skip WiFi and use **Ethernet** for the first boot — `eth0` picks up an IP via
DHCP and the Pi is reachable at `pi.local`. Seed this file from SSH later.

## 4. First boot + connect

Insert into the Pi and power on. Then:

```sh
ssh pi@192.168.0.2      # or: ssh pi@pi.local
```

Your key (`john.pertoft.pub`) is already authorized. Handy `~/.ssh/config`:

```
Host pi
  HostName pi.local
  User pi
  ForwardAgent yes      # required — sudo on the Pi uses SSH-agent auth
```

## 5. Enable the full service stack

Once the Pi is reachable, uncomment the service import in `default.nix`:

```nix
    ./services.nix
```

Commit/push, then build it natively on the Pi:

```sh
ssh pi
sudo nixos-rebuild switch --flake github:johnPertoft/dotfiles#pi
sudo tailscale up       # one-time, to join the tailnet
```

Grafana is then at `http://pi.local:3000` and Home Assistant at
`http://pi.local:8123` (both also over Tailscale). Point a device's DNS at
`192.168.0.2` to use Blocky adblocking.

## 6. Updating the config later

You never re-flash for config changes — just rebuild.

```sh
# From the Mac; the Pi builds it (native aarch64, fast). Best for testing local edits.
nixos-rebuild switch --flake .#pi --target-host pi --build-host pi --use-remote-sudo

# Or on the Pi itself, pulling from GitHub after you push:
ssh pi
sudo nixos-rebuild switch --flake github:johnPertoft/dotfiles#pi
```

Use `test` instead of `switch` to apply a config **without** making it the boot
default (reverts on reboot) — do this for risky networking/SSH changes. `boot`
applies on next reboot only.

Bump dependencies with `nix flake update --commit-lock-file`, then rebuild.

## 7. Test in a VM (optional)

```sh
nixos-rebuild build-vm --flake .#pi
./result/bin/run-pi-vm       # boots the config in QEMU
```

## Recovery

If a bad config locks you out: pull the card, mount `NIXOS_SD` elsewhere, and
edit `boot/extlinux/extlinux.conf` to boot the previous generation. Or, if you
can still SSH in, `sudo nixos-rebuild --rollback switch`.
