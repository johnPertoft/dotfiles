{ pkgs
, coreutils
, ...
}:
pkgs.writeShellApplication {
  name = "ai";
  # coreutils for a deterministic fractional `sleep` (spinner) + `mktemp`.
  # `claude` (Claude Code) itself is NOT pinned: it resolves from the ambient
  # PATH — installed via the llm home module and carrying its own login, so we
  # deliberately use the same binary the user runs interactively rather than
  # pinning a second copy into this closure.
  runtimeInputs = [ coreutils ];
  text = builtins.readFile ./script.sh;
}
