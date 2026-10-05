# codex-copilot: Codex running on a GitHub Copilot subscription.
#
#   - The copilot-api gateway (./copilot-api.nix) serves the OpenAI Responses
#     API from the Copilot subscription on 127.0.0.1:4141.
#   - `codex-copilot` runs the same Nix-installed Codex as `codex` with
#     CODEX_HOME=~/.codex-copilot. That home has its own config.toml: the
#     shared Codex config (including the shared MCP servers) plus the gateway
#     provider below. Its own sessions, history and auth live there too.
#   - Plain `codex` and ~/.codex are left untouched.
#
# Setup, once per machine:
#   1. Set programs.codex-copilot.enable = true and switch.
#   2. Log in to Copilot and check the gateway; see ./copilot-api.nix.
#   3. Run `codex-copilot`, then `/status`: the provider should be
#      copilot_api. Pick a model with `/model`; the list comes from the
#      gateway. Don't sign in to ChatGPT in this home.
#   4. Check auto review: ask it to run `/usr/bin/printf GUARDIAN_TEST_OK`
#      with sandbox escalation (sandbox_permissions=require_escalated). It
#      should be approved by the reviewer without asking you. If it errors
#      instead, check the mapping in ~/.local/share/copilot-api/config.json.
#
# Skills are shared: ~/.codex-copilot/skills links to ~/.codex/skills.
{ pkgs
, lib
, config
, ...
}:
let
  cfg = config.programs.codex-copilot;
  codexCfg = config.programs.codex;
  home = config.home.homeDirectory;

  copilotHome = "${home}/.codex-copilot";
  gatewayUrl = config.programs.copilot-api.url;
  catalog = "${copilotHome}/model_catalog.json";

  inherit (import ./mutable-merge.nix { inherit pkgs lib; })
    mkMutableMerge yqTomlMerge;

  # Gateway provider settings, from copilot-api's Codex guide.
  overlay = (pkgs.formats.toml { }).generate "codex-copilot-overlay.toml" {
    model_provider = "copilot_api";
    # Let a model review escalation requests ("Approve for me") instead of
    # asking every time, like auto mode in claude-copilot. Codex asks for
    # `codex-auto-review`, which Copilot doesn't serve over Responses; the
    # gateway maps it below.
    approvals_reviewer = "auto_review";
    # Codex's default (cached) search mode never reaches a real search
    # through the gateway; live mode does, using the native web.run tool.
    web_search = "live";
    features.standalone_web_search = true;
    # standalone_web_search is marked under development; skip the warning
    # Codex prints for it on every start.
    suppress_unstable_features_warning = true;
    # Usage analytics would go to OpenAI, which this home doesn't use.
    analytics.enabled = false;
    # Codex 0.156+ fails to use the model list it discovers from a custom
    # provider, so point it at a local catalog. The launcher refreshes it
    # from the gateway on every start.
    model_catalog_json = catalog;
    model_providers.copilot_api = {
      # copilot-api's guide says the name must be "OpenAI".
      name = "OpenAI";
      base_url = gatewayUrl;
      # The loopback gateway has no client key configured; the launcher
      # exports a placeholder.
      env_key = "GITHUB_COPILOT_API_KEY";
      # The guide sets this to true, but then the TUI shows the ChatGPT
      # sign-in screen in a fresh CODEX_HOME. With env_key set, the features
      # it would unlock are off anyway.
      requires_openai_auth = false;
      wire_api = "responses";
      supports_websockets = false;
      supports_standalone_web_search = true;
      request_max_retries = 3;
      stream_max_retries = 3;
      stream_idle_timeout_ms = 300000;
    };
  };

  # Shared Codex config (same as ~/.codex/config.toml gets, MCP servers
  # included) with the gateway settings on top. `model` is deliberately not
  # set: Nix wins on conflicts, so it would reset a /model choice on every
  # switch.
  settingsFile = pkgs.runCommand "codex-copilot-config.toml" { } ''
    ${yqTomlMerge} ${overlay} ${config.home.file.".codex/config.toml".source} > $out
  '';

  # The gateway shapes its /models response for Codex based on these
  # headers, as in copilot-api's catalog generator script.
  codexVersion = codexCfg.package.version;

  codex-copilot = pkgs.writeShellApplication {
    name = "codex-copilot";
    runtimeInputs = [ pkgs.curl pkgs.jq pkgs.coreutils ];
    text = ''
      export CODEX_HOME="${copilotHome}"
      export GITHUB_COPILOT_API_KEY=local-copilot-no-auth
      unset OPENAI_API_KEY OPENAI_BASE_URL CODEX_API_KEY

      # Refresh the model catalog. On failure keep the previous one, so Codex
      # still starts if the gateway is briefly down.
      mkdir -p "$CODEX_HOME"
      tmp=$(mktemp "$CODEX_HOME/.model_catalog.json.XXXXXX")
      if curl -fsS --max-time 10 -o "$tmp" \
        --user-agent "codex-tui/${codexVersion}" \
        --header "originator: codex-tui" --header "version: ${codexVersion}" \
        "${gatewayUrl}/models?client_version=${codexVersion}" 2>/dev/null &&
        jq -e '.models | length > 0' "$tmp" >/dev/null 2>&1; then
        mv -f "$tmp" "${catalog}"
      else
        rm -f "$tmp"
        echo "codex-copilot: copilot-api gateway not reachable at ${gatewayUrl}." >&2
        echo "  Not logged in yet? copilot-api auth login --provider copilot" >&2
      fi

      exec "${lib.getExe codexCfg.package}" "$@"
    '';
  };
in
{
  options.programs.codex-copilot.enable =
    lib.mkEnableOption "the codex-copilot launcher (and the copilot-api gateway it uses)";

  config = lib.mkIf cfg.enable {
    programs.copilot-api = {
      enable = true;
      # Model for the auto reviewer (approvals_reviewer above).
      modelMappings.codex-auto-review = lib.mkDefault "gpt-5.6-terra";
    };

    home.packages = [ codex-copilot ];

    # Mutable like ~/.codex/config.toml: Codex can write to it, and each
    # switch merges the Nix values back on top.
    home.activation.mergeCodexCopilotConfig = mkMutableMerge {
      label = "codex-copilot config.toml";
      nixFile = settingsFile;
      liveFile = "${copilotHome}/config.toml";
      mergeCmd = yqTomlMerge;
    };

    # One directory link: Nix-managed skills and ones added at runtime are
    # shared with the regular home.
    home.file.".codex-copilot/skills".source =
      config.lib.file.mkOutOfStoreSymlink "${home}/.codex/skills";
  };
}
