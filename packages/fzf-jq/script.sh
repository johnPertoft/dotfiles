#!/usr/bin/env bash
# Live jq explorer — type a jq filter and see it apply on every keystroke.
#
# Usage:  fzf-jq file.json        (read from a file)
#         some-cmd | fzf-jq       (read from stdin)
#
# - Result renders live in the preview as you type.
# - Half-typed / invalid filters show jq's error inline (expected).
# - Enter: print the RESULT to stdout (so `fzf-jq f.json > out.json` works);
#   the filter used is echoed to stderr so you can see/reuse it.
# - CTRL-O: page the current output in less.
# - CTRL-Y: copy the current filter to the clipboard, using whichever tool is
#   present (pbcopy/wl-copy/xclip/xsel); a no-op if none is installed.

# jq must re-read the input on every keystroke, so materialize it to a file
# (a stdin pipe can only be consumed once).
STATE_DIR="${TMPDIR:-/tmp}/fzf-jq.$$"
mkdir -p "$STATE_DIR"
trap 'rm -rf "$STATE_DIR"' EXIT
INPUT="$STATE_DIR/input.json"
if [ -n "${1:-}" ]; then
	cat -- "$1" >"$INPUT"
else
	cat >"$INPUT"
fi
export INPUT

# The preview/action strings are evaluated by fzf's own subshell (which has
# $INPUT exported and substitutes {q}), not by this script.
# shellcheck disable=SC2016
echo | fzf --disabled --query '.' \
	--prompt 'jq> ' \
	--header 'jq filter · Enter: emit result (> file) · ^O: page output · ^Y: copy filter' \
	--preview 'jq --color-output {q} "$INPUT" 2>&1' \
	--preview-window 'up,99%,wrap' \
	--bind 'change:refresh-preview' \
	--bind 'enter:become(printf "jq %s\n" {q} >&2; jq {q} "$INPUT")' \
	--bind 'ctrl-o:execute:jq --color-output {q} "$INPUT" 2>&1 | less -R' \
	--bind 'ctrl-y:execute-silent(printf %s {q} | { pbcopy || wl-copy || xclip -selection clipboard || xsel -b; } 2>/dev/null)'
