{ pkgs, lib }:
{
  # Returns a home.activation DAG entry that merges a Nix settings store-path
  # into a mutable live config file on each switch. Nix wins on conflicts;
  # keys absent from Nix survive untouched (e.g. theme, runtime state).
  #
  # mergeCmd and diffCmd are shell snippets invoked as: cmd <nix-file> <live-file>
  # In both, the right-hand side (nix) wins on conflicts.
  mkMutableMerge =
    { label       # shown in the diff header, e.g. "vscode settings.json"
    , nixFile     # store-path derivation of the Nix-managed settings
    , liveFile    # absolute path string to the live mutable config file
    , mergeCmd    # shell snippet: produces merged output on stdout
    , diffCmd ? null  # shell snippet: produces overwrite report on stdout
    }:
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      nix_src="${nixFile}"
      live="${liveFile}"

      if [ -f "$live" ] && [ ! -L "$live" ]; then
        ${lib.optionalString (diffCmd != null) ''
          overwritten=$(${diffCmd} "$nix_src" "$live")
          if [ -n "$overwritten" ]; then
            echo "${label}: Nix overwrote:"
            echo "$overwritten"
          fi
        ''}
        tmp="$live.tmp"
        ${mergeCmd} "$nix_src" "$live" > "$tmp" \
          && $DRY_RUN_CMD mv "$tmp" "$live" \
          || rm -f "$tmp"
      else
        $DRY_RUN_CMD rm -f "$live"
        $DRY_RUN_CMD install -Dm 644 "$nix_src" "$live"
      fi
    '';

  # jq-based merge and diff for JSON config files.
  # .[0] = nix (first arg), .[1] = live (second arg); right side wins in jq.
  jqMerge = "${lib.getExe pkgs.jq} -s '.[1] * .[0]'";
  jqDiff = ''${lib.getExe pkgs.jq} -sr '
    .[0] as $nix | .[1] as $live |
    [ $nix | to_entries[] |
      select($live[.key] != null and ($live[.key] | tojson) != (.value | tojson)) |
      "~ \(.key)\n-  \($live[.key] | tojson)\n+  \(.value | tojson)"
    ] | .[]
  ' '';

  # yq-based merge for TOML config files.
  # fi==0 = nix (first arg), fi==1 = live (second arg); right side (*) wins.
  yqTomlMerge = "${lib.getExe pkgs.yq-go} ea --input-format=toml --output-format=toml 'select(fi==1) * select(fi==0)'";
}
