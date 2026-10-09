#!/bin/sh
# Start (or restart) the detached poller. Startup hooks are one-shot, so the
# poller runs in the background and exits on its own once Herdr goes away.
set -eu
state="${HERDR_PLUGIN_STATE_DIR:?}"
pidfile="$state/poller.pid"

if [ -f "$pidfile" ]; then
  kill "$(cat "$pidfile")" 2>/dev/null || true
  rm -f "$pidfile"
fi

nohup sh "$HERDR_PLUGIN_ROOT/bin/poller.sh" >>"$state/poller.log" 2>&1 </dev/null &
echo $! >"$pidfile"
echo "claude-limits poller started (pid $!)"
