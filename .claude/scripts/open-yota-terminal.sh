#!/usr/bin/env bash
# open-yota-terminal.sh — Öffnet ein macOS-Terminal-Fenster und startet yota-live.sh.
#
# Bevorzugt iTerm wenn installiert (sauberere Profile-Steuerung), sonst Terminal.app.
# Setzt Fenster-Titel auf "Yota Live", damit es im Dock/Mission-Control auffindbar ist.
#
# Usage:
#   bash .claude/scripts/open-yota-terminal.sh
#
# ENV (durchgereicht an yota-live.sh):
#   YOTA_LIVE_INTERVAL=5
#   YOTA_LIVE_DONE_LIMIT=15

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
LIVE_SCRIPT="$SCRIPT_DIR/yota-live.sh"

if [ ! -x "$LIVE_SCRIPT" ] && [ ! -f "$LIVE_SCRIPT" ]; then
  printf 'open-yota-terminal: yota-live.sh nicht gefunden unter %s\n' "$LIVE_SCRIPT" >&2
  exit 1
fi

if [ "$(uname -s)" != "Darwin" ]; then
  printf 'open-yota-terminal: nur macOS unterstützt (uname=%s). Starte yota-live.sh direkt:\n' "$(uname -s)" >&2
  printf '  bash %s\n' "$LIVE_SCRIPT" >&2
  exit 1
fi

# Befehl, der im neuen Terminal ausgeführt wird
CMD="cd '$REPO_ROOT' && exec bash '$LIVE_SCRIPT'"

# ENV-Variablen durchreichen (nur die yota-live-spezifischen)
if [ -n "${YOTA_LIVE_INTERVAL:-}" ]; then
  CMD="YOTA_LIVE_INTERVAL=$YOTA_LIVE_INTERVAL $CMD"
fi
if [ -n "${YOTA_LIVE_DONE_LIMIT:-}" ]; then
  CMD="YOTA_LIVE_DONE_LIMIT=$YOTA_LIVE_DONE_LIMIT $CMD"
fi
if [ -n "${YOTA_LIVE_NO_COLOR:-}" ]; then
  CMD="YOTA_LIVE_NO_COLOR=$YOTA_LIVE_NO_COLOR $CMD"
fi

# iTerm bevorzugen wenn vorhanden
if [ -d "/Applications/iTerm.app" ]; then
  /usr/bin/osascript <<EOF
tell application "iTerm"
  activate
  if (count of windows) = 0 then
    create window with default profile
  else
    tell current window to create tab with default profile
  end if
  tell current session of current window
    set name to "Yota Live"
    write text "$CMD"
  end tell
end tell
EOF
  printf 'Yota-Live in iTerm gestartet.\n'
  exit 0
fi

# Fallback: Terminal.app
/usr/bin/osascript <<EOF
tell application "Terminal"
  activate
  set newTab to do script "$CMD"
  set custom title of newTab to "Yota Live"
end tell
EOF

printf 'Yota-Live in Terminal.app gestartet.\n'
