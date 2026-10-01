# claude-copilot: Claude Code running on a GitHub Copilot subscription.
#
#   - copilot-api (caozhiyuan fork, packages/copilot-api) runs as a user
#     service on 127.0.0.1:4141. It logs in to Copilot with its own GitHub
#     device flow and serves the Anthropic Messages API from the Copilot
#     subscription.
#   - `claude-copilot` runs the same Nix-installed Claude Code as `claude`
#     (programs.claude-code.finalPackage, so the shared MCP servers come
#     along) with CLAUDE_CONFIG_DIR=~/.claude-copilot. That home has its own
#     settings.json: the shared Claude settings plus the gateway settings
#     below. Its own sessions, history and plugins live there too.
#   - Plain `claude` and ~/.claude are left untouched.
#
# Setup, once per machine:
#   1. Set programs.claude-copilot.enable = true and switch. The switch
#      starts the gateway service, which waits until step 2 is done.
#   2. Log in to Copilot (GitHub device flow; writes the token to
#      ~/.local/share/copilot-api/github_token):
#        copilot-api auth login --provider copilot
#      The gateway starts by itself within a few seconds.
#      Logs: ~/Library/Logs/copilot-api.log (macOS) or
#      `journalctl --user -u copilot-api` (Linux).
#   3. Check that the model IDs in `models` below are still served:
#        curl -s http://127.0.0.1:4141/v1/models | jq -r '.data[].id' | grep claude
#   4. Run `claude-copilot`, then `/status`: the Anthropic base URL should be
#      http://127.0.0.1:4141 and the auth source apiKeyHelper. Don't log in to
#      claude.ai in this home; that would bypass the gateway.
#
# Not carried over from ~/.claude: plugins installed with /plugin (for example
# glean-remote-mcp). Reinstall them from inside claude-copilot if wanted.
# Skills are shared: ~/.claude-copilot/skills links to ~/.claude/skills.
#
# Caveat: this is an unofficial route into Copilot's API. GitHub may restrict
# it, and the company Copilot seat's terms still apply.
{ pkgs
, lib
, config
, self
, ...
}:
let
  cfg = config.programs.claude-copilot;
  claudeCfg = config.programs.claude-code;
  home = config.home.homeDirectory;

  copilotHome = "${home}/.claude-copilot";
  gatewayUrl = "http://127.0.0.1:${toString cfg.port}";
  copilot-api = self.packages.${pkgs.stdenv.hostPlatform.system}.copilot-api;

  inherit (import ./mutable-merge.nix { inherit pkgs lib; })
    mkMutableMerge jqMerge jqDiff;

  # Shared Claude settings (same as ~/.claude/settings.json gets) plus the
  # gateway settings. `model` is deliberately not set: Nix wins
  # on conflicts, so it would reset a /model choice on every switch.
  settings = lib.recursiveUpdate
    (lib.recursiveUpdate claudeCfg.settings claudeCfg.extraSettings)
    {
      # Claude Code needs a credential to talk to a gateway. The loopback
      # gateway has no client key configured, so any placeholder works.
      apiKeyHelper = "echo local-copilot-no-auth";
      # Classify every shell command in auto mode, so shell allow rules can't
      # skip the classifier.
      autoMode.classifyAllShell = true;
      env = {
        ANTHROPIC_BASE_URL = gatewayUrl;
        # Explicit tier mappings, so a Claude Code upgrade can't move an
        # alias to a model Copilot doesn't serve.
        ANTHROPIC_DEFAULT_OPUS_MODEL = cfg.models.opus;
        ANTHROPIC_DEFAULT_SONNET_MODEL = cfg.models.sonnet;
        ANTHROPIC_DEFAULT_HAIKU_MODEL = cfg.models.haiku;
        ANTHROPIC_DEFAULT_FABLE_MODEL = cfg.models.fable;
        # Auto mode's permission classifier calls go through the gateway too,
        # instead of Anthropic's server-side classifier.
        CLAUDE_CODE_AUTO_MODE_SERVER = "0";
        # The gateway's recommended setting. Also turns off auto-updates
        # (Nix handles those) and feature-flag fetching, including Remote
        # Control.
        CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
        # List the gateway's models under "From gateway" in /model. Claude
        # Code only keeps the claude-* ones (e.g. Opus 4.8, Sonnet 5.5).
        CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY = "1";
      }
      # One extra /model entry for a non-Claude model. Other ones still work
      # by typing their ID: /model gpt-5.6-sol.
      // lib.optionalAttrs (cfg.customModel != null) (
        {
          ANTHROPIC_CUSTOM_MODEL_OPTION = cfg.customModel.id;
        }
        // lib.optionalAttrs (cfg.customModel.name != null) {
          ANTHROPIC_CUSTOM_MODEL_OPTION_NAME = cfg.customModel.name;
        }
      );
    };
  settingsFile = (pkgs.formats.json { }).generate "claude-copilot-settings.json" settings;

  claude-copilot = pkgs.writeShellApplication {
    name = "claude-copilot";
    runtimeInputs = [ pkgs.curl ];
    text = ''
      export CLAUDE_CONFIG_DIR="${copilotHome}"

      # This home's settings.json supplies the gateway URL, credential and
      # models. Drop anything inherited that would override them.
      unset ANTHROPIC_BASE_URL ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN
      unset ANTHROPIC_MODEL ANTHROPIC_DEFAULT_MODEL ANTHROPIC_CUSTOM_HEADERS
      unset CLAUDE_CODE_OAUTH_TOKEN
      unset CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_VERTEX CLAUDE_CODE_USE_FOUNDRY
      unset CLAUDE_CODE_USE_ANTHROPIC_AWS CLAUDE_CODE_USE_MANTLE

      if ! curl -fsS -o /dev/null --max-time 2 "${gatewayUrl}/v1/models" 2>/dev/null; then
        echo "claude-copilot: copilot-api gateway not reachable at ${gatewayUrl}." >&2
        echo "  Not logged in yet? copilot-api auth login --provider copilot" >&2
      fi

      exec "${claudeCfg.finalPackage}/bin/claude" "$@"
    '';
  };

  # Under a service manager there is no TTY. Without a token, `start` falls
  # into interactive provider setup and fails, and `ensurePaths` has already
  # created an empty github_token. So wait for a non-empty token first: the
  # service started on switch then comes up by itself after the first login.
  gateway = pkgs.writeShellScript "copilot-api-service" ''
    token="${home}/.local/share/copilot-api/github_token"
    if [ ! -s "$token" ]; then
      echo "copilot-api: waiting for login: copilot-api auth login --provider copilot" >&2
      while [ ! -s "$token" ]; do ${pkgs.coreutils}/bin/sleep 5; done
    fi
    exec ${lib.getExe copilot-api} start --host 127.0.0.1 --port ${toString cfg.port}
  '';
in
{
  options.programs.claude-copilot = {
    enable = lib.mkEnableOption "the claude-copilot launcher and copilot-api gateway service";

    port = lib.mkOption {
      type = lib.types.port;
      default = 4141;
      description = "Loopback port for the copilot-api gateway.";
    };

    # Claude model IDs the gateway advertised on 2026-09-25.
    # Re-check with step 3 above when a tier stops working.
    models = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        opus = "claude-opus-5-5";
        sonnet = "claude-sonnet-5";
        haiku = "claude-haiku-4-5";
        fable = "claude-fable-5-1";
      };
      description = "Copilot model IDs for Claude Code's opus/sonnet/haiku/fable aliases.";
    };

    # Non-Claude models (GPT, Gemini, Grok) work through the gateway too, but
    # Claude Code doesn't know their context window and assumes the Claude
    # default for compaction.
    customModel = lib.mkOption {
      type = lib.types.nullOr (lib.types.submodule {
        options = {
          id = lib.mkOption {
            type = lib.types.str;
            description = "Gateway model ID, e.g. gpt-6.1-sol.";
          };
          name = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Display name in /model.";
          };
        };
      });
      default = null;
      description = "Extra non-Claude model to list in Claude Code's /model picker.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      claude-copilot
      # On PATH for the one-off `copilot-api auth login` and `debug`.
      copilot-api
    ];

    # Mutable like ~/.claude/settings.json: Claude Code can write to it, and
    # each switch merges the Nix values back on top.
    home.activation.mergeClaudeCopilotSettings = mkMutableMerge {
      label = "claude-copilot settings.json";
      nixFile = settingsFile;
      liveFile = "${copilotHome}/settings.json";
      mergeCmd = jqMerge;
      diffCmd = jqDiff;
    };

    # One directory link: Nix-managed skills, synced skills
    # and ones added at runtime are all shared with the regular home.
    home.file.".claude-copilot/skills".source =
      config.lib.file.mkOutOfStoreSymlink "${claudeCfg.configDir}/skills";

    launchd.agents.copilot-api = lib.mkIf pkgs.stdenv.isDarwin {
      enable = true;
      config = {
        ProgramArguments = [ "${gateway}" ];
        RunAtLoad = true;
        KeepAlive.SuccessfulExit = false;
        StandardOutPath = "${home}/Library/Logs/copilot-api.log";
        StandardErrorPath = "${home}/Library/Logs/copilot-api.log";
      };
    };

    systemd.user.services.copilot-api = lib.mkIf pkgs.stdenv.isLinux {
      Unit.Description = "copilot-api gateway for claude-copilot";
      Service = {
        ExecStart = "${gateway}";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
