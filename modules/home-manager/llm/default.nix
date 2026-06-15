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
in
{
  programs.claude-code = {
    enable = true;
    package = agents.claude-code;

    # MCP servers shared across this Claude Code install. Add new servers
    # here; reference unpackaged binaries by absolute path until they're
    # wrapped as nix derivations.
    mcpServers = {
      # nixos.command = lib.getExe pkgs.mcp-nixos;
    };
  };

  programs.codex = {
    enable = true;
    package = agents.codex;
  };

  # gemini-cli was renamed upstream to antigravity-cli (Google rebrand).
  programs.antigravity-cli = {
    enable = true;
    package = agents.antigravity-cli;
  };
}
