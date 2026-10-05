# copilot-api gateway: serves a GitHub Copilot subscription as Anthropic
# Messages and OpenAI Responses APIs on loopback. Shared by claude-copilot.nix
# and codex-copilot.nix, which enable it; not meant to be enabled on its own.
#
# Setup, once per machine:
#   1. Switch with claude-copilot and/or codex-copilot enabled. The switch
#      starts the gateway service, which waits until step 2 is done.
#   2. Log in to Copilot (GitHub device flow; writes the token to
#      ~/.local/share/copilot-api/github_token):
#        copilot-api auth login --provider copilot
#      The gateway starts by itself within a few seconds.
#      Logs: ~/Library/Logs/copilot-api.log (macOS) or
#      `journalctl --user -u copilot-api` (Linux).
#   3. Check it is serving models:
#        curl -s http://127.0.0.1:4141/v1/models | jq -r '.data[].id'
#
# The gateway's own settings live in ~/.local/share/copilot-api/config.json.
# copilot-api writes to that file itself; Nix only merges `modelMappings`
# into it, each time the service starts.
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
  cfg = config.programs.copilot-api;
  home = config.home.homeDirectory;

  # Under a service manager there is no TTY. Without a token, `start` falls
  # into interactive provider setup and fails, and `ensurePaths` has already
  # created an empty github_token. So wait for a non-empty token first: the
  # service started on switch then comes up by itself after the first login.
  #
  # The gateway reads config.json only at startup, so modelMappings are merged
  # in here. Changing them changes this script, and with it the service
  # definition, so home-manager restarts the service on switch.
  gateway = pkgs.writeShellScript "copilot-api-service" ''
    dir="${home}/.local/share/copilot-api"
    token="$dir/github_token"
    if [ ! -s "$token" ]; then
      echo "copilot-api: waiting for login: copilot-api auth login --provider copilot" >&2
      while [ ! -s "$token" ]; do ${pkgs.coreutils}/bin/sleep 5; done
    fi
    ${lib.optionalString (cfg.modelMappings != { }) ''
      # Nix wins for the mappings it sets; other mappings are kept. The gateway
      # leaves an empty config.json until its first full start.
      umask 077
      conf="$dir/config.json"
      [ -s "$conf" ] || echo '{}' > "$conf"
      ${lib.getExe pkgs.jq} --argjson m ${lib.escapeShellArg (builtins.toJSON cfg.modelMappings)} \
        '.modelMappings = ((.modelMappings // {}) + $m)' "$conf" > "$conf.tmp" \
        && mv "$conf.tmp" "$conf" \
        || { rm -f "$conf.tmp"; echo "copilot-api: could not merge modelMappings into $conf" >&2; }
    ''}
    exec ${lib.getExe cfg.package} start --host 127.0.0.1 --port ${toString cfg.port}
  '';
in
{
  options.programs.copilot-api = {
    enable = lib.mkEnableOption "the copilot-api gateway user service";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.copilot-api;
      defaultText = lib.literalExpression "self.packages.\${system}.copilot-api";
      description = "The copilot-api package.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 4141;
      description = "Loopback port for the copilot-api gateway.";
    };

    modelMappings = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = { codex-auto-review = "gpt-5.6-terra"; };
      description = "Requested model ID to the model the gateway actually calls.";
    };

    url = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "http://127.0.0.1:${toString cfg.port}";
      description = "Base URL of the gateway, for the clients that use it.";
    };
  };

  config = lib.mkIf cfg.enable {
    # On PATH for the one-off `copilot-api auth login` and `debug`.
    home.packages = [ cfg.package ];

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
      Unit.Description = "copilot-api gateway for claude-copilot and codex-copilot";
      Service = {
        ExecStart = "${gateway}";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
