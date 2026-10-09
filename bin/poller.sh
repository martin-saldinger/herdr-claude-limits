#!/bin/sh
# Polls the Claude plan usage endpoint into $HERDR_PLUGIN_STATE_DIR/usage.json,
# which bin/status.sh turns into the tab bar summary.
#
# With SIDEBAR=1 it also reports pane metadata tokens ($cc5h, $cc7d) on a single
# Claude pane: the focused one, else the last one they were shown on.
#
# Optional config: $HERDR_PLUGIN_CONFIG_DIR/config.env
#   FETCH_INTERVAL=60    seconds between usage API calls
#   SIDEBAR=0            also report sidebar tokens
#   TICK=2               seconds between focus checks
#   REFRESH=10           seconds between sidebar text refreshes
#   SHOW_7D_RESET=0      append the weekly reset countdown to $cc7d
set -u
herdr="${HERDR_BIN_PATH:-herdr}"
root="$HERDR_PLUGIN_ROOT"
state="$HERDR_PLUGIN_STATE_DIR"
FETCH_INTERVAL=60
SIDEBAR=0
TICK=2
REFRESH=10
SHOW_7D_RESET=0
[ -f "$HERDR_PLUGIN_CONFIG_DIR/config.env" ] && . "$HERDR_PLUGIN_CONFIG_DIR/config.env"

usage="$state/usage.json"
source_id="plugin:martin.claude-limits"
last_fetch=0
backoff=$FETCH_INTERVAL
misses=0
target=
shown=
last_report=0

log() { echo "$(date '+%F %T') $*"; }

# Read the access token Claude Code stores. Never refresh it here: rotating the
# refresh token would log Claude Code out. Claude Code refreshes it itself.
access_token() {
  creds=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null) \
    || creds=$(cat "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.credentials.json" 2>/dev/null) \
    || return 1
  printf '%s' "$creds" | jq -er '.claudeAiOauth.accessToken'
}

fetch() {
  token=$(access_token) || { log "no Claude Code credentials found"; return 1; }
  code=$(curl -sS -m 15 -o "$usage.tmp" -w '%{http_code}' \
    https://api.anthropic.com/api/oauth/usage \
    -H "Authorization: Bearer $token" \
    -H "anthropic-beta: oauth-2025-04-20" \
    -H "User-Agent: herdr-claude-limits/0.1") || { log "fetch failed"; return 1; }
  case "$code" in
    200) jq -e '.five_hour' "$usage.tmp" >/dev/null && mv "$usage.tmp" "$usage" && return 0 ;;
    429) backoff=$((backoff * 2)); [ "$backoff" -gt 600 ] && backoff=600 ;;
  esac
  log "usage endpoint returned HTTP $code"
  return 1
}

log "poller started (pid $$)"
while :; do
  now=$(date +%s)
  if [ $((now - last_fetch)) -ge "$backoff" ]; then
    last_fetch=$now
    fetch && backoff=$FETCH_INTERVAL
  fi

  panes=$("$herdr" pane list 2>/dev/null) || {
    misses=$((misses + 1))
    # Herdr server is gone; the next startup hook starts a fresh poller.
    [ $((misses * TICK)) -ge 60 ] && { log "herdr unreachable, exiting"; exit 0; }
    sleep "$TICK"; continue
  }
  misses=0

  if [ "$SIDEBAR" = 1 ] && [ -f "$usage" ]; then
    # Data older than three fetch intervals is shown as stale.
    age=$((now - $(stat -f %m "$usage" 2>/dev/null || stat -c %Y "$usage")))
    stale=$([ "$age" -gt $((FETCH_INTERVAL * 3)) ] && echo 1 || echo 0)
    out=$(jq -r --argjson now "$now" --argjson stale "$stale" --argjson r7 "$SHOW_7D_RESET" -L "$root/bin" \
      'include "limits"; summary($stale == 1; $r7 == 1)[]' "$usage")
    t5h=$(printf '%s\n' "$out" | sed -n 1p)
    t7d=$(printf '%s\n' "$out" | sed -n 2p)

    pick=$(printf '%s' "$panes" | jq -r --arg prev "$target" '
      [.result.panes[] | select(.agent == "claude")] as $c
      | ($c | map(select(.focused)))[0].pane_id
        // ($c | map(select(.pane_id == $prev)))[0].pane_id
        // $c[0].pane_id // empty')

    if [ "$pick" != "$target" ] && [ -n "$target" ]; then
      "$herdr" pane report-metadata "$target" --source "$source_id" \
        --clear-token cc5h --clear-token cc7d >/dev/null 2>&1
    fi
    if [ -n "$pick" ] && { [ "$pick" != "$target" ] || [ "$t5h|$t7d" != "$shown" ] ||
      [ $((now - last_report)) -ge "$REFRESH" ]; }; then
      "$herdr" pane report-metadata "$pick" --source "$source_id" \
        --token "cc5h=$t5h" --token "cc7d=$t7d" \
        --ttl-ms $((REFRESH * 3 * 1000)) >/dev/null 2>&1
      shown="$t5h|$t7d"
      last_report=$now
    fi
    target=$pick
  fi
  sleep "$TICK"
done
