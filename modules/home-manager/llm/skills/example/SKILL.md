---
name: example
description: Smoke-test skill loaded via nix from the shared dotfiles. If this shows up in Claude's skill list at startup, the auto-discovery in modules/home-manager/llm is working. Replace or delete once real shared skills exist.
---

# Example skill

This is a placeholder. It lives at `modules/home-manager/llm/skills/example/`
and is rendered into `~/.claude/skills/example/` by the `programs.claude-code.skills`
option in `modules/home-manager/llm/default.nix`.

It exists so we can confirm:

- `builtins.readDir` is picking up new directories under `skills/`
- Home-manager is linking them into `~/.claude/skills/`
- Claude Code is loading the skills at startup

If you're reading this in a future session, the pipeline works — feel free to
delete this directory.
