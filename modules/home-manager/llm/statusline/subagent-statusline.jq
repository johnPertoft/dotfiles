# Claude Code subagentStatusLine renderer.
# Input:  {columns, tasks: [...], ...base hook fields}
# Output: one {"id","content"} JSON line per task (run with jq -c).
# Schema: https://code.claude.com/docs/en/statusline#subagent-status-lines
#
# Row layout (colours match the main status line's context thresholds):
#   ● Explore [opus·high] [ctx: 12.3k (6%)] ▁▂▃▅▇ 1m42s Research statusline schema

def esc($c): "\u001b[" + $c + "m";
def reset: "\u001b[0m";

# 12345 -> "12.3k"
def ktok: (. / 100 | floor) as $d | "\($d / 10 | floor).\($d % 10)k";

def ctxcolor:
  if . < 15 then "1;32" elif . < 20 then "1;33"
  elif . < 50 then "1;38;5;208" else "1;31" end;

# Seconds -> "42s" / "1m42s" / "1h05m"
def dur:
  floor as $s
  | if $s < 60 then "\($s)s"
    elif $s < 3600 then "\($s / 60 | floor)m\($s % 60 | tostring | if length < 2 then "0" + . else . end)s"
    else "\($s / 3600 | floor)h\(($s % 3600) / 60 | floor | tostring | if length < 2 then "0" + . else . end)m"
    end;

# "claude-opus-5-5[1m]" / "us.anthropic.claude-sonnet-..." -> "opus" / "sonnet"
def shortmodel:
  (capture("(?<f>opus|sonnet|haiku|fable)").f) // sub("^claude-"; "");

# Token samples -> sparkline; empty when there's nothing to compare.
def spark:
  if length < 2 then ""
  else (min) as $lo | (max) as $hi
    | if $hi == $lo then ""
      else map(((. - $lo) / ($hi - $lo) * 7 | round) as $i | "▁▂▃▄▅▆▇█"[$i:$i + 1]) | join("")
      end
  end;

# Truncate plain text to $n visible chars with an ellipsis.
def fit($n):
  if $n <= 0 then ""
  elif length <= $n then .
  elif $n == 1 then "…"
  else .[0:$n - 1] + "…" end;

(.columns // 80) as $cols
| now as $now
| .tasks[]
| . as $t
| ( {running: ["●", "1;33"], completed: ["✓", "1;32"], failed: ["✗", "1;31"], killed: ["✗", "1;31"]}[$t.status]
    // ["·", "2"] ) as $st
| ( [ $t.model | select(.) | shortmodel ] + [ $t.effort | select(.) | tostring ] | join("·") ) as $me
| ( if $t.contextWindowSize and $t.contextWindowSize > 0 then
      ($t.tokenCount / $t.contextWindowSize * 100 | round) as $p
      | ["[ctx: \($t.tokenCount | ktok) (\($p)%)]", ($p | ctxcolor)]
    else ["[\($t.tokenCount | ktok)]", "1;37"] end ) as $ctx
# [plain text, colour, drop-priority] segments; higher priority is dropped
# first when the row doesn't fit. 0 = never dropped.
| [ $st + [0],
    [($t.name // $t.agentType // "agent"), "1;36", 0],
    (if $me != "" then ["[\($me)]", "1;37", 2] else empty end),
    $ctx + [0],
    ([($t.tokenSamples // []) | spark, "2", 3] | select(.[0] != "")),
    (if $t.status == "running" and $t.startTime then [($now - $t.startTime / 1000) | dur, "1;35", 1] else empty end)
  ] as $all
# Visible width of segments plus one separating space each.
| def width: map(.[0] | length) | add + length;
  # Drop optional segments until there's room for ~12 chars of label.
  ( $all | until(width + 12 <= $cols or all(.[2] == 0);
             (map(.[2]) | max) as $m | map(select(.[2] != $m))) ) as $segs
| ($t.label // $t.description // "") | fit($cols - ($segs | width)) as $text
| { id: $t.id,
    content: (
      ($segs | map(esc(.[1]) + .[0] + reset) | join(" "))
      + (if $text != "" then " " + $text else "" end)
    ) }
