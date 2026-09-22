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

An isolated **GitHub Actions runner VM** is also configured. It starts only
after its registration token has been provisioned; CI use is separately opt-in.
See [GitHub Actions runner](#github-actions-runner).

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
set at runtime** in Jellyfin's admin UI (Dashboard → Playback → Transcoding).

Use **VA-API**, device `/dev/dri/renderD128`. Not QSV — see below.

The iGPU is an **Intel UHD Graphics 630 (CometLake-S GT2, Gen9.5)**. Verified
working: `h264_vaapi` and `hevc_vaapi` encode, and decode of H264, HEVC
Main/Main10, VP9 profile 0/2, VP8, MPEG2, VC1. Known not to work, both because
the silicon is older than the "UHD 6xx" name suggests:

- **QSV** — oneVPL is Gen12/Xe-era and fails with `Error initializing an MFX
session: -3`. Use VA-API.
- **AV1 decode** — not present in this GPU at all.

Re-verify as the `jellyfin` user (running as yourself can mask a group problem),
using Jellyfin's own ffmpeg:

```sh
sudo -u jellyfin nix-shell -p libva-utils --run vainfo   # iHD driver, H264/HEVC VAProfiles
ls -l /dev/dri/renderD128                               # exists, group `render`
id jellyfin                                             # must include render + video

FF=$(ls -d /nix/store/*jellyfin-ffmpeg*-bin/bin/ffmpeg | head -1)
sudo -u jellyfin $FF -init_hw_device vaapi=va:/dev/dri/renderD128 -filter_hw_device va \
  -f lavfi -i testsrc=size=1280x720:rate=30 -t 2 -vf format=nv12,hwupload \
  -c:v h264_vaapi -f null -                             # a real HW encode
sudo -u jellyfin $FF -init_hw_device opencl=ocl -f lavfi -i testsrc -t 0.1 -f null -
```

That last one gates **HDR→SDR tonemapping**. It needs
`intel-compute-runtime-legacy1`; the non-legacy `intel-compute-runtime` supports
12th Gen and newer only and fails here with
`Failed to get number of OpenCL platforms: -1001`.

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

## GitHub Actions runner

One persistent NixOS/KVM VM provides one GitHub Actions job slot for
`johnPertoft/dotfiles`. GitHub sees `thinkcentre-nix-1`, with labels
`self-hosted`, `linux`, `x64`, `nix`, and `homelab`. The runner connects outbound;
there are no forwarded ports, SSH server, or Tailscale connection in the VM.

The guest gets 2 vCPUs, 4 GiB RAM, and a **100 GiB sparse disk**. The host limits
the whole VM to 200% CPU and 5 GiB RAM, with reduced CPU/I/O priority. These are
conservative starting limits; adjust `services/github-runner/{default,guest}.nix`
if builds need more memory. The disk grows as it is used, so budget real free
space on the host, particularly for the desktop/CUDA closure. Changing
`diskSize` only affects initial creation, not an existing disk.

### Generate the token

In your **personal GitHub Settings**, open **Developer settings → Personal
access tokens → Fine-grained tokens → Generate new token**:

- Resource owner: **johnPertoft**.
- Repository access: **Only select repositories → dotfiles**.
- Repository permissions: **Administration → Read and write**. Metadata read
  access is automatic; no Contents write, Actions write, or organization
  permissions are needed.
- Set an expiration and a reminder to rotate it before it expires.

Use a fine-grained PAT, **not** the one-hour token from “New self-hosted runner”.
The NixOS service exchanges the PAT for registration tokens when required.
Administration write is the permission GitHub requires for repository runner
registration, so treat this as a sensitive repository-admin credential.

### Provision and activate when home

On the ThinkCentre, create the root-only directory, then use a hidden prompt
to write the token without putting it in shell history or command arguments:

```sh
sudo install -d -m 0700 /etc/nixos-secrets
sudo bash -c '
  set -euo pipefail
  umask 077
  read -r -s -p "GitHub runner PAT: " token
  printf "\n"
  test -n "$token"
  printf "%s" "$token" > /etc/nixos-secrets/github-runner.token
  chmod 0600 /etc/nixos-secrets/github-runner.token
'
```

Do not put the token in Git, a Nix expression, or a GitHub Actions secret.
The host loads it through systemd credentials and passes it to the guest via
QEMU firmware credentials. The guest keeps it root-only; it is not exposed as
a job environment variable.

Once this configuration is committed and pushed, activate it on the host:

```sh
sudo nixos-rebuild switch --flake github:johnPertoft/dotfiles#thinkcentre
sudo systemctl status github-runner-vm
sudo journalctl -u github-runner-vm -f
```

If you already activated the configuration without the token, the VM service
was skipped. After provisioning the file, start it with
`sudo systemctl start github-runner-vm`.

The first boot creates the disk and registers the runner. In **dotfiles →
Settings → Actions → Runners**, wait for `thinkcentre-nix-1` to show **Idle**.
Then create the **repository variable** (not a secret)
`ENABLE_SELF_HOSTED_BUILDS` with value `true`, under **Settings → Secrets and
variables → Actions → Variables**. Alternatively, from an authenticated dev box:

```sh
gh variable set ENABLE_SELF_HOSTED_BUILDS --body true --repo johnPertoft/dotfiles
gh workflow run check.yaml --ref main --repo johnPertoft/dotfiles
```

Until that variable is set, the self-hosted job is skipped and the existing
GitHub-hosted checks continue normally. Once enabled, only pushes to `main`
and manual runs on `main` can use this workflow's runner job. Pull requests
and other branches only run GitHub-hosted checks. An offline/busy runner queues
eligible jobs; GitHub does not automatically fall back to a hosted runner.

### State, maintenance, and trust

The persistent disk is `/var/lib/github-runner-vm/runner.qcow2`; it contains the
guest's Nix store, runner registration, and work directory. The boot store image
is recreated under `/var/cache/github-runner-vm`. Before switching to the guest
root, missing boot closure paths are copied into its persistent store. Old
paths remain available across guest upgrades until normal GC removes them;
the store does not depend on an old boot image staying mounted. No host
directories, host Nix store, or host Nix daemon socket are shared with the VM.

Guest Nix builds use one build slot and two cores per build. Automatic GC runs
weekly, with pressure-triggered GC below 5 GiB free (targeting 10 GiB). The store
is reusable between jobs, but unrooted build results are not retained forever.
Checkout/workspace state is not a guaranteed cache: the runner service cleans
its work directory on restart. CI builds both x86 Linux system closures; it
does **not** activate them, test booting, or publish a binary cache.

Host systemd IP filtering blocks QEMU from reaching loopback, private LAN,
link-local, multicast, and Tailscale address ranges. The guest uses public DNS.
This is defense in depth, not permission to run untrusted jobs: GitHub recommends
self-hosted runners only for private repositories. This repository is public;
keep the runner limited to reviewed code on `main`. Do not add PR jobs or
`pull_request_target` workflows that check out untrusted code on it. Runner
labels are routing hints, not an authorization boundary. A persistent runner
can retain changes made by an earlier job.

To rotate the token, repeat the hidden-prompt command and then run:

```sh
sudo systemctl restart github-runner-vm
```

Restart only when idle; it interrupts a running job. The registration name is
reused. Host rebuilds that change the VM configuration also restart it; the
runner package is updated declaratively with NixOS, not by its self-updater.
Keep it current because GitHub enforces runner version requirements. To pause
CI routing, set `ENABLE_SELF_HOSTED_BUILDS` to `false`; to stop the VM too, run
`sudo systemctl stop github-runner-vm`. A host reboot starts it again if the
token is present.

The runner includes Node 24 only; Node 20 is end-of-life and rejected by this
Nixpkgs pin. Use current actions (the build job uses `actions/checkout@v6`).
Some runner features, notably `hashFiles()`, may still require Node 20; avoid
those on this runner rather than permitting an insecure runtime.

Additional personal repositories need their own runner registrations. An
organization-scoped pool or a separate Ubuntu VM for non-Nix workflows can be
added later; neither is configured here. The Pi is unchanged.

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
