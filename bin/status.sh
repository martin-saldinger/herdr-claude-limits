#!/bin/sh
# One-line summary for Herdr's tab bar (a ui.tab_bar_right command entry), read
# from the poller's cache. Herdr strips colors there, so the gauge glyph is the cue.
lib=$(dirname "$0")
usage="${CLAUDE_LIMITS_USAGE:-${XDG_STATE_HOME:-$HOME/.local/state}/herdr/plugins/martin.claude-limits/usage.json}"
[ -f "$usage" ] || exit 1
now=$(date +%s)
age=$((now - $(stat -f %m "$usage" 2>/dev/null || stat -c %Y "$usage")))
jq -r --argjson now "$now" --argjson stale "$([ "$age" -gt 180 ] && echo true || echo false)" -L "$lib" \
  'include "limits"; summary($stale; false) | map(select(. != "")) | join(" · ")' "$usage"
