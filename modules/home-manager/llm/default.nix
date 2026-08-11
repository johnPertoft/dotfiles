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

  # Returns a home.activation DAG entry that merges a Nix settings store-path
  # into a mutable live config file on each switch. Nix wins on conflicts;
  # keys absent from Nix survive untouched (e.g. theme, enabledPlugins).
  #
  # mergeCmd and diffCmd are shell snippets called as: cmd <nix-file> <live-file>
  # In both, the right-hand side (nix) wins on conflicts.
  mkMutableMerge =
    { label       # shown in the diff header, e.g. "claude settings.json"
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
  # `.` = nix (first arg), `input` = live (second arg); right side (*) wins.
  yqTomlMerge = "${lib.getExe pkgs.yq-go} eval-all --input-format=toml --output-format=toml 'input * .'";

  # Claude Code: merge shared settings + host-specific extraSettings into one JSON.
  claudeNixSettings =
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

    programs.codex = {
      enable = true;
      package = agents.codex;

      enableMcpIntegration = true;

      settings.approval_policy = "auto";
    };

    # gemini-cli was renamed upstream to antigravity-cli (Google rebrand).
    programs.antigravity-cli = {
      enable = true;
      package = agents.antigravity-cli;

      enableMcpIntegration = true;
    };

    # Suppress the read-only symlinks that the upstream modules would generate
    # from settings/MCP integration — the activation scripts below write
    # mutable copies instead, so tools can still write back to their configs.
    home.file."${config.programs.claude-code.configDir}/settings.json".enable =
      lib.mkForce false;
    home.file.".codex/config.toml".enable =
      lib.mkForce false;

    home.activation.mergeClaudeSettings = mkMutableMerge {
      label = "claude settings.json";
      nixFile = claudeNixSettings;
      liveFile = "${config.home.homeDirectory}/.claude/settings.json";
      mergeCmd = jqMerge;
      diffCmd = jqDiff;
    };

    home.activation.mergeCodexConfig = mkMutableMerge {
      label = "codex config.toml";
      nixFile = config.home.file.".codex/config.toml".source;
      liveFile = "${config.home.homeDirectory}/.codex/config.toml";
      mergeCmd = yqTomlMerge;
    };
  };
}
