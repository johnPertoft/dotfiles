# shellcheck shell=bash
# Claude Code main status line. Reads session JSON on stdin, prints:
#   [ctx: 45.2k (23%)] [Opus] [~/Code/dotfiles] [main!]
# Schema: https://code.claude.com/docs/en/statusline#available-data

input=$(cat)

dir=$(echo "$input" | jq -r '.workspace.current_dir')
# Quote "~" so bash 5 doesn't tilde-expand it back into $HOME.
display="${dir/#"$HOME"/"~"}"
# Keep at most the last 3 path components.
display=$(echo "$display" | awk -F'/' '{parts=0; for(i=1;i<=NF;i++) if($i!="") parts++; if(parts>3){p=""; c=0; for(i=NF;i>=1;i--) if($i!=""){p="/"$i p; if(++c==3)break}; print "..."p} else print $0}')

branch=$(git --no-optional-locks -C "$dir" symbolic-ref --short HEAD 2>/dev/null)
dirty=""
git --no-optional-locks -C "$dir" status --porcelain 2>/dev/null | grep -q . && dirty="!"

model=$(echo "$input" | jq -r '.model.display_name')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')

if [ -n "$used" ]; then
	pct=$(printf "%.0f" "$used")
	if [ "$pct" -lt 15 ]; then
		color="1;32"
	elif [ "$pct" -lt 20 ]; then
		color="1;33"
	elif [ "$pct" -lt 50 ]; then
		color="1;38;5;208"
	else color="1;31"; fi
	ktokens=$(awk -v t="$tokens" 'BEGIN{printf "%.1fk", t/1000}')
	printf "\033[%sm[ctx: %s (%s%%)]\033[0m " "$color" "$ktokens" "$pct"
fi
printf "\033[1;37m[%s]\033[0m " "$model"
printf "\033[1;36m[%s]\033[0m " "$display"
[ -n "$branch" ] && printf "\033[1;35m[%s%s]\033[0m" "$branch" "$dirty"
exit 0
