{ ... }:

# Hermes Agent (Nous Research) as a self-hosted, deliberately scoped-down ops
# helper for the Pi. The upstream NixOS module is imported in ../../default.nix;
# this file is ONLY the configuration.
#
# Threat model / design (why it looks the way it does):
#   - The agent is an LLM that can call tools. The real risk is not the systemd
#     sandbox but what the tools let it *do* — a shell tool = arbitrary code as
#     the `hermes` user, and an untrusted inbound channel = prompt-injection →
#     command execution. So we scope on three axes:
#       1. Toolset allowlist       — the agent only gets `terminal` + `memory`,
#                                     never `["all"]`, no browser/web/computer_use.
#       2. OS-level privilege       — the unprivileged `hermes` user can restart
#                                     ONLY an explicit list of units (polkit
#                                     rule below). THIS is the hard boundary on
#                                     what a compromised/injected agent can
#                                     mutate; the Hermes approval layer is
#                                     defense-in-depth on top.
#       3. No untrusted inbound     — reachable only via the bearer-authed API
#                                     server over Tailscale (no messaging bots),
#                                     so the only party talking to it is us.
#   - Native systemd hardening (ProtectSystem=strict, NoNewPrivileges,
#     PrivateTmp) comes from the upstream module and bounds blast radius. We did
#     NOT use container mode: its value is sandboxing a freeform shell, and we
#     don't grant one — pulling Docker onto an aarch64 Pi 4 would be weight for
#     little gain. Upgrade path if freeform shell is ever wanted:
#     settings.terminal.backend = "docker" for just that tool.
#
# NOTE: hermes-agent is not in any binary cache, so the first `nixos-rebuild`
# builds it from source on the Pi (Python 3.12 closure). Watch for memory
# pressure; cross-build from home-desktop is the escape hatch. See pi-wip.md.

{
  services.hermes-agent = {
    enable = true;
    # user/group default to hermes:hermes; createUser defaults true. The polkit
    # rule below and the secrets path assume that user name.

    # Non-secret env for the `hermes gateway` process. The API server is enabled
    # via these env vars (not config.yaml). Bind 0.0.0.0 but DO NOT open 8642 on
    # the LAN firewall — tailscale0 is a trusted interface (see ../tailscale),
    # so only tailnet clients reach it. Same pattern transmission uses for 9091.
    # A bearer key is required regardless (API_SERVER_KEY, in the secrets file).
    environment = {
      API_SERVER_ENABLED = "true";
      API_SERVER_HOST = "0.0.0.0";
      API_SERVER_PORT = "8642";
      # We manage this deployment via Nix, so lock out the CLI mutation commands
      # (`hermes setup`, `hermes config edit`, `hermes gateway install/uninstall`)
      # that would let state drift from what's declared here. (This guards those
      # subcommands — it is NOT a root-execution guard.)
      HERMES_MANAGED = "true";
    };

    # Secrets live OUTSIDE the repo/store (see the secrets TODO in pi-wip.md for
    # the eventual sops/agenix path). Place this file on the Pi by hand:
    #     sudo install -o hermes -g hermes -m 600 /dev/stdin /var/lib/hermes/secrets.env <<'EOF'
    #     ANTHROPIC_API_KEY=sk-ant-...
    #     API_SERVER_KEY=<long-random-string>
    #     EOF
    # (API_SERVER_KEY is the bearer token clients present; generate with
    #  `openssl rand -hex 32`.)
    environmentFiles = [ "/var/lib/hermes/secrets.env" ];

    settings = {
      # VERIFY on first deploy that Hermes accepts this exact model slug for the
      # ANTHROPIC_API_KEY provider (`hermes models` / config validation). Sonnet
      # is the sensible cost/latency pick for an ops helper; bump to opus if you
      # want more reasoning.
      model.default = "anthropic/claude-sonnet-4-6";

      # Allowlist of toolsets — NOT "all". Confirmed against hermes_cli/dump.py:
      # top-level `toolsets` is load-bearing (default ["hermes-cli"]), so this
      # replaces the default set rather than adding to it. `terminal` is how the
      # agent reaches the Pi's own services (curl localhost:9090 Prometheus,
      # journalctl, systemctl status/restart) — a localhost path that sidesteps
      # the SSRF block below. `memory` gives session continuity. Everything else
      # (browser, web, computer_use, code_execution, file) stays OFF to keep the
      # exfiltration/injection surface minimal.
      # VERIFY on first deploy: the API server may need a platform toolset in
      # this list to emit responses (default was "hermes-cli"). If replies don't
      # come back, add the platform toolset the gateway expects (e.g.
      # "hermes-cli" / "hermes-acp") — a functionality fix, not a security one.
      toolsets = [ "terminal" "memory" ];

      agent = {
        max_turns = 40;
      };

      terminal = {
        backend = "local"; # agent already sandboxed by the module's systemd hardening
        cwd = "/var/lib/hermes/workspace"; # working-dir allowlist for the tool
      };

      approvals = {
        # Gate mutating commands behind an explicit approval. Since the only
        # caller is us (bearer-authed, Tailscale-only) and there's no web/
        # messaging injection path, this is primarily a safety net.
        # Enum confirmed from tools/approval.py: manual | smart | off. "manual"
        # prompts before dangerous commands; an unknown/absent value fails
        # closed to "manual", so this is the safe, gating choice.
        mode = "manual";

        # Hard denylist (fnmatch, case-insensitive, whole command). These fire
        # BEFORE any yolo / mode=off bypass — a true floor, on top of Hermes'
        # built-in hardline blocklist. Patterns are deliberately shaped to avoid
        # false positives on the agent's own read-only curls (e.g. NOT
        # "*curl*sh*", which would match "curl .../dashboard").
        deny = [
          "*sudo *" # privileged actions go via the polkit rule, never generic sudo
          "* | sh*" # pipe-to-shell (curl … | sh remote-exec shape)
          "* | bash*"
          "*rm -rf /*"
          "*mkfs*"
          "*dd if=* of=/dev/*"
          "* > /etc/*" # writing system config
          "*chmod -R 777*"
        ];
      };

      security = {
        # Keep the always-on SSRF protection ON (default). This blocks the web/
        # browser tools from reaching RFC-1918 / localhost — which is exactly
        # why observability goes through the `terminal` tool (localhost curl),
        # NOT by loosening this. Do NOT flip to true.
        allow_private_urls = false;
      };
    };
  };

  # ── The actual mutation boundary ─────────────────────────────────────────
  # The unprivileged `hermes` user cannot restart system units on its own; this
  # polkit rule grants that right for an EXPLICIT, EDITABLE list of units and
  # verbs only. This — not the toolset/approval config — is what bounds a
  # prompt-injected agent's blast radius. NEVER widen this to blanket
  # manage-units. Add a unit here only when you actually want the agent to be
  # able to bounce it.
  security.polkit.enable = true;
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (subject.user !== "hermes") { return polkit.Result.NOT_HANDLED; }
      if (action.id !== "org.freedesktop.systemd1.manage-units") { return polkit.Result.NOT_HANDLED; }

      var allowedUnits = [
        "jellyfin.service",
        "transmission.service",
        "home-assistant.service"
      ];
      var allowedVerbs = [ "restart", "try-restart", "reload-or-restart" ];

      var unit = action.lookup("unit");
      var verb = action.lookup("verb");
      if (allowedUnits.indexOf(unit) !== -1 && allowedVerbs.indexOf(verb) !== -1) {
        return polkit.Result.YES;
      }
      return polkit.Result.NOT_HANDLED;
    });
  '';

  # No firewall ports opened: the API server on 8642 is reached over Tailscale
  # (trusted interface), never the LAN. The admin `hermes dashboard` is NOT run
  # as a service — reach it, when needed, by SSH-tunnelling to loopback over the
  # tailnet, so its config/key/gateway-control authority is never network-bound.
}
