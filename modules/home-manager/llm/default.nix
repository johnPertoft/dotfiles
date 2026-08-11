{ pkgs
, lib
, config
, llm-agents
, self
, ...
}:
let
  # Bleeding-edge agent CLIs from numtide/llm-agents.nix (rebuilt daily,
  # prebuilt in cache.numtide.com). Sourcing here so claude-code et al
  # don't lag behind their upstream releases like nixpkgs stable does.
  agents = llm-agents.packages.${pkgs.stdenv.system};

  # Auto-discover skills: every subdirectory of ./skills becomes a skill
  # entry. Drop a new <skill-name>/SKILL.md in there and it loads next
  # switch — no edits to this file needed. Per-home modules can merge
  # additional skills into the same option using the attrset form.
  discoverSkills = dir:
    lib.mapAttrs (name: _: dir + "/${name}")
      (lib.filterAttrs (_: v: v == "directory") (builtins.readDir dir));

  # Merge shared Nix settings with any host-specific extras contributed via
  # myDotfiles.claudeSettingsExtra, then generate a store-path JSON for the
  # activation script to merge into the live ~/.claude/settings.json.
  nixSettingsFile =
    (pkgs.formats.json { }).generate "claude-settings.json"
      (lib.recursiveUpdate config.programs.claude-code.settings
        config.programs.claude-code.extraSettings);
in
{
  options.programs.claude-code.extraSettings = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
    description = ''
      Host-specific Claude Code settings merged on top of the shared
      programs.claude-code.settings during activation. Use this for settings
      that should not apply to every host (e.g. work-specific marketplaces).
    '';
  };

  config = {
    home.packages = [
      # Local inference runtime (llama-cli, llama-server, ...). From nixpkgs
      # rather than the llm-agents flake, which only ships agent CLIs.
      pkgs.llama-cpp

      # pi (earendil-works/pi): terminal coding agent with multi-model
      # support. Installed as a bare package — unlike claude-code/codex/
      # antigravity-cli below, home-manager 26.05 ships no `programs.pi`
      # module, so it can't opt into the shared MCP servers via
      # enableMcpIntegration. Configure MCP for it manually if needed.
      agents.pi

      # ai: one-shot terminal prompt wrapping `claude -p` (reuses its login,
      # MCP off, terse output). Lives here alongside the agent CLIs it shells out to.
      self.packages.${pkgs.stdenv.hostPlatform.system}.ai
    ];

    # Shared MCP servers, defined once and fanned out to every client below
    # via enableMcpIntegration. Each module transforms the generic schema
    # into its native config format. Per-tool overrides remain possible
    # through `programs.<tool>.mcpServers` / `.settings.mcp_servers`, which
    # take precedence over these shared definitions.
    programs.mcp = {
      enable = true;
      servers = {
        # Skip a flaky test that asserts "Error" is not a substring of a
        # randomly-picked /nix/store text file — fails when the picked
        # file legitimately contains the word. Fixed upstream in
        # utensils/mcp-nixos#154 but not yet in nixpkgs' 2.4.3 pin.
        nixos.command = lib.getExe (pkgs.mcp-nixos.overridePythonAttrs (old: {
          disabledTests = (old.disabledTests or [ ]) ++ [ "test_read_text_file" ];
        }));
        context7.command = lib.getExe pkgs.context7-mcp;
      };
    };

    programs.claude-code = {
      enable = true;
      package = agents.claude-code;

      enableMcpIntegration = true;

      # Nix-managed settings. programs.claude-code.settings is used here for
      # its type (JSON-serialisable attrset) and to keep the intent clear.
      # The symlink it would normally generate is suppressed below — the
      # activation script merges into a mutable file instead.
      #
      # Deliberately excluded (written by Claude Code's own /theme and /plugin
      # UI commands — including them would silently revert user changes):
      #   theme, enabledPlugins
      settings = {
        permissions.defaultMode = "auto";
        skipAutoPermissionPrompt = true;
        autoUpdatesChannel = "stable";
        voice = {
          enabled = true;
          mode = "hold";
        };
        statusLine = {
          type = "command";
          command = ''input=$(cat); dir=$(echo "$input" | jq -r '.workspace.current_dir'); display="''${dir/$HOME/~}"; display=$(echo "$display" | awk -F'/' '{parts=0; for(i=1;i<=NF;i++) if($i!="") parts++; if(parts>3){p=""; c=0; for(i=NF;i>=1;i--) if($i!=""){p="/"$i p; if(++c==3)break}; print "..."p} else print $0}'); branch=$(git --no-optional-locks -C "$dir" symbolic-ref --short HEAD 2>/dev/null); dirty=""; git --no-optional-locks -C "$dir" status --porcelain 2>/dev/null | grep -q . && dirty="!"; model=$(echo "$input" | jq -r '.model.display_name'); used=$(echo "$input" | jq -r '.context_window.used_percentage // empty'); [ -n "$used" ] && printf "\033[1;33m[ctx:%.0f%%]\033[0m " "$used"; printf "\033[1;37m[%s]\033[0m " "$model"; printf "\033[1;36m[%s]\033[0m " "$display"; [ -n "$branch" ] && printf "\033[1;35m[%s%s]\033[0m" "$branch" "$dirty"'';
        };
      };

      # TODO: codex and antigravity-cli also expose a `skills` option with
      # the same shape. Not sharing yet because skills often encode
      # agent-specific assumptions (e.g. "use the Plan tool") that don't
      # translate across CLIs. Revisit once there are real skills to
      # classify — options for sharing later:
      #   - Manual opt-in: list specific skill paths per client.
      #   - Split dir: ./skills/shared/ vs ./skills/claude-only/.
      skills = discoverSkills ./skills;
    };

    # Suppress the read-only symlink that programs.claude-code.settings would
    # normally generate — the activation script below writes a mutable copy
    # instead, so Claude Code can write back to it (e.g. /theme, permissions).
    home.file."${config.programs.claude-code.configDir}/settings.json".enable =
      lib.mkForce false;

    # Merge Nix-managed settings into ~/.claude/settings.json on each switch.
    # nixSettingsFile is the combined shared + host-specific settings baked
    # into the store at eval time. jq's recursive * operator applies it with
    # Nix as the right operand — Nix wins on conflicts, keys absent from Nix
    # (e.g. theme) survive untouched. Arrays/scalars are replaced wholesale.
    home.activation.mergeClaudeSettings =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        settings="${config.home.homeDirectory}/.claude/settings.json"

        if [ -f "$settings" ] && [ ! -L "$settings" ]; then
          overwritten=$(${lib.getExe pkgs.jq} -sr '
            .[0] as $nix | .[1] as $live |
            [ $nix | to_entries[] |
              select($live[.key] != null and ($live[.key] | tojson) != (.value | tojson)) |
              "~ \(.key)\n-  \($live[.key] | tojson)\n+  \(.value | tojson)"
            ] | .[]
          ' "${nixSettingsFile}" "$settings")

          if [ -n "$overwritten" ]; then
            echo "claude settings.json: Nix overwrote:"
            echo "$overwritten"
          fi

          tmp="$settings.tmp"
          ${lib.getExe pkgs.jq} -s '.[1] * .[0]' "${nixSettingsFile}" "$settings" > "$tmp" \
            && $DRY_RUN_CMD mv "$tmp" "$settings" \
            || rm -f "$tmp"
        else
          $DRY_RUN_CMD rm -f "$settings"
          $DRY_RUN_CMD install -Dm 644 "${nixSettingsFile}" "$settings"
        fi
      '';

    programs.codex = {
      enable = true;
      package = agents.codex;

      enableMcpIntegration = true;
    };

    # gemini-cli was renamed upstream to antigravity-cli (Google rebrand).
    programs.antigravity-cli = {
      enable = true;
      package = agents.antigravity-cli;

      enableMcpIntegration = true;
    };
  };
}
