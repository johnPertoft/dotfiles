# LAN DNS via Blocky — design notes

Future design notes, not current state. Collects a discussion (2026-11-06)
about routing home-network DNS through Blocky, with fallback when the box
running it is down. Companion to
[thinkcentre-hardening.md](./thinkcentre-hardening.md).

Current state: Blocky runs on the ThinkCentre (`192.168.0.3`, wired `eno2`)
and on the Pi (`192.168.0.2`, WiFi `wlan0`), both listening on port 53 on all
addresses, both forwarding to Cloudflare DoH only. No device on the network
uses either yet. The router is a consumer TP-Link.

Decision so far: **run two Blocky instances** (ThinkCentre + Pi) rather than
retiring the Pi's at cutover.

## 1. Pointing devices at Blocky

**Per device**: set the device's DNS server manually (e.g. the TV →
`192.168.0.3`). Works because the address is static, but tedious, and phones /
laptops often reset DNS per network.

**Automatically, via router DHCP (preferred)**: the router's DHCP server hands
every device an IP _and_ DNS servers. On most TP-Link routers: **Advanced →
Network → DHCP Server → Primary/Secondary DNS** (varies by model/firmware).
Devices pick it up on lease renewal — reconnect them or reboot the router.

Don't use the **WAN/Internet** page's DNS setting for this: devices would still
ask the router, which forwards to Blocky, so every query looks like it comes
from the router and per-client stats are lost.

Verify on a device: `nslookup doubleclick.net` → `0.0.0.0` from Blocky.

**Forcing all DNS** (redirecting port 53 regardless of device settings) isn't
possible on stock TP-Link firmware — it needs a firewall NAT rule, i.e.
OpenWrt-class firmware. Known leaks even with DHCP:

- Android/Google TV, Chromecast sometimes hardcode `8.8.8.8`.
- DNS-over-HTTPS in browsers/apps (e.g. Firefox) bypasses LAN DNS entirely.
- IPv6: if the router advertises ISP DNS over IPv6, devices may use it. Check
  the router's IPv6/LAN settings or disable LAN IPv6 if ads still show.

## 2. Fallback when Blocky is down

Requirement: if Blocky is unavailable, ads are preferable to "the internet is
down". The ThinkCentre and Pi get tinkered with, so neither is ultra stable.

### How devices use multiple DNS servers

There is no reliable way to make devices query servers sequentially — the OS
decides, and the router can't change it:

| Device                   | Behaviour                                            |
| ------------------------ | ---------------------------------------------------- |
| Linux (glibc)            | In order; next server only after a timeout (5 s)     |
| Linux (systemd-resolved) | Sticks with the last server that worked              |
| Windows                  | First, then after ~1 s all others; remembers fastest |
| macOS/iOS                | Often several in parallel, uses whichever answers    |
| Android, TVs, consoles   | Varies; often parallel/fastest                       |

So a public resolver in the list isn't a fallback — it's a peer, and ads leak
through it even while Blocky is healthy. DHCP allows any number of DNS servers,
but most TP-Link DHCP pages only have two fields, and a third would leak the
same way.

### Options

| Setup                                                     | Ads blocked when up | Internet when both boxes down |
| --------------------------------------------------------- | ------------------- | ----------------------------- |
| A. Blocky + `1.1.1.1` as secondary                        | ⚠️ leaks            | ✅                            |
| B. ThinkCentre Blocky + Pi Blocky                         | ✅ always           | ❌ until one is back          |
| C. Floating IP over both Blockys + `1.1.1.1` as secondary | ⚠️ mostly           | ✅                            |
| D. OpenWrt router with dnsmasq `strict-order` fallback    | ✅                  | ✅                            |

- **B** is the practical choice on the current router. Mitigate "both down" by
  never tinkering with both at once, and using `nixos-rebuild test` (not the
  boot default — a reboot restores the last good generation) or
  `nixos-rebuild switch --rollback`.
- **C** is the learning upgrade (§3), if some leakage is acceptable.
- **D** is the only setup that gets both; it needs a router that can run
  OpenWrt. Some stock TP-Link firmware forwards DNS through the router itself,
  but its ordering behaviour can't easily be confirmed.

### Making each Blocky sturdier

- **Multiple upstreams**: currently Cloudflare DoH only — if that endpoint is
  unreachable, every lookup fails even with the box healthy. Add e.g.
  `https://dns.quad9.net/dns-query`; Blocky races upstreams.
- **Startup**: check Blocky's blocklist loading strategy option (name varies
  by version) so it serves immediately and applies lists once downloaded,
  rather than refusing queries after every reboot.
- **One shared Blocky module** imported by both hosts so blocking doesn't
  differ depending on which answers (ties into the README's "shared modules"
  TODO).

## 3. Floating IP with keepalived (option C)

### Concept

A **floating (virtual) IP** belongs to no machine; whichever is healthy holds
it. Devices only know e.g. `192.168.0.4`.

1. Both hosts run **keepalived** (VRRP) and exchange heartbeats ~1/s.
2. The **MASTER** adds `192.168.0.4` as an extra address on its interface and
   answers ARP for it; the **BACKUP** listens.
3. If heartbeats stop (~3 s), the BACKUP takes the address and sends a
   **gratuitous ARP** ("`.4` is now at my MAC"); devices update their ARP cache.
4. A **health-check script** (e.g. "does Blocky answer?") makes a host give up
   the address when the _service_ is broken even if the machine is up.

Hosts keep their own addresses (`.3`, `.2`) for SSH etc. With this, the
README's plan to move the ThinkCentre to `.2` at cutover is unnecessary.

### Layout

|             | ThinkCentre            | Pi                                      |
| ----------- | ---------------------- | --------------------------------------- |
| Own address | `192.168.0.3` (`eno2`) | `192.168.0.2` (`wlan0`, WiFi)           |
| Role        | MASTER, priority 150   | BACKUP, priority 100                    |
| Holds `.4`  | normally               | when the ThinkCentre/its Blocky is down |

Router DHCP: DNS 1 = `192.168.0.4`; optionally DNS 2 = `1.1.1.1` (leaks, see
§2). Pick a virtual address outside the router's DHCP pool (TP-Link often
`.100–.199`) and confirm it's unused (`ping` gets no reply).

### Config sketch

Verify option names against the nixpkgs version in use.

```nix
# ThinkCentre side. The Pi: state = "BACKUP", priority = 100,
# interface = "wlan0", unicastPeers = [ "192.168.0.3" ].
{ pkgs, ... }:
{
  services.keepalived = {
    enable = true;
    openFirewall = true; # VRRP (IP protocol 112)

    vrrpScripts.blocky = {
      script = "${pkgs.dig}/bin/dig +time=1 +tries=1 @127.0.0.1 example.com";
      interval = 2;
      fall = 2;
      rise = 2;
    };

    vrrpInstances.dns = {
      interface = "eno2";
      state = "MASTER";
      priority = 150;
      virtualRouterId = 53; # 1–255, same on both hosts
      virtualIps = [{ addr = "192.168.0.4/24"; }];
      unicastPeers = [ "192.168.0.2" ];
      trackScripts = [ "blocky" ];
    };
  };
}
```

### Gotchas

- **Pi on WiFi**: APs often mangle multicast, hence `unicastPeers`. Gratuitous
  ARP over WiFi works but failover may be slower; a wired Pi would be more
  reliable.
- **Split brain**: if the hosts can't hear each other (WiFi, firewall), both
  claim `.4` and devices flap between them. Mostly harmless with identical
  Blockys, confusing to debug — `journalctl -u keepalived` on both.
- **Blocky must answer on `.4`**: it listens on all addresses, so it should;
  verify with `dig @192.168.0.4 example.com` from another machine after a
  failover.
- **Fail-back**: the higher-priority ThinkCentre reclaims `.4` on recovery
  (another short blip); `nopreempt` keeps it on the Pi until moved by hand.

### Failover drill

1. `ip addr show eno2` on the ThinkCentre shows `192.168.0.4`.
2. From a laptop, loop `dig @192.168.0.4 doubleclick.net`.
3. `sudo systemctl stop blocky` on the ThinkCentre → `.4` appears on the Pi's
   `wlan0` within seconds; the loop keeps answering after a brief gap.
4. Start Blocky again; watch `.4` move back.

## Suggested order

1. Shared Blocky module for both hosts; add a second upstream.
2. Router DHCP: DNS 1 = ThinkCentre, DNS 2 = Pi (option B). Verify per device;
   chase IPv6/hardcoded-DNS leaks.
3. Later: keepalived floating IP (option C) and the failover drill.
4. If a router upgrade happens: OpenWrt for port-53 redirect and strict-order
   fallback (option D).
