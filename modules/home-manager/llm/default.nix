{ pkgs
, lib
, llm-agents
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
in
{
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
  };

  # gemini-cli was renamed upstream to antigravity-cli (Google rebrand).
  programs.antigravity-cli = {
    enable = true;
    package = agents.antigravity-cli;

    enableMcpIntegration = true;
  };
}
