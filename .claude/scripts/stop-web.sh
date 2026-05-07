#!/usr/bin/env bash
# Stoppt den dev-web.sh-Server (PID aus .claude/test-runs/dev-web.pid) sauber.

set -euo pipefail

PORT="${FLUTTER_WEB_PORT:-8123}"
ROOT="$(git rev-parse --show-toplevel)"
PID_FILE="$ROOT/.claude/test-runs/dev-web.pid"

if [ -f "$PID_FILE" ]; then
  PID="$(cat "$PID_FILE")"
  if kill -0 "$PID" 2>/dev/null; then
    kill "$PID" || true
    echo "stop-web: killed PID $PID"
  else
    echo "stop-web: PID $PID not running"
  fi
  rm -f "$PID_FILE"
else
  echo "stop-web: no PID file"
fi

# Fallback: kill anything else holding the port
LINGERING="$(lsof -ti tcp:"$PORT" 2>/dev/null || true)"
if [ -n "$LINGERING" ]; then
  echo "stop-web: also killing lingering PIDs on port $PORT: $LINGERING"
  echo "$LINGERING" | xargs -r kill 2>/dev/null || true
fi

exit 0
