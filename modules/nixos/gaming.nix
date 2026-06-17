{ config, pkgs, ... }:
{
  # Steam, with GE-Proton available as a selectable compatibility tool.
  # Per-game Proton version and launch options are still chosen imperatively
  # in the Steam UI; this only makes GE-Proton show up in the dropdown.
  programs.steam = {
    enable = true;
    extraCompatPackages = with pkgs; [ proton-ge-bin ];
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  # 32-bit graphics drivers, needed by most Steam/Proton titles.
  hardware.graphics.enable32Bit = true;

  # On-demand performance optimisations; games launched with `gamemoderun`
  # (or via Steam launch option `gamemoderun %command%`) get the boost.
  programs.gamemode = {
    enable = true;
    enableRenice = true;
  };

  # Micro-compositor for upscaling/scaling and frame limiting. Launch games
  # with `gamescope -- %command%`; not wired up as a full session here.
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  # Imperative Proton-GE management, plus a few common gaming utilities.
  environment.systemPackages = with pkgs; [
    protonup-qt # download/manage extra Proton-GE builds
    mangohud # performance overlay
    lutris # non-Steam game launcher
  ];

  # TODO(follow-up): add fufexan/nix-gaming (platformOptimizations,
  # pipewire-low-latency) and consider declarative per-game Steam config.
}
