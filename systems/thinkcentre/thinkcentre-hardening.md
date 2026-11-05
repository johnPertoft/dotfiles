# ThinkCentre hardening, isolation, and storage — design notes

Future design notes, not current state. Nothing here is implemented yet; it
collects a discussion (2026-11-05) about hardening the ThinkCentre, isolating
its services without Docker, impermanence, and redundancy/backups via an
offsite "vault" box. Starting point was the isolation section of
[this video](https://www.youtube.com/watch?v=zCzQ88aXV4g) about moving VPS
deployments from Docker to plain NixOS.

Context: nothing on the box is critical. Jellyfin and Transmission are the most
used; nothing goes through Blocky yet (but might later).

## 1. Deployment methods from the video

| Method                                                                           | Pros                                                                                                          | Cons                                                                                                                                 |
| -------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| **Registry image + `virtualisation.oci-containers`** (Podman backend by default) | Familiar, works with any published image                                                                      | Image pulled at **activation**, not build — a bad tag/registry outage fails mid-switch and leaves the service down; not reproducible |
| **`dockerTools.pullImage`**                                                      | Image fetched into the store at **build** time; failures leave the box untouched; no registry auth on the box | Still need to build/publish the image somewhere                                                                                      |
| **`dockerTools.buildImage`**                                                     | Image built by Nix alongside the config from a flake package; no registry, no Dockerfile                      | Requires packaging the app with Nix — at which point the image wrapper adds little                                                   |
| **Plain systemd service from a Nix package** (his endpoint)                      | Simplest; reproducible, rollback-able, fails at build                                                         | Loses container isolation for free — needs to be added back (§2); only for software packaged in Nix                                  |

Relevance here: Home Assistant is the first row (`:stable` floating tag,
pulled at activation). Parked for now; `pullImage` with a pinned digest would
fix it. Everything else is already a native NixOS module (last row).

## 2. Isolation without Docker/Podman

All options use the same kernel primitives — **namespaces** (what a process
sees), **cgroups** (what it may use), **capabilities** (which slices of root it
keeps), **seccomp** (which syscalls it may make). All share the host kernel;
only a VM (e.g. microvm.nix) has its own.

### systemd sandboxing — start from the host, subtract

The service stays a host process; unit settings take things away:

```nix
systemd.services.mealie.serviceConfig = {
  DynamicUser = true;
  ProtectSystem = "strict";
  ReadWritePaths = [ "/var/lib/mealie" ];
  ProtectHome = true;
  PrivateTmp = true;
  PrivateDevices = true;
  NoNewPrivileges = true;
  CapabilityBoundingSet = "";
  SystemCallFilter = [ "@system-service" ];
  RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
  MemoryMax = "1G";
};
```

- Near-zero overhead; paths, ports and URLs don't change.
- Fine-grained, but fails silently (e.g. `PrivateDevices` breaks Jellyfin's
  `/dev/dri` transcoding with no clear error).
- No own network/IP (`PrivateNetwork` = loopback only).
- Many nixpkgs modules already set some of this. Measure with
  `systemd-analyze security <unit>`.

### NixOS containers — start empty, add

A full NixOS system under systemd-nspawn (`containers.<name>`): own init,
services, users, journal, firewall; optionally its own network
(`privateNetwork`, veth, `forwardPorts`); own root under
`/var/lib/nixos-containers/<name>` plus read-only shared `/nix/store`;
`bindMounts` for data; `ephemeral = true` for wipe-on-restart. Built and rolled
back with the host.

- **Not a strong security boundary by default**: no user namespace, so
  container root is host root. The NixOS manual says not to rely on them for
  untrusted code. Good at separation (ports, files, process interference).
- Combines with systemd sandboxing inside the container.
- Boilerplate per service — the video's answer is a helper abstraction (package,
  ports, secrets, env, ingress).

### NixOS containers vs Docker

|                   | NixOS container                               | Docker / Podman                                                  |
| ----------------- | --------------------------------------------- | ---------------------------------------------------------------- |
| Artifact          | None — built from config, shares `/nix/store` | Layered image tarball with its own copy of every library         |
| Inside            | Whole OS: systemd as PID 1, many services     | Usually one process as PID 1                                     |
| Defined by        | Nix, built/rolled back with the host          | Dockerfile + tag; contents decided where the image was built     |
| Runtime           | systemd (`container@x.service`)               | `dockerd` (Podman: daemonless)                                   |
| Default hardening | Fairly permissive                             | Drops capabilities, default seccomp; rootless Podman adds userns |
| Networking        | veth + NAT/forwardPorts you wire up           | Built-in bridge, `-p` publishing                                 |
| Portability       | NixOS hosts only                              | Any Linux host with a runtime                                    |

Docker's _defaults_ are stricter (and `--privileged` turns them all off). The
real difference is packaging: NixOS doesn't need images because the store
already pins every dependency.

Rough strength ordering: plain service < systemd sandbox < NixOS container ≈
Docker < microVM. A well-hardened unit can be tighter than a default container;
the container's real extra is its own network and filesystem.

### Per-service view

| Service                                   | Suggestion                                                                                                                               |
| ----------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Home Assistant (`--privileged`, host net) | Weakest spot. Drop `--privileged` once no USB radios need it; pass specific devices. (Parked.)                                           |
| Transmission (talks to internet peers)    | Best container candidate, especially if routing it through a VPN. Watch UID/GID consistency so Jellyfin can still read `/srv/downloads`. |
| Jellyfin                                  | systemd hardening only — a container means GPU passthrough and redoing the VA-API verification.                                          |
| Mealie                                    | Easy container practice if wanted; hardening gets most of the benefit.                                                                   |
| Blocky                                    | Unused today, so now is the cheapest time to harden/containerize before it becomes LAN DNS.                                              |

Container consequences for users: forwarded ports are tied to the external
interface, so tailnet and on-box access can break unless wired separately;
state moves into the container unless bind-mounted; UIDs inside may differ from
the host; container journals need extra wiring to reach Loki.

## 3. Hardening gaps (from reading the repo)

Already good: key-only SSH (`PasswordAuthentication` and
`KbdInteractiveAuthentication` off), no root login, fail2ban, declarative users,
firewall with Transmission RPC and node-exporter kept off the LAN.

Gaps, roughly by priority:

1. **Patches only land on manual deploys.** CI bumps `flake.lock` weekly but
   nothing applies it. Consider `system.autoUpgrade` against
   `github:johnPertoft/dotfiles#thinkcentre` (CI already caches the build).
2. **The work SSH key is effectively root** (passwordless sudo). Swap to a
   personal key (existing TODO); add `AllowUsers = [ "john" ]`.
3. **The whole tailnet is trusted** (`trustedInterfaces = [ "tailscale0" ]`).
   Use Tailscale ACLs to limit who reaches which port. Set
   `useRoutingFeatures = "none"` unless the box is a subnet router/exit node.
4. **Unauthenticated services**: Transmission RPC (fine once ACLs exist; a
   `credentialsFile` is cheap), Mealie's default admin login (verify changed),
   Home Assistant `--privileged` on the LAN.
5. **No per-service sandboxing** beyond module defaults (§2).
6. **Housekeeping**: `nix.gc.automatic`; `boot.loader.systemd-boot.configurationLimit`
   so `/boot` can't fill and break a switch.
7. **No detection**: the monitoring hub isn't wired, so failures/intrusions go
   unnoticed.
8. **Optional**: LUKS with TPM2 auto-unlock (easiest at a reinstall);
   cherry-picked kernel sysctls (`kernel.dmesg_restrict`, `kernel.kptr_restrict`,
   `security.protectKernelImage`) rather than the whole
   `profiles/hardened.nix`; sops-nix/agenix for secrets.

## 4. Impermanence

Root wiped every boot (tmpfs, or ZFS/btrfs rollback to an empty snapshot); only
`/nix` and `/persist` survive. Must persist on this box:

| Path                                                                    | If lost                                                          |
| ----------------------------------------------------------------------- | ---------------------------------------------------------------- |
| `/etc/nixos-secrets/john.pw`                                            | **Lockout** — no password, no console login                      |
| `/etc/ssh/ssh_host_*`                                                   | New host keys every boot; breaks sops/agenix host-key decryption |
| `/var/lib/nixos`                                                        | UID/GID map drifts → wrong ownership on `/srv/media`             |
| `/var/lib/tailscale`                                                    | Leaves the tailnet every reboot                                  |
| `/var/lib/jellyfin`, `/var/lib/transmission`, `/var/lib/home-assistant` | Libraries, history, torrents, HA config                          |
| `/var/lib/private/mealie`                                               | Recipes (`DynamicUser` → `private/`)                             |
| `/etc/machine-id`, `/var/log`                                           | Journal continuity                                               |

Media/downloads live on their own pool under `/srv`, not in `/persist`.
Rehearse in `nixos-rebuild build-vm` first. With impermanence, `/persist` _is_
the backup list.

## 5. Storage redundancy

- **RAID is not backup** — it covers a dead disk, not deletion, ransomware, a
  bad switch, fire or theft.
- **Media is mostly replaceable** (re-downloadable); state and photos are not.
  That decides what goes offsite.

| Local layout            | Pros                                                                                | Cons                                                                |
| ----------------------- | ----------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| **ZFS mirror**          | Checksums + self-repair, snapshots, `zfs send` replication, pairs with impermanence | Out-of-tree module pins kernel; needs `networking.hostId`; more RAM |
| **btrfs RAID1**         | In-kernel, checksums, snapshots, mixed sizes                                        | RAID5/6 untrustworthy; less mature repair tooling                   |
| **mdadm RAID1 + ext4**  | Simple, proven                                                                      | No checksums (silent bitrot), no snapshots                          |
| **mergerfs + SnapRAID** | Mixed disks, one parity for many, disks readable alone, only active disk spins      | Parity on a schedule — recent writes unprotected                    |

Leaning: **ZFS mirror** for two disks. Whatever the layout: `services.smartd` +
scheduled scrubs with alerts, or a degraded mirror goes unnoticed.

Check the ThinkCentre model first — a Tiny fits ~one NVMe + one 2.5" drive.

## 6. Backups — 3-2-1(-1-0)

- **3** copies, **2** different devices, **1** offsite. A mirror is one copy.
- **+1** offline/immutable (borg append-only, `rest-server --append-only`, B2
  Object Lock) — the home box can add but not delete.
- **0** errors — `restic check` / `borg check` / scrubs, and tested restores.

Copies in this design:

1. ThinkCentre (mirrored).
2. Offsite vault box (pull-based ZFS replication).
3. Cloud: restic/borg to Hetzner Storage Box or B2, append-only — only for
   irreplaceable data (photos, DB dumps, `/persist`), so it stays cheap.

| Data                  | Replaceable? | Copies                             |
| --------------------- | ------------ | ---------------------------------- |
| Immich originals + DB | No           | 3: home mirror, offsite, cloud     |
| Mealie DB, `/persist` | No (small)   | 3                                  |
| Movies/shows          | Yes          | 1–2: home mirror, offsite optional |

With a cloud copy, one offsite disk is acceptable; without it, mirror the
offsite box. Buy mirror disks from different batches.

### Immich / Mealie specifics (future)

- **Immich** (`services.immich`, Postgres): back up `library/`/`upload/`
  (originals) + `backups/` (Immich's scheduled DB dumps). Skip `thumbs/` and
  `encoded-video/` (regenerable). Do a restore drill.
- **Mealie** (SQLite): ZFS snapshots are crash-consistent; additionally
  `sqlite3 mealie.db ".backup …"` before backups, or Mealie's own export.
- Keep **logical dumps** (`pg_dump`) next to snapshots — a raw Postgres data dir
  only restores on the same major version.

## 7. Offsite vault box

### Role: backup target + cold standby, not active-active

- A backup must not share failure modes with the primary; active copies of live
  data do.
- Jellyfin/Mealie SQLite and Transmission state can't run in two places at once.
- Two homes are WAN-apart: TB media sync and streaming over home upload is
  slow, and offsite failover doesn't help if _home_ internet is down.
- So: hold data, _able_ to take over. Real HA (keepalived, k3s/Nomad,
  Litestream) is better learned on a second box on the LAN.

### Replication

- `/persist` split into datasets — datasets are the backup policy:

  ```
  rpool/persist/system     host keys, machine-id, /var/lib/nixos, john.pw → replicate, long history
  rpool/persist/services   app state, DB dumps                           → replicate, hourly
  rpool/persist/identity   /var/lib/tailscale                            → don't restore on standby
  rpool/persist/cache      regenerable caches                             → don't replicate
  tank/media, tank/photos                                                 → own schedules
  ```

- Replicate **snapshots**, not live dirs (crash-consistent DBs).
- **ZFS native encryption + raw send** (`zfs send -w`): the vault stores
  ciphertext and never has the key; it can still receive, scrub and prune. Key
  loaded by hand only at failover. Keep the key in a password manager + on
  paper — not only on the ThinkCentre.
- **Vault pulls** (`services.syncoid`) over Tailscale from a restricted
  `zfs-send` user on the ThinkCentre (`zfs allow … send,hold`). The ThinkCentre
  holds no credentials for the vault.
- **sanoid**: ThinkCentre snapshots (short retention); vault only prunes
  (`autosnap = false`) with longer retention (e.g. 72h / 60d / 24m).
- Received datasets `readonly=on`, `canmount=off`.

### Vault config sketch (`systems/vault/`)

- Same `server.nix` baseline; can be impermanent itself.
- SSD for OS; HDD pool `backup/thinkcentre/{persist/*,photos,media}`.
- ZFS: `boot.supportedFilesystems = [ "zfs" ]`, `networking.hostId`,
  `services.zfs.autoScrub`, `services.smartd`.
- Network: Tailscale only, no router ports; ACLs allow vault → `thinkcentre:22`
  and nothing in reverse.
- BIOS: power on after power loss; TPM auto-unlock if the OS disk is encrypted.
- **Standby as a specialisation**: import the same `./services` (disabled) plus
  `specialisation.failover` enabling them on clones. Failover runbook:
  `zfs load-key` → `zfs clone` latest snapshots → activate specialisation →
  repoint DNS/Tailscale. Received history is never touched. Measure **RPO**
  (snapshot interval) and **RTO** (drill time).
- **Monitoring**: snapshot freshness (`sanoid --monitor-snapshots`, alert at
  ~2× interval), smartd, scrub results — shipped to the same hub.
- Because the vault can't decrypt, the **cloud backup runs on the
  ThinkCentre**, from a snapshot path (`/persist/.zfs/snapshot/<latest>/…`).
- Seed the first full replication on the LAN, then move the box offsite.

### Hardware

Prefer something close to the ThinkCentre so the same Jellyfin VA-API config
carries over: used **Lenovo M720t/M920t (tower) or M720s/M920s (SFF)**, Intel
8th/9th gen, native SATA + 3.5" bays. Tower if two+ disks.

**Lenovo M715q Tiny (Ryzen 3 PRO 2200GE, 8 GB, 128 GB)** — fine as a pure
backup target (CPU/RAM plenty without dedup; 2× SO-DIMM for 16 GB; ~10 W idle),
weaker as a standby (AMD, so the Intel Jellyfin config doesn't carry over;
Immich ML slow). Storage per
[Lenovo PSREF](https://psref.lenovo.com/syspool/Sys/i_pdf/psref500.pdf): one
internal 2.5" SATA, one M.2 storage slot, one M.2 Wi-Fi slot, no PCIe riser
(unlike M720q/M920q). Ways to attach HDDs:

- **USB enclosures** — simple; risk of dropouts and SMART not passing through.
- **M.2 → SATA adapter** (ugly but proper): boot from the 2.5" SATA bay, put an
  ASM1166 (6 port) / JMB585 (5 port) M.2 adapter in the storage slot (or a
  2-port A+E adapter in the Wi-Fi slot), route cables out, power drives from a
  small jumpered ATX PSU or 12 V brick/PicoPSU; make drive power come on after
  outages. Verify slot keying on the actual unit.

Once adapter + PSU are added, the price gap to a used tower mostly disappears.

## 8. disko

Fits this design: declarative partitions, pools, datasets and properties per
host; creates the `@blank` snapshot for impermanence; pairs with
**nixos-anywhere** to install the vault over SSH.

Caveats: provisioning only (destructive at install; later dataset changes are
manual _and_ must be mirrored in the config); the ThinkCentre's ext4 root needs
a reinstall to adopt it; regenerate `hardware-configuration.nix` with
`--no-filesystems`; use `/dev/disk/by-id/…`; keep the vault's disko minimal —
received datasets carry their own encryption.

Order: disko configs for both hosts → test in VMs → nixos-anywhere the vault at
home → migrate the ThinkCentre.

## 9. Assertions

`assertions` / `warnings` are evaluated against the final merged config; a
failed assertion stops `nixos-rebuild`, `nix build` and `nix flake check`
before anything is built or activated (CI's flake check catches them on PRs).
They can't inspect the running machine — use systemd conditions, activation
scripts or NixOS VM tests (`pkgs.testers.runNixOSTest`) for that. Only _read_
config in them to avoid infinite recursion.

The config's "must" comments are the candidates:

```nix
# services/transmission — RPC is unauthenticated
{ assertion = !config.services.transmission.openRPCPort
    && !(lib.elem 9091 config.networking.firewall.allowedTCPPorts);
  message = "Transmission RPC is unauthenticated; 9091 must not be open on the LAN."; }

# configuration.nix — allowlist of LAN-open ports
let allowed = [ 22 53 80 8096 8123 9000 ];
    extra = lib.subtractLists allowed config.networking.firewall.allowedTCPPorts;
in { assertion = extra == [ ];
     message = "Unexpected LAN-open TCP ports: ${toString extra}."; }

# server.nix — SSH stays key-only
{ assertion = !config.services.openssh.settings.PasswordAuthentication
    && !config.services.openssh.settings.KbdInteractiveAuthentication;
  message = "SSH must be key-only."; }

# services/jellyfin — VA-API needs these groups
{ assertion = lib.all (g: lib.elem g config.users.users.jellyfin.extraGroups) [ "render" "video" ];
  message = "jellyfin needs render+video for /dev/dri/renderD128."; }

# services/blocky — LAN DNS needs a static address
{ assertion = !config.networking.useDHCP
    && config.networking.interfaces.eno2.ipv4.addresses != [ ];
  message = "Blocky serves LAN DNS; the host needs a static address."; }
```

With impermanence: assert that every enabled service's state dir (plus
`/var/lib/nixos`, `/etc/nixos-secrets`) is in
`environment.persistence."/persist".directories` (normalising string vs
attrset entries), and that ZFS hosts set `networking.hostId`. Use `warnings`
for preferences (e.g. floating image tags).

## Suggested order (whenever this is picked up)

1. Cheap hardening: auto-upgrade decision, `nix.gc`, boot entry limit,
   `AllowUsers`, personal SSH key, Tailscale ACLs, `useRoutingFeatures`.
2. `systemd-analyze security` baseline; harden Transmission, Jellyfin, Mealie.
3. Assertions for the existing "must" rules.
4. Disks: buy mirror disks (+ vault hardware); write disko configs; VM-test.
5. Reinstall the ThinkCentre on ZFS + impermanence (+ LUKS/TPM).
6. Vault with pull replication, monitoring, then a timed failover drill.
7. Cloud copy (append-only) of photos, DB dumps, `/persist`; Immich when ready.
