{ pkgs
, ...
}:
{
  programs.yt-dlp.enable = true;

  home.packages = with pkgs; [
    ffmpeg-full
    lame
    opus-tools
    rubberband
    sox
    timidity
    vorbis-tools
  ];
}
