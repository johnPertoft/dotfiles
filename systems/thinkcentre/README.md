# Lenovo ThinkCentre (NixOS)

Headless x86_64 homelab server — media (**hardware-transcoded** Jellyfin, Intel
iGPU), downloads, recipes, home automation, and DNS adblocking, with room for
the future \*arr stack. Hostname `thinkcentre`, reachable as `thinkcentre.local`
(mDNS) or over Tailscale (`thinkcentre`).

Key-only SSH, declarative users, rebuilt with `nixos-rebuild switch`. A normal
UEFI x86_64 install (systemd-boot, static wired Ethernet on `192.168.0.3`).

## Status: deployed

The machine is here, installed, and on the LAN at `192.168.0.3` (static, wired
`eno2`) with Tailscale up. `hardware-configuration.nix` is the real generated
one.

Services enabled here: **Tailscale, Blocky (DNS adblock), Jellyfin (HW
transcode), Transmission, Mealie, Home Assistant, a monitoring client
(node-exporter + Alloy), and a www landing page.** The Prometheus/Loki/Grafana
**hub lives on another host** — this box is a monitoring _client_.

This config is purely additive and changes nothing on the existing homelab host;
overlapping services (Blocky, Home Assistant, …) run in parallel during
migration and the old copies are retired at cutover.

### Two bits of required state that live outside the repo

Both are easy to forget and both fail silently-ish:

- **`/etc/nixos-secrets/john.pw`** — `users.users.john.hashedPasswordFile` reads
  it on _every_ activation, and `users.mutableUsers = false` means there's no
  fallback: if the file is missing, `john` gets no password and there is no
  console login at all. Seed it as root with
  `mkpasswd -m sha-512 > /etc/nixos-secrets/john.pw && chmod 0600` (the hash is
  deliberately not committed — this repo is public and `$6$` is offline-crackable).
- **A network path for the _first_ switch.** Nothing here enables NetworkManager
  or wpa_supplicant, so a machine that is online only over WiFi will drop off
  the network the moment it activates this config. Have Ethernet plugged in, or
  bring your own temporary link (USB tethering works — but note `useDHCP` is
  `false`, so a temporary interface needs its own config).

## Reinstalling from scratch

1. Boot the NixOS installer, partition + mount the disk (GPT: an EFI system
   partition at `/mnt/boot`, ext4 root at `/mnt`).
2. Regenerate `hardware-configuration.nix` if the disks changed:

   ```sh
   sudo nixos-generate-config --root /mnt
   # copy the generated systems/thinkcentre/hardware-configuration.nix into a
   # checkout of this repo and commit it.
   ```

3. Install against this flake:

   ```sh
   sudo nixos-install --flake github:johnPertoft/dotfiles#thinkcentre
   ```

4. Seed `/etc/nixos-secrets/john.pw` (see above) **before** the first switch.
5. Reboot, then `ssh john@thinkcentre.local` (your key is authorized), and
   `sudo tailscale up` once to join the tailnet.

## Verify Intel transcoding

Nix provides the drivers + render-node access; the **HW-accel toggle itself is
set at runtime** in Jellyfin's admin UI (Dashboard → Playback → Transcoding →
VA-API or QSV, device `/dev/dri/renderD128`).

```sh
nix-shell -p pciutils --run 'lspci -nn | grep -i vga'   # confirm the iGPU / gen
nix-shell -p libva-utils --run vainfo                   # should list H264/HEVC VAProfiles via iHD
ls -l /dev/dri/renderD128                                # exists, group `render`
```

If it's a pre-Broadwell part (unlikely for "UHD"), swap `intel-media-driver` →
`intel-vaapi-driver` in `services/jellyfin/default.nix`.

## Test the service stack in a VM

```sh
nixos-rebuild build-vm --flake .#thinkcentre
./result/bin/run-thinkcentre-vm     # boots the service stack in QEMU (no iGPU passthrough)
```

## Updating later

```sh
sudo nixos-rebuild switch --flake github:johnPertoft/dotfiles#thinkcentre
# or, from a dev box, build remotely:
nixos-rebuild switch --flake .#thinkcentre --target-host thinkcentre --build-host thinkcentre --use-remote-sudo
```

## Outstanding TODOs / cutover work (all deferred)

- **Swap the SSH key** — currently the _work_ key (`john.pertoft@king.com`).
  Swap for a personal key additively (add → verify → remove) to avoid lockout.
- **DNS cutover** — move this box from `192.168.0.3` to `192.168.0.2` and retire
  the Pi's Blocky (re-point router/clients). Until then the two coexist. The
  address is a one-line change in `configuration.nix`; the Pi has to give
  `.2` up first.
- **Monitoring hub wiring** — the hub host must expose Loki to accept this box's
  Alloy pushes and add a `thinkcentre:9100` scrape target. Deferred; see
  `services/monitoring/default.nix`.
- **Shared modules** — the service modules are copied rather than factored into a
  shared set; dedupe across hosts once things settle.
