{ pkgs
, lib
, config
, ...
}:
let
  # Same auto-discovery pattern as modules/home-manager/llm. Skills here
  # merge with the shared ones via attrset merging in nix's module system.
  discoverSkills =
    dir:
    lib.mapAttrs (name: _: dir + "/${name}") (
      lib.filterAttrs (_: v: v == "directory") (builtins.readDir dir)
    );

  # Claude Code settings managed by Nix. On each switch these are deep-merged
  # into ~/.claude/settings.json using jq's recursive * operator — Nix values
  # win on conflicts; keys absent from Nix survive untouched.
  #
  # Deliberately excluded (written by Claude Code's own /theme and /plugin
  # UI commands — putting them here would silently revert user changes on
  # every switch):
  #   theme, enabledPlugins
  claudeSettings = {
    permissions.defaultMode = "auto";
    skipAutoPermissionPrompt = true;
    autoUpdatesChannel = "stable";
    voice = {
      enabled = true;
      mode = "hold";
    };
    extraKnownMarketplaces = {
      ai-engineering-marketplace = {
        source = {
          source = "git";
          url = "git@github.int.midasplayer.com:ai-ml/ai-engineering-marketplace.git";
        };
      };
    };
    statusLine = {
      type = "command";
      command = ''input=$(cat); dir=$(echo "$input" | jq -r '.workspace.current_dir'); display="''${dir/$HOME/~}"; display=$(echo "$display" | awk -F'/' '{parts=0; for(i=1;i<=NF;i++) if($i!="") parts++; if(parts>3){p=""; c=0; for(i=NF;i>=1;i--) if($i!=""){p="/"$i p; if(++c==3)break}; print "..."p} else print $0}'); branch=$(git --no-optional-locks -C "$dir" symbolic-ref --short HEAD 2>/dev/null); dirty=""; git --no-optional-locks -C "$dir" status --porcelain 2>/dev/null | grep -q . && dirty="!"; model=$(echo "$input" | jq -r '.model.display_name'); used=$(echo "$input" | jq -r '.context_window.used_percentage // empty'); printf "\033[1;36m[%s]\033[0m " "$display"; [ -n "$branch" ] && printf "\033[1;35m[%s%s]\033[0m " "$branch" "$dirty"; printf "\033[1;37m[%s]\033[0m " "$model"; [ -n "$used" ] && printf "\033[1;33m[ctx:%.0f%%]\033[0m" "$used"'';
    };
  };

  claudeSettingsFile = pkgs.writeText "claude-settings-base.json" (builtins.toJSON claudeSettings);

  # TODO: re-enable once CI can evaluate this without a VPN. The
  # internal King marketplace lives behind github.int.midasplayer.com,
  # which isn't reachable from the public GitHub Actions runner that
  # runs `nix flake check` / `nix flake show` on every push. Possible
  # paths forward:
  #   - Gate the fetch on a CI env var (`builtins.getEnv "CI"`) and
  #     pass `--impure` from the workflow.
  #   - Scope CI to outputs that don't need VPN and lose check coverage
  #     for the work home.
  #   - Keep the King marketplace mutable (interactive
  #     `/plugin marketplace add`) and only nix-manage public stuff.
  #
  # ai-engineering-marketplace = builtins.fetchGit {
  #   url = "ssh://git@github.int.midasplayer.com/ai-ml/ai-engineering-marketplace.git";
  #   ref = "main";
  #   rev = "b1894daa569ea1b2cf0613393e3bafa6575d6834";
  # };
in
{
  programs.claude-code = {
    skills = discoverSkills ./skills;

    # marketplaces.ai-engineering = ai-engineering-marketplace;
    # plugins = [
    #   "${ai-engineering-marketplace}/plugins/git-worktree-create"
    # ];
  };

  # Merge Nix-managed settings into ~/.claude/settings.json on each switch.
  # jq's recursive * operator is used with Nix as the right operand so Nix
  # wins on key conflicts; keys only present in the live file survive untouched.
  # Arrays and scalars are replaced wholesale (not appended) when Nix defines them.
  home.activation.mergeClaudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="${config.home.homeDirectory}/.claude/settings.json"

    if [ -f "$settings" ] && [ ! -L "$settings" ]; then
      tmp="$settings.tmp"
      ${lib.getExe pkgs.jq} -s '.[1] * .[0]' "${claudeSettingsFile}" "$settings" > "$tmp" \
        && $DRY_RUN_CMD mv "$tmp" "$settings" \
        || rm -f "$tmp"
    else
      $DRY_RUN_CMD rm -f "$settings"
      $DRY_RUN_CMD install -Dm 644 "${claudeSettingsFile}" "$settings"
    fi
  '';
}
