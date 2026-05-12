#!/usr/bin/env bash
# yota-watch.sh — Optionaler 15-Minuten-Push-Daemon für Yota-Status.
#
# Liest yota-snapshot.sh, baut 1-Zeilen-Summary, schickt per notify.sh an ntfy.
#
# Usage:
#   yota-watch.sh --once     — eine Iteration und exit (default für LaunchAgent)
#   yota-watch.sh --daemon   — Loop mit sleep 900 (15min) zwischen Iterationen
#   yota-watch.sh --dry-run  — print summary, kein notify-Call

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

SNAPSHOT_SH="$SCRIPT_DIR/yota-snapshot.sh"
NOTIFY_SH="$SCRIPT_DIR/notify.sh"

MODE="once"
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --once)    MODE="once" ;;
    --daemon)  MODE="daemon" ;;
    --dry-run) DRY_RUN=1 ;;
    *)
      printf 'Usage: %s [--once|--daemon|--dry-run]\n' "$(basename "$0")" >&2
      exit 1
      ;;
  esac
done

log() { printf '[yota-watch] %s\n' "$*" >&2; }

_summary_from_snapshot() {
  local json
  json="$(bash "$SNAPSHOT_SH" 2>/dev/null || true)"
  if [ -z "$json" ]; then
    printf 'snapshot unavailable'
    return
  fi
  YOTA_JSON="$json" python3 <<'PYEOF'
import json, os
try:
    s = json.loads(os.environ.get('YOTA_JSON', '{}'))
except Exception:
    print('snapshot parse error')
    raise SystemExit(0)
status = s.get('status', 'unknown')
w = s.get('workers', {})
i = s.get('inbox', {})
c = s.get('cost', {})
alerts = s.get('alerts', []) or []
parts = [
    f"{status}",
    f"{w.get('active',0)}/{w.get('max',0)} worker",
    f"{i.get('done_today',0)}d/{i.get('failed_today',0)}f",
    f"${c.get('today_usd',0)}/${c.get('cap_today',0)}",
]
if alerts:
    parts.append(f"⚠ {len(alerts)} alert")
print(" · ".join(parts))
PYEOF
}

run_once() {
  local summary
  summary="$(_summary_from_snapshot)"
  log "summary: $summary"

  if [ "$DRY_RUN" = "1" ]; then
    printf 'DRY-RUN: %s\n' "$summary"
    return 0
  fi

  if [ -x "$NOTIFY_SH" ]; then
    REPO_ROOT="$REPO_ROOT" "$NOTIFY_SH" info yota "Yota Status" "$summary" '[]' 2>/dev/null || true
    log "notify dispatched"
  fi
}

case "$MODE" in
  once)
    run_once
    ;;
  daemon)
    log "daemon mode (sleep 900 between runs)"
    while true; do
      run_once
      sleep 900
    done
    ;;
esac
