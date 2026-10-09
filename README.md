# herdr-claude-limits

Herdr plugin that polls your Claude plan usage (the same endpoint `/usage` reads) and
shows a one-line summary in the tab bar, plus a popup with all limits.

```sh
herdr plugin link .
herdr plugin action invoke martin.claude-limits.restart   # startup hook does this on server start
```

Tab bar summary and popup key (`~/.config/herdr/config.toml`):

```toml
[ui]
tab_bar_right = [
  { type = "command", command = "/path/to/herdr-claude-limits/bin/status.sh", interval_seconds = 10 },
]

[[keys.command]]
key = "prefix+u"
type = "plugin_action"
command = "martin.claude-limits.show"
```

Options go in `$(herdr plugin config-dir martin.claude-limits)/config.env`:
`FETCH_INTERVAL=60`, and `SIDEBAR=1` to also report `$cc5h` / `$cc7d` tokens on the
focused Claude pane for `ui.sidebar.agents.rows_by_agent` (tuned by `TICK`, `REFRESH`, `SHOW_7D_RESET`).

The OAuth token is read from the macOS Keychain (or `~/.claude/.credentials.json`) and
never refreshed by the plugin; Claude Code keeps it fresh. Logs: `$HERDR_PLUGIN_STATE_DIR/poller.log`.
