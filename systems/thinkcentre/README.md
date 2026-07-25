# Lenovo ThinkCentre (NixOS)

Headless x86_64 homelab box that takes over most of the Pi's duties, with more
compute for **hardware-transcoded** Jellyfin (Intel iGPU) plus room for the
future \*arr stack. Hostname `thinkcentre`, reachable as `thinkcentre.local`
(mDNS) or over Tailscale (`thinkcentre`).

Managed exactly like the Pi: key-only SSH, declarative users, rebuilt with
`nixos-rebuild switch` — but this is a normal UEFI x86_64 install (systemd-boot,
wired Ethernet via DHCP), not an SD image.

## Status: config-only, no hardware yet

The machine isn't physically here. Everything is committed **except the real
`hardware-configuration.nix`** — that file is a **placeholder** so the flake
still evaluates (CI runs `nix flake check`). It has a fake root FS and does
nothing real.

Services enabled here: **Tailscale, Blocky (DNS adblock), Jellyfin (HW
transcode), Transmission, Mealie, Home Assistant, a monitoring client
(node-exporter + Alloy), and a www landing page.** The Prometheus/Loki/Grafana
**hub stays on the Pi** — this box is a monitoring _client_.

Nothing on the Pi is changed by this config; it's purely additive. Blocky/HA/etc.
run on both boxes during migration and the Pi's copies get retired at cutover.

## First install (once the hardware arrives)

1. Boot the NixOS installer, partition + mount the disk (GPT: an EFI system
   partition at `/mnt/boot`, ext4 root at `/mnt`).
2. **Generate the real hardware config** and overwrite the placeholder:

   ```sh
   sudo nixos-generate-config --root /mnt
   # copy the generated systems/thinkcentre/hardware-configuration.nix into a
   # checkout of this repo, replacing the placeholder, and commit it.
   ```

3. Install against this flake:

   ```sh
   sudo nixos-install --flake github:johnPertoft/dotfiles#thinkcentre
   ```

4. Reboot, then `ssh john@thinkcentre.local` (your key is authorized), and
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

## Test in a VM before the hardware exists

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

- **Real `hardware-configuration.nix`** — replace the placeholder (see above).
- **Swap the SSH key** — reuses the Pi's _work_ key (`john.pertoft@king.com`),
  the sole way onto the box. Swap for a personal key additively (add → verify →
  remove) to avoid lockout.
- **DNS cutover** — move this box to the static `192.168.0.2` and retire the
  Pi's Blocky (re-point router/clients). Until then two Blocky instances coexist.
- **Monitoring hub wiring** — the Pi must expose Loki to accept this box's Alloy
  pushes and add a `thinkcentre:9100` scrape target. That's a _Pi-side_ edit,
  intentionally not done here. See `services/monitoring/default.nix`.
- **Shared modules** — the service modules were copied from the Pi rather than
  factored out; dedupe once both boxes are settled.
