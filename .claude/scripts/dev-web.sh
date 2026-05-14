#!/usr/bin/env bash
# Startet Flutter-Web im Hintergrund auf festem Port 8123.
# Idempotent: wenn schon ein Server lauscht, gibt er nur die PID zurück.
# Schreibt Logs nach .claude/test-runs/dev-web.log.
#
# Usage:
#   bash dev-web.sh [--profile|--audit-build] [-h|--help]
#
# Flags:
#   --profile / --audit-build   Profile-Build mit Source-Maps (Dart-Exceptions
#                               sichtbar, DevTools-Connectivity aktiv, ~6× größer).
#                               Default: Release-Build.
#   -h / --help                 Diesen Hilfetext anzeigen.

set -euo pipefail

PORT="${FLUTTER_WEB_PORT:-8123}"
LOG_DIR="$(git rev-parse --show-toplevel)/.claude/test-runs"
LOG_FILE="$LOG_DIR/dev-web.log"
PID_FILE="$LOG_DIR/dev-web.pid"
PROFILE_MODE=0

# --- Argument-Parsing ---
for arg in "$@"; do
  case "$arg" in
    --profile|--audit-build)
      PROFILE_MODE=1
      ;;
    -h|--help)
      sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "dev-web: unknown flag '$arg'" >&2
      echo "  Use -h for help." >&2
      exit 1
      ;;
  esac
done

mkdir -p "$LOG_DIR"

if lsof -ti tcp:"$PORT" >/dev/null 2>&1; then
  EXISTING_PID="$(lsof -ti tcp:"$PORT" | head -n1)"
  echo "dev-web: port $PORT already in use by PID $EXISTING_PID — reusing"
  echo "$EXISTING_PID" > "$PID_FILE"
  echo "url=http://localhost:$PORT"
  echo "pid=$EXISTING_PID"
  exit 0
fi

cd "$(git rev-parse --show-toplevel)"

if ! command -v flutter >/dev/null 2>&1; then
  echo "dev-web: flutter not on PATH" >&2
  exit 1
fi

# Headless-Chrome via flutter run wäre ideal, aber das blockiert.
# → flutter build web + python -m http.server ist deterministischer.
if [ "$PROFILE_MODE" -eq 1 ]; then
  echo "dev-web: building web bundle in PROFILE mode (Dart-Exceptions + Source-Maps + Semantics, ~60-120s)..."
  flutter build web --profile --source-maps --no-tree-shake-icons \
    --dart-define=ENABLE_SEMANTICS=true >"$LOG_FILE" 2>&1 || {
    echo "dev-web: flutter build web --profile failed — see $LOG_FILE" >&2
    exit 1
  }
else
  echo "dev-web: building web bundle in RELEASE mode (this can take ~60s on first run)..."
  flutter build web --release --no-tree-shake-icons >"$LOG_FILE" 2>&1 || {
    echo "dev-web: flutter build web failed — see $LOG_FILE" >&2
    exit 1
  }
fi

cd build/web
python3 -m http.server "$PORT" >>"$LOG_FILE" 2>&1 &
SERVER_PID=$!
echo "$SERVER_PID" > "$PID_FILE"

# Polling bis Port antwortet
for i in $(seq 1 30); do
  if curl -sf "http://localhost:$PORT/" >/dev/null 2>&1; then
    echo "dev-web: ready"
    echo "url=http://localhost:$PORT"
    echo "pid=$SERVER_PID"
    echo "log=$LOG_FILE"
    exit 0
  fi
  sleep 0.5
done

echo "dev-web: server did not respond within 15s — see $LOG_FILE" >&2
kill "$SERVER_PID" 2>/dev/null || true
exit 1
