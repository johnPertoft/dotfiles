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

    # MCP servers, rendered into a home-manager plugin and loaded via
    # --plugin-dir. Coexists with ~/.claude.json mcpServers (e.g. glean,
    # bigquery) — claude-code merges both at startup.
    mcpServers = {
      nixos = {
        type = "stdio";
        # Skip a flaky test that asserts "Error" is not a substring of a
        # randomly-picked /nix/store text file — fails when the picked
        # file legitimately contains the word. Fixed upstream in
        # utensils/mcp-nixos#154 but not yet in nixpkgs' 2.4.3 pin.
        command = lib.getExe (pkgs.mcp-nixos.overridePythonAttrs (old: {
          disabledTests = (old.disabledTests or [ ]) ++ [ "test_read_text_file" ];
        }));
      };
      context7 = {
        type = "stdio";
        command = lib.getExe pkgs.context7-mcp;
      };
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
