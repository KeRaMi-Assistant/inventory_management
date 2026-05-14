#!/usr/bin/env bash
# heartbeat.sh — Activity-Aware Heartbeat-Daemon.
#
# Pusht alle 10 Minuten via ntfy.sh den aktuellen Pipeline-Status — ABER nur,
# solange etwas passiert (User-Request 2026-05-15: "10min updates solange was
# passiert"). Bei stiller Idle (keine aktiven Worker UND leere Inboxes UND keine
# kürzlichen Failures) wird NICHT gepusht — User-Phone bleibt ruhig.
#
# Activity-Detection (irgendeines davon → "passiert was"):
#   1. Aktiver Worker-Pool: pgrep "scripts/worker.sh"
#   2. Aktive overseer-pickup: items in .claude/overseer/in_progress/
#   3. Inbox-Items wartend: .claude/overseer/inbox/ ODER legacy .claude/backlog/inbox/
#   4. Failures in den letzten 30 Min: .claude/overseer/failed/ (mmin -30)
#   5. Stakeholder-Pending: .claude/stakeholder/pending-proposal/ ODER pending-approval/
#   6. Legacy: .claude/backlog/.current_task
#
# Bei reinem "Done-Backlog leer" → silent skip (Heartbeat-Daemon zählt im Log, pusht nicht).
# Bei Activity → Push mit kompaktem Status pro Channel.
#
# Singleton: Per fcntl flock auf .claude/overseer/.heartbeat.lock. Zweite Instanz
# beendet sich sauber (verhindert Duplikat-Spam, siehe Bug 2026-05-15 mit 2× heartbeat
# parallel laufend).
#
# Aufruf als Daemon (LaunchAgent-Variante empfohlen):
#   nohup bash .claude/scripts/heartbeat.sh > /tmp/heartbeat.log 2>&1 &
#
# Stoppen:
#   bash .claude/scripts/heartbeat.sh --stop
#
# Single-shot (Debug):
#   bash .claude/scripts/heartbeat.sh --once

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OVERSEER_DIR="$ROOT/.claude/overseer"
BACKLOG_DIR="$ROOT/.claude/backlog"
STAKEHOLDER_DIR="$ROOT/.claude/stakeholder"

# Lock + state
LOCK_FILE="$OVERSEER_DIR/.heartbeat.lock"
LAST_PUSH_FILE="$OVERSEER_DIR/state/heartbeat-last-push.ts"
mkdir -p "$OVERSEER_DIR/state"

# Notify + interval
NOTIFY="$ROOT/.claude/scripts/notify.sh"
INTERVAL="${HEARTBEAT_INTERVAL:-600}"  # 10 Min Default

# --stop / --once shortcut
case "${1:-}" in
  --stop)
    if [ -f "$LOCK_FILE" ]; then
      HOLDER="$(cat "$LOCK_FILE" 2>/dev/null || echo 0)"
      if [ -n "$HOLDER" ] && kill -0 "$HOLDER" 2>/dev/null; then
        kill -TERM "$HOLDER" 2>/dev/null || true
        echo "[heartbeat] sent TERM to pid=$HOLDER"
      fi
    fi
    # Force-kill any stray heartbeat.sh (defensive — alte Instanzen ohne Lock)
    pkill -f "scripts/heartbeat\.sh" 2>/dev/null || true
    rm -f "$LOCK_FILE"
    echo "[heartbeat] stopped"
    exit 0
    ;;
esac

# Load .env.headless for NTFY_TOPIC
if [ -f "$ROOT/.env.headless" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/.env.headless"
  set +a
fi

if [ -z "${NTFY_TOPIC:-}" ]; then
  echo "[heartbeat] NTFY_TOPIC not set in .env.headless — exiting."
  exit 1
fi

# ---------------------------------------------------------------------------
# Singleton-Lock (Python flock, gleiches Pattern wie telegram-bot.py)
# ---------------------------------------------------------------------------
acquire_lock_or_exit() {
  python3 - "$LOCK_FILE" "$$" <<'PYEOF' &
import sys, os, fcntl, signal, time
lock_path = sys.argv[1]
parent_pid = int(sys.argv[2])
fh = open(lock_path, "w")
try:
    fcntl.flock(fh.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
except BlockingIOError:
    sys.exit(1)
fh.write(str(parent_pid))
fh.flush()
os.fsync(fh.fileno())
sys.stdout.write(f"OK {os.getpid()}\n")
sys.stdout.flush()

def _shutdown(_signum, _frame):
    try:
        fcntl.flock(fh.fileno(), fcntl.LOCK_UN)
    except Exception:
        pass
    sys.exit(0)

signal.signal(signal.SIGTERM, _shutdown)
signal.signal(signal.SIGINT, _shutdown)

while True:
    try:
        os.kill(parent_pid, 0)
    except ProcessLookupError:
        sys.exit(0)
    time.sleep(2)
PYEOF
  HELPER_PID=$!
  # Wait briefly for OK or failure
  local deadline=$(( $(date +%s) + 3 ))
  while [ "$(date +%s)" -lt "$deadline" ]; do
    if ! kill -0 "$HELPER_PID" 2>/dev/null; then
      echo "[heartbeat] another instance holds the lock — exiting silently" >&2
      exit 0
    fi
    sleep 0.2
    # Helper writes OK <pid>\n to stdout; we just need it alive after 1s
  done
}

# Only acquire lock in daemon mode (not --once)
if [ "${1:-}" != "--once" ]; then
  acquire_lock_or_exit
  HELPER_PID_OWNED="${HELPER_PID:-}"
  trap '[ -n "${HELPER_PID_OWNED:-}" ] && kill -TERM "$HELPER_PID_OWNED" 2>/dev/null; exit 0' TERM INT EXIT
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
format_duration() {
  local sec="$1"
  local h=$((sec / 3600))
  local m=$(((sec % 3600) / 60))
  if [ "$h" -gt 0 ]; then
    printf '%dh%02dm' "$h" "$m"
  elif [ "$m" -gt 0 ]; then
    printf '%dm' "$m"
  else
    printf '<1m'
  fi
}

count_files() {
  # Robust counter that returns 0 if dir missing
  local dir="$1"
  if [ -d "$dir" ]; then
    find "$dir" -maxdepth 1 -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' '
  else
    echo 0
  fi
}

count_files_recent() {
  # Files modified in last N minutes
  local dir="$1" minutes="$2"
  if [ -d "$dir" ]; then
    find "$dir" -maxdepth 1 -type f -name '*.md' -mmin "-$minutes" 2>/dev/null | wc -l | tr -d ' '
  else
    echo 0
  fi
}

# ---------------------------------------------------------------------------
# Activity-Detection (returns 0=active, 1=silent-idle)
# ---------------------------------------------------------------------------
detect_activity() {
  # 1. Active worker.sh processes
  if pgrep -f "scripts/worker\.sh" >/dev/null 2>&1; then
    ACTIVITY_REASON="worker-running"
    return 0
  fi

  # 2. Items in overseer/in_progress
  local in_progress
  in_progress=$(count_files "$OVERSEER_DIR/in_progress")
  if [ "$in_progress" -gt 0 ]; then
    ACTIVITY_REASON="in-progress=$in_progress"
    return 0
  fi

  # 3. Inbox waiting (overseer or legacy)
  local overseer_inbox legacy_inbox
  overseer_inbox=$(count_files "$OVERSEER_DIR/inbox")
  legacy_inbox=$(count_files "$BACKLOG_DIR/inbox")
  if [ "$overseer_inbox" -gt 0 ] || [ "$legacy_inbox" -gt 0 ]; then
    ACTIVITY_REASON="inbox-pending=$((overseer_inbox + legacy_inbox))"
    return 0
  fi

  # 4. Recent failures (last 30 min)
  local recent_failures
  recent_failures=$(count_files_recent "$OVERSEER_DIR/failed" 30)
  if [ "$recent_failures" -gt 0 ]; then
    ACTIVITY_REASON="recent-failures=$recent_failures"
    return 0
  fi

  # 5. Stakeholder pending
  local proposals approvals
  proposals=$(count_files "$STAKEHOLDER_DIR/pending-proposal")
  approvals=$(count_files "$STAKEHOLDER_DIR/pending-approval")
  if [ "$proposals" -gt 0 ] || [ "$approvals" -gt 0 ]; then
    ACTIVITY_REASON="stakeholder-pending=$((proposals + approvals))"
    return 0
  fi

  # 6. Legacy active task
  if [ -f "$BACKLOG_DIR/.current_task" ]; then
    ACTIVITY_REASON="legacy-task"
    return 0
  fi

  # 7. PANIC marker exists
  if [ -f "$OVERSEER_DIR/PANIC" ]; then
    ACTIVITY_REASON="PANIC-marker-present"
    return 0
  fi

  ACTIVITY_REASON=""
  return 1
}

# ---------------------------------------------------------------------------
# Push one heartbeat
# ---------------------------------------------------------------------------
build_and_push() {
  local reason="$1"

  # Gather state
  local overseer_inbox in_progress overseer_done overseer_failed
  overseer_inbox=$(count_files "$OVERSEER_DIR/inbox")
  in_progress=$(count_files "$OVERSEER_DIR/in_progress")
  overseer_done=$(count_files "$OVERSEER_DIR/done")
  overseer_failed=$(count_files "$OVERSEER_DIR/failed")

  local active_workers
  active_workers=$(pgrep -f "scripts/worker\.sh" 2>/dev/null | wc -l | tr -d ' ')

  local panic_marker=""
  [ -f "$OVERSEER_DIR/PANIC" ] && panic_marker="⛔ PANIC aktiv. "

  local title body

  if [ "$active_workers" -gt 0 ]; then
    # Get oldest worker's elapsed time
    local oldest_etime
    oldest_etime=$(ps -o etime= -p "$(pgrep -f "scripts/worker\.sh" | head -1)" 2>/dev/null | tr -d ' ' || echo "?")
    title="🔧 Worker aktiv ($active_workers)"
    body="${panic_marker}Seit $oldest_etime. In-Progress: $in_progress · Done: $overseer_done · Failed: $overseer_failed."
  elif [ "$in_progress" -gt 0 ]; then
    title="⏳ Item in Bearbeitung"
    body="${panic_marker}$in_progress in_progress, kein Worker-Prozess (gerade gepickt?). Done: $overseer_done."
  elif [ "$overseer_inbox" -gt 0 ]; then
    title="📥 $overseer_inbox Item(s) warten"
    body="${panic_marker}Overseer pickt beim nächsten Tick. Done: $overseer_done · Failed: $overseer_failed."
  elif [ -f "$OVERSEER_DIR/PANIC" ]; then
    title="⛔ PANIC-Marker präsent"
    body="System pausiert. resume.sh nötig oder Marker manuell löschen."
  else
    # Activity-Detection sagte "active" aber wir finden nichts Konkretes → keep silent
    return 0
  fi

  "$NOTIFY" "info" "$NTFY_TOPIC" "$title" "$body" >/dev/null 2>&1 || true
  date +%s > "$LAST_PUSH_FILE"
  echo "[heartbeat $(date -u +%H:%M:%S)] PUSHED: $title — $body (reason=$reason)"
}

# ---------------------------------------------------------------------------
# Loop
# ---------------------------------------------------------------------------
run_tick() {
  ACTIVITY_REASON=""
  if detect_activity; then
    build_and_push "$ACTIVITY_REASON"
  else
    echo "[heartbeat $(date -u +%H:%M:%S)] silent-idle — skip push"
  fi
}

case "${1:-}" in
  --once)
    run_tick
    exit 0
    ;;
esac

echo "[heartbeat] started (pid=$$, interval=${INTERVAL}s, ntfy=$NTFY_TOPIC)"
while true; do
  run_tick
  sleep "$INTERVAL"
done
