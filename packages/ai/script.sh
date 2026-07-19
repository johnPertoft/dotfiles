#!/bin/sh
# ai — one-shot Claude prompt from the terminal.
#
# A thin wrapper around Claude Code's print mode (`claude -p`). Reuses whatever
# login `claude` already has (no API key needed), disables MCP servers for a
# fast pure-ask, and applies a terse system prompt so answers read well in a
# terminal. Combine with stdin to explain command output:
#
#   ai "how do I squash the last 3 commits"
#   git log --oneline -5 | ai "summarize what changed"
#
# For JSON you can pipe into jq, pass a JSON Schema with -s (Claude Code's
# --json-schema) — it constrains the reply to valid JSON. The schema must be an
# object at the top level:
#
#   ai -s '{"type":"object","properties":{"planets":{"type":"array"}}}' \
#      "list the planets" | jq .planets
#
# By default it cannot touch the filesystem (pure ask). Pass -x to let it read
# and run commands (grants Claude Code tool access + your home dir) for queries
# like "which files under ~ are largest": `ai -x "..."`.

set -eu

SYSTEM_PROMPT="You are a terse command-line assistant. Answer directly in plain \
text with no preamble and no sign-off. Be concise."

usage() {
	cat >&2 <<'EOF'
usage: ai [-m MODEL] [-s SCHEMA] [-x] [QUESTION...]
  Ask Claude a one-shot question. Reads extra context from stdin if piped.

  -m, --model MODEL   Model alias (haiku, sonnet, opus, fable) or full id.
                      Default: haiku.
  -s, --schema SCHEMA JSON Schema for guaranteed-valid JSON output (passed to
                      claude --json-schema). Must be a top-level object schema.
  -x, --exec          Allow Claude to read files and run commands (grants tool
                      access + your $HOME). Off by default (pure ask).
  -h, --help          Show this help.

examples:
  ai "how do I undo the last commit"
  cat error.log | ai "what is going wrong here"
  ai -s '{"type":"object","properties":{"planets":{"type":"array"}}}' \
     "list the planets" | jq .planets
  ai -x "which three files under my home dir are largest"
EOF
}

model="haiku"
prompt=""
allow_exec=0
schema=""

while [ "$#" -gt 0 ]; do
	case "$1" in
	-m | --model)
		if [ "$#" -lt 2 ]; then
			echo "ai: $1 requires an argument" >&2
			exit 1
		fi
		model="$2"
		shift 2
		;;
	-s | --schema)
		if [ "$#" -lt 2 ]; then
			echo "ai: $1 requires an argument" >&2
			exit 1
		fi
		schema="$2"
		shift 2
		;;
	-x | --exec)
		allow_exec=1
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	--)
		shift
		break
		;;
	-*)
		echo "ai: unknown option '$1'" >&2
		usage
		exit 1
		;;
	*)
		break
		;;
	esac
done

# Everything remaining is the question (joined with spaces).
if [ "$#" -gt 0 ]; then
	prompt="$*"
fi

# Need either a question or piped stdin; otherwise there's nothing to ask.
if [ -z "$prompt" ] && [ -t 0 ]; then
	usage
	exit 1
fi

# Build the claude argv in the positional params. With no question, claude reads
# the prompt straight from stdin; with one, it merges any piped stdin as context.
if [ -n "$prompt" ]; then
	set -- -p "$prompt"
else
	set -- -p
fi
set -- "$@" --model "$model" --strict-mcp-config

if [ "$allow_exec" = 1 ]; then
	# Agentic mode: keep Claude Code's default (tool-aware) system prompt and
	# only append the terseness rules; grant tool + home-directory access.
	set -- "$@" --append-system-prompt "$SYSTEM_PROMPT" \
		--dangerously-skip-permissions --add-dir "$HOME"
else
	# Pure ask: replace the system prompt with the lean terse one.
	set -- "$@" --system-prompt "$SYSTEM_PROMPT"
fi

# Optional structured output: constrain the reply to a JSON Schema (must be a
# top-level object schema, per the Messages API). Output is raw, jq-ready JSON.
if [ -n "$schema" ]; then
	set -- "$@" --json-schema "$schema"
fi

# Redirect stdin from /dev/null only when a question was given at an interactive
# terminal, so claude doesn't stall a few seconds waiting for input that won't come.
redirect_null=0
if [ -n "$prompt" ] && [ -t 0 ]; then
	redirect_null=1
fi

# No spinner unless stderr is a terminal: keeps stdout (the reply) clean for
# pipes and shows nothing when stderr is redirected. In that case just exec
# claude and let it stream straight through.
if [ ! -t 2 ]; then
	if [ "$redirect_null" = 1 ]; then
		exec claude "$@" </dev/null
	else
		exec claude "$@"
	fi
fi

# Interactive terminal: background claude and spin on stderr while it works, then
# emit its captured stdout. `<&0` preserves piped stdin — POSIX otherwise
# reassigns an async job's stdin to /dev/null.
out=$(mktemp)
spin_active=0
# shellcheck disable=SC2329  # invoked indirectly via trap
cleanup() {
	if [ "$spin_active" = 1 ]; then printf '\r\033[K' >&2; fi
	rm -f "$out"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [ "$redirect_null" = 1 ]; then
	claude "$@" >"$out" </dev/null &
else
	claude "$@" >"$out" <&0 &
fi
pid=$!

spin_active=1
i=0
while kill -0 "$pid" 2>/dev/null; do
	case $((i % 4)) in
	0) frame='⠋' ;;
	1) frame='⠹' ;;
	2) frame='⠸' ;;
	3) frame='⠇' ;;
	esac
	printf '\r%s thinking…' "$frame" >&2
	i=$((i + 1))
	sleep 0.1
done
printf '\r\033[K' >&2
spin_active=0

status=0
wait "$pid" || status=$?
cat "$out"
exit "$status"
