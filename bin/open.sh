#!/bin/sh
exec "${HERDR_BIN_PATH:-herdr}" plugin pane open --plugin "$HERDR_PLUGIN_ID" --entrypoint detail
