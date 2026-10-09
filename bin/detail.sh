#!/bin/bash
# Popup view of every limit the usage endpoint reports. q or Esc closes it.
usage="$HERDR_PLUGIN_STATE_DIR/usage.json"
lib="$HERDR_PLUGIN_ROOT/bin"
printf '\033[?25l'
trap 'printf "\033[?25h"' EXIT

while :; do
  printf '\033[H\033[2J\n  \033[1mClaude usage limits\033[0m\n\n'
  if [ -f "$usage" ]; then
    jq -r --argjson now "$(date +%s)" -L "$lib" 'include "limits"; detail' "$usage"
    age=$(( $(date +%s) - $(stat -f %m "$usage" 2>/dev/null || stat -c %Y "$usage") ))
    printf '  \033[2mupdated %ss ago · q to close\033[0m' "$age"
  else
    printf '  No data yet. Is the poller running? (restart action)\n'
  fi
  read -rsn1 -t 5 key
  rc=$?
  [ $rc -gt 0 ] && [ $rc -le 128 ] && exit 0 # stdin closed; >128 is the timeout
  case "$key" in q|Q|$'\e') exit 0 ;; esac
  key=
done
