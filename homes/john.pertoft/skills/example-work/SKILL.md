---
name: example-work
description: Smoke-test skill loaded only on the work laptop via homes/john.pertoft/llm.nix. If you see this listed alongside the `example` skill, host-scoping is wired correctly. Should NOT appear on the personal or desktop homes.
---

# Work-only example skill

Lives at `homes/john.pertoft/skills/example-work/`, rendered into
`~/.claude/skills/example-work/` only when the `john.pertoft` home is active.

It exists to confirm that:

- Per-home skills auto-discovery works (same pattern as the shared one)
- `programs.claude-code.skills` from the shared and per-home modules merge
  correctly rather than overwriting each other

If both `example` and `example-work` appear in Claude's skill list, the
setup is correct. Replace with real work-only skills as needed.
