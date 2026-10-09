# Shared helpers. Input: the /api/oauth/usage response. $now: epoch seconds.

def epoch: sub("\\.[0-9]+"; "") | sub("(\\+00:00|Z)$"; "Z") | fromdateiso8601;

def left($ts):
  if $ts == null then ""
  else (($ts | epoch) - $now) as $s
    | if $s <= 0 then "now"
      elif $s < 3600 then "\($s / 60 | floor)m"
      elif $s < 86400 then "\($s / 3600 | floor)h\(($s % 3600) / 60 | floor)m"
      else "\($s / 86400 | floor)d\(($s % 86400) / 3600 | floor)h"
      end
  end;

# One-cell gauge; the sidebar colors on its first character.
def gauge: ["▁","▂","▃","▄","▅","▆","▇","█"][[(. / 12.5 | floor), 7] | min];

def pct: . | round;

# Sidebar token: "▇ 5h 78% 2h13m"
def token($label; $w; $with_reset):
  if $w == null or $w.utilization == null then ""
  else "\($w.utilization | gauge) \($label) \($w.utilization | pct)%"
    + (if $with_reset then " \(left($w.resets_at))" else "" end)
  end;

# The 5h and 7d tokens; "?" marks data the poller has not refreshed recently.
def summary($stale; $r7):
  [token("5h"; .five_hour; true), token("7d"; .seven_day; $r7)]
  | map(if $stale and . != "" then "? " + . else . end);

def color($p): if $p >= 90 then "\u001b[31m" elif $p >= 70 then "\u001b[33m" else "\u001b[32m" end;
def bar($p; $w): ([$p / 100 * $w | round, $w] | min) as $n
  | color($p) + ([range($n)] | map("█") | join("")) + "\u001b[2m"
    + ([range($w - $n)] | map("░") | join("")) + "\u001b[0m";
def name: if .kind == "session" then "Session (5h)"
  elif .kind == "weekly_all" then "Weekly, all models"
  elif .scope.model.display_name then "Weekly, \(.scope.model.display_name)"
  else .kind end;

# Popup body lines.
def detail:
  (if .limits then .limits else
    [{kind: "session", percent: .five_hour.utilization, resets_at: .five_hour.resets_at},
     {kind: "weekly_all", percent: .seven_day.utilization, resets_at: .seven_day.resets_at}]
   end
   | map(select(.percent != null))[]
   | "  \(name)\n  \(bar(.percent; 36)) \(.percent | pct)%  resets in \(left(.resets_at))\n"),
  (.extra_usage | select(.is_enabled == true)
   | "  Extra usage\n  \(bar(.utilization; 36)) \(.utilization | pct)%  $\(.used_credits / 100 | . * 100 | round / 100) of $\(.monthly_limit / 100)\n");
