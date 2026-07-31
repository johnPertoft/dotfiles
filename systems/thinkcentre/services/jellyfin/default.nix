{ pkgs, ... }:

{
  # Media server. Runs as the `jellyfin` user; library data lives in
  # /var/lib/jellyfin and the transcode/cache in /var/cache/jellyfin.
  services.jellyfin.enable = true;

  # ── Intel hardware transcoding ───────────────────────────────────────────────
  # The whole point of this box. Nix's job is only to provide the drivers and
  # give Jellyfin access to the render node — the "enable HW acceleration"
  # toggle itself is set at RUNTIME in Jellyfin's admin UI (Dashboard → Playback
  # → Transcoding → VA-API, device /dev/dri/renderD128).
  #
  # The iGPU is an Intel UHD Graphics 630 (CometLake-S GT2, 8086:9bc8) — that is
  # **Gen9.5**, which is older than the marketing name suggests and rules out
  # two things:
  #
  #   * QSV does not work. oneVPL (vpl-gpu-rt) is Gen12/Xe-era and fails here
  #     with "Error initializing an MFX session: -3". QSV on Comet Lake would
  #     need the deprecated intel-media-sdk; not worth it, since VAAPI is the
  #     recommended path on pre-Gen12 Intel and is verified working (real
  #     h264_vaapi and hevc_vaapi encodes both succeed as the jellyfin user).
  #   * AV1 decode does not exist in this silicon. Expected, not a config gap.
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      # iHD VAAPI driver. Covers Broadwell and newer, so it handles this Gen9.5
      # part: H264 + HEVC Main/Main10 encode and decode, VP9/VP8/MPEG2/VC1
      # decode. This is the only driver Jellyfin actually needs here.
      intel-media-driver
      # OpenCL runtime — needed for GPU tone-mapping of HDR→SDR. This must be
      # the *legacy* build: plain `intel-compute-runtime` supports 12th Gen and
      # newer only, and on this GPU it registers an ICD that enumerates zero
      # devices, so tonemapping silently fails with
      # "Failed to get number of OpenCL platforms: -1001".
      intel-compute-runtime-legacy1
    ];
  };

  # Re-verify after changing anything above, as the jellyfin user (it is the one
  # that needs the access, and running as yourself can mask a group problem):
  #   sudo -u jellyfin nix-shell -p libva-utils --run vainfo
  #   sudo -u jellyfin ffmpeg -init_hw_device vaapi=va:/dev/dri/renderD128 \
  #     -filter_hw_device va -f lavfi -i testsrc=size=1280x720:rate=30 -t 2 \
  #     -vf format=nv12,hwupload -c:v h264_vaapi -f null -
  #   sudo -u jellyfin ffmpeg -init_hw_device opencl=ocl -f lavfi -i testsrc \
  #     -t 0.1 -f null -            # tonemapping availability
  # using jellyfin's own ffmpeg (/nix/store/*jellyfin-ffmpeg*-bin/bin/ffmpeg).

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
