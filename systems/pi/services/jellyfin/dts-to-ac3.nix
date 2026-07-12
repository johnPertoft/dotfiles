{ pkgs, ... }:

let
  # Offline audio remux for the Jellyfin libraries.
  #
  # Why: the LG WebOS TV (and most TV clients) can't Direct Play DTS audio, so
  # Jellyfin falls back to a live audio-transcode + HLS remux for any DTS file.
  # That HLS path stutters over WiFi where the same file's video (copied, not
  # re-encoded) would stream fine on its own. The loki investigation showed DTS
  # 5.1 sources were the *only* thing being transcoded; AC3 sources Direct Play.
  #
  # So we convert the offending audio ahead of time instead of at stream time:
  # re-encode DTS tracks to AC3 (Dolby Digital, universally Direct-Play-able),
  # copying video, subtitles, chapters and any non-DTS audio verbatim. Audio-only
  # re-encode is cheap enough for the Pi to churn through in the background; the
  # video is never re-encoded (the Pi has no hardware encoder — see the missing
  # /dev/video* — so a video transcode would be a software crawl).
  #
  # Replacement is atomic: encode to a temp file in the same directory, then mv
  # over the original only after it verifies. An interrupted run leaves the
  # original untouched, and a file being streamed keeps its old inode open until
  # the player closes it, so a mid-play swap is safe.
  #
  # Already-AC3/AAC files are skipped for free — once converted they no longer
  # match, so re-running (and the hourly timer) is idempotent. Runnable by hand:
  #   jellyfin-dts-to-ac3 [root]      (default root: /srv/media)
  remux = pkgs.writeShellApplication {
    name = "jellyfin-dts-to-ac3";
    runtimeInputs = [ pkgs.ffmpeg-headless pkgs.findutils pkgs.coreutils ];
    text = ''
      root=''${1:-/srv/media}

      find "$root" -type f \
        \( -iname '*.mkv' -o -iname '*.mp4' -o -iname '*.m4v' \
           -o -iname '*.mov' -o -iname '*.ts' \) \
        ! -iname '*.dts2ac3-tmp.*' -print0 |
      while IFS= read -r -d "" f; do
        # Codec of each audio stream, in stream order (e.g. "dts", "aac").
        mapfile -t acodecs < <(
          ffprobe -v error -select_streams a \
            -show_entries stream=codec_name -of csv=p=0 "$f" || true)

        # Nothing to do unless at least one audio stream is DTS.
        case " ''${acodecs[*]} " in
          *" dts "*) : ;;
          *) continue ;;
        esac

        # Re-encode only the DTS streams to AC3; copy every other audio stream.
        codecargs=()
        i=0
        for c in "''${acodecs[@]}"; do
          if [ "$c" = dts ]; then
            codecargs+=( "-c:a:$i" ac3 "-b:a:$i" 640k )
          else
            codecargs+=( "-c:a:$i" copy )
          fi
          i=$((i + 1))
        done

        tmp="''${f%.*}.dts2ac3-tmp.''${f##*.}"
        echo "dts-to-ac3: converting DTS -> AC3 in $f"

        # -map 0 keeps every stream (video, all audio, subs, attachments,
        # chapters); -c copy is the baseline, codecargs override only audio.
        # A 7.1 (8-channel) DTS track exceeds AC3's 6-channel ceiling and will
        # fail the encode below — the original is then left intact, not
        # corrupted (it just gets logged and skipped).
        if ffmpeg -nostdin -y -i "$f" \
             -map 0 -map_metadata 0 -map_chapters 0 \
             -c copy "''${codecargs[@]}" \
             -max_muxing_queue_size 4096 \
             "$tmp" </dev/null; then
          # Guard against a truncated output before clobbering the original.
          # Output is ~input size (video copied, only audio shrinks), so half
          # the input size is a safe floor.
          insize=$(stat -c%s "$f")
          outsize=$(stat -c%s "$tmp")
          if [ "$outsize" -gt $((insize / 2)) ]; then
            chown pi:media "$tmp"
            chmod 0664 "$tmp"
            mv -f "$tmp" "$f"
            echo "dts-to-ac3: done $f"
          else
            echo "dts-to-ac3: output too small, keeping original: $f" >&2
            rm -f "$tmp"
          fi
        else
          echo "dts-to-ac3: ffmpeg failed, keeping original: $f" >&2
          rm -f "$tmp"
        fi
      done
    '';
  };
in
{
  # Background remux pass. Runs as root so it can restore pi:media ownership on
  # the rewritten files, and at the lowest CPU/IO priority so it never competes
  # with live playback. A full-library ffprobe scan each run is cheap (header
  # only); the actual encode only touches DTS files, which shrinks to zero once
  # the backlog is cleared.
  systemd.services.jellyfin-dts-to-ac3 = {
    description = "Remux DTS audio to AC3 in Jellyfin libraries (offline)";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${remux}/bin/jellyfin-dts-to-ac3 /srv/media";
      Nice = 19;
      IOSchedulingClass = "idle";
      CPUSchedulingPolicy = "idle";
      ProtectSystem = "strict";
      ReadWritePaths = [ "/srv/media" ];
      PrivateTmp = true;
    };
  };

  systemd.timers.jellyfin-dts-to-ac3 = {
    description = "Periodically remux DTS audio to AC3 in Jellyfin libraries";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
      RandomizedDelaySec = "5m";
    };
  };
}
