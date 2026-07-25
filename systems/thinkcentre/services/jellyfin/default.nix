{ pkgs, ... }:

{
  # Media server. Runs as the `jellyfin` user; library data lives in
  # /var/lib/jellyfin and the transcode/cache in /var/cache/jellyfin.
  services.jellyfin.enable = true;

  # ── Intel hardware transcoding (iGPU: Intel UHD Graphics) ────────────────────
  # The whole point of this box. Nix's job is only to provide the
  # VAAPI/QSV drivers and give Jellyfin access to the render node — the actual
  # "enable HW acceleration" toggle is set at RUNTIME in Jellyfin's admin UI
  # (Dashboard → Playback → Transcoding → VA-API or QSV, device /dev/dri/renderD128).
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      # iHD VAAPI driver — covers Broadwell (2014) and newer Intel iGPUs, which
      # includes every "Intel UHD Graphics" part. This alone is enough for VAAPI
      # H.264/HEVC transcoding.
      intel-media-driver
      # oneVPL GPU runtime — enables Jellyfin's "Intel QuickSync (QSV)" path,
      # which is the recommended backend on Gen11+ (Ice Lake / UHD 6xx and newer).
      vpl-gpu-rt
      # OpenCL runtime — needed for GPU tone-mapping of HDR→SDR.
      intel-compute-runtime
    ];
  };

  # NOTE: the exact iGPU generation is unconfirmed until the box is here. On
  # first boot verify with `nix-shell -p pciutils --run 'lspci -nn | grep -i vga'`
  # and `nix-shell -p libva-utils --run vainfo` (should list H264/HEVC
  # VAProfiles against the iHD driver). If it turns out to be a pre-Broadwell
  # part (very unlikely for "UHD"), swap intel-media-driver → intel-vaapi-driver.

  # Declarative media layout. One folder per library type under /srv/media.
  # A `media` group lets `john` drop files here (e.g. over scp) while the
  # `jellyfin` service user reads them; the setgid bit (2775) makes new files
  # inherit the `media` group so Jellyfin can always read whatever lands here.
  users.groups.media = { };
  # render + video: access to /dev/dri/renderD128 for HW transcoding (the module
  # doesn't add these). media: read whatever lands in /srv/media.
  users.users.jellyfin.extraGroups = [ "render" "video" "media" ];
  users.users.john.extraGroups = [ "media" ];
  systemd.tmpfiles.rules = [
    "d /srv/media        2775 john media -"
    "d /srv/media/movies 2775 john media -"
    "d /srv/media/shows  2775 john media -"
    "d /srv/media/music  2775 john media -"
  ];

  # Web UI, reachable on the LAN and (trusted) over Tailscale. Client
  # auto-discovery ports (UDP 1900/7359) are intentionally left closed.
  networking.firewall.allowedTCPPorts = [ 8096 ];
}
