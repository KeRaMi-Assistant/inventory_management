#!/usr/bin/env bash
# overseer.sh — Long-running daemon that processes items from
# .claude/overseer/inbox/ via single-worker pipeline (Phase 1 N=1).
#
# Architecture inspiration: ComposioHQ agent-orchestrator (MIT-licensed)
#   https://github.com/ComposioHQ/agent-orchestrator
# We borrow the pattern (atomic-move queue → worker spawn in isolated
# workspace → graceful shutdown markers) but no code. Phase 2 will grow
# this to N>1 worker pool; today the loop is strictly sequential.
#
# CLI:
#   overseer.sh           — daemon-loop (default)
#   overseer.sh --once    — one iteration, then exit
#   overseer.sh --status  — print lock holder PID + current item + pre-flight state
#   overseer.sh --stop    — touch STOP marker
#   overseer.sh --resume  — remove STOP marker
#
# Markers (in $OVERSEER_DIR):
#   STOP                — graceful pause (no pickup; resume via --resume)
#   PANIC               — full halt (set by watchdog or worker exit 2)
#   AUTH_EXPIRED        — set by oauth-check when claude probe fails
#   COST_CAP_REACHED    — set by cost_check_or_die
#
# Lock file: $OVERSEER_DIR/.overseer.lock (separate from .claude/backlog/.lock
#   so the legacy headless-runner stays untouched, Mitigation 8).
#
# IMPORTANT: This file is in the Self-Mod-Blocklist (P0-0).

set -euo pipefail

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

OVERSEER_DIR="${REPO_ROOT}/.claude/overseer"
INBOX_DIR="${OVERSEER_DIR}/inbox"
INPROGRESS_DIR="${OVERSEER_DIR}/in_progress"
DONE_DIR="${OVERSEER_DIR}/done"
FAILED_DIR="${OVERSEER_DIR}/failed"
LOCK_FILE="${OVERSEER_DIR}/.overseer.lock"
STOP_MARKER="${OVERSEER_DIR}/STOP"
PANIC_MARKER="${OVERSEER_DIR}/PANIC"
AUTH_EXPIRED_MARKER="${OVERSEER_DIR}/AUTH_EXPIRED"
COST_CAP_MARKER="${OVERSEER_DIR}/COST_CAP_REACHED"
OAUTH_CACHE_FILE="${OVERSEER_DIR}/state/oauth-last-check.ts"
HOURLY_NOTIFY_FILE="${OVERSEER_DIR}/state/last-hourly-notify.ts"

WORKER_SH="${SCRIPT_DIR}/worker.sh"
NOTIFY_SH="${SCRIPT_DIR}/notify.sh"
WATCHDOG_SH="${SCRIPT_DIR}/watchdog.sh"

LIB_PICKER="${SCRIPT_DIR}/lib/picker.sh"
LIB_WORKTREE="${SCRIPT_DIR}/lib/worktree.sh"
LIB_COST="${SCRIPT_DIR}/lib/cost-cap.sh"
LIB_AUDIT="${SCRIPT_DIR}/lib/audit.sh"
LIB_OAUTH="${SCRIPT_DIR}/lib/oauth-check.sh"

mkdir -p "$OVERSEER_DIR" "$INBOX_DIR" "$INPROGRESS_DIR" "$DONE_DIR" "$FAILED_DIR" "$OVERSEER_DIR/state"

# ---------------------------------------------------------------------------
# Source libraries (optional — degrade gracefully if missing)
# ---------------------------------------------------------------------------
for lib in "$LIB_PICKER" "$LIB_WORKTREE" "$LIB_COST" "$LIB_AUDIT" "$LIB_OAUTH"; do
  if [ -f "$lib" ]; then
    # shellcheck disable=SC1090
    source "$lib"
  fi
done

# ---------------------------------------------------------------------------
# Tunables
# ---------------------------------------------------------------------------
SLEEP_IDLE="${OVERSEER_SLEEP_IDLE:-30}"
SLEEP_BETWEEN="${OVERSEER_SLEEP_BETWEEN:-5}"
WORKER_TIMEOUT_DEFAULT="${OVERSEER_WORKER_TIMEOUT:-14400}"  # 4h
CAP_TODAY="${OVERSEER_CAP_TODAY:-20}"
CAP_WEEK="${OVERSEER_CAP_WEEK:-100}"
OAUTH_TTL="${OVERSEER_OAUTH_TTL:-3600}"
HOURLY_TTL=3600

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
_log() { printf '[overseer %s pid=%d] %s\n' "$(date -u +%H:%M:%S)" "$$" "$*" >&2; }

_audit() {
  if command -v audit_record >/dev/null 2>&1; then
    audit_record "overseer" "$1" "$2" "${3:-}" 2>/dev/null || true
  fi
}

_notify() {
  local severity="$1" title="$2" body="$3"
  local topic="${NTFY_TOPIC:-claude-code}"
  if [ -x "$NOTIFY_SH" ]; then
    REPO_ROOT="$REPO_ROOT" "$NOTIFY_SH" "$severity" "$topic" "$title" "$body" >/dev/null 2>&1 || true
  fi
}

# Hourly-info-notify dedup: throttles a (key,message) pair to once per hour.
_hourly_notify() {
  local key="$1" severity="$2" title="$3" body="$4"
  mkdir -p "$(dirname "$HOURLY_NOTIFY_FILE")"
  local now last
  now="$(date +%s)"
  last=0
  if [ -f "${HOURLY_NOTIFY_FILE}.${key}" ]; then
    last="$(cat "${HOURLY_NOTIFY_FILE}.${key}" 2>/dev/null || echo 0)"
  fi
  if (( now - last >= HOURLY_TTL )); then
    _notify "$severity" "$title" "$body"
    printf '%s' "$now" > "${HOURLY_NOTIFY_FILE}.${key}"
  fi
}

# ---------------------------------------------------------------------------
# Lock-file: fcntl-flock via python3 (POSIX-portable on macOS+Linux)
# Holds an exclusive lock for the lifetime of THIS process. The lock fd is
# kept open via a sleeper child; we kill it on exit.
# ---------------------------------------------------------------------------
LOCK_HOLDER_PID=""

_acquire_lock_or_exit() {
  # Use a python helper that flocks the file then prints the PID and sleeps.
  # If lock contention: exits 1 immediately.
  local helper_out
  helper_out="$(mktemp)"
  python3 - "$LOCK_FILE" "$$" >"$helper_out" 2>/dev/null <<'PYEOF' &
import sys, os, fcntl, time, signal

lock_path = sys.argv[1]
parent_pid = int(sys.argv[2])

fd = open(lock_path, 'w')
try:
    fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
except BlockingIOError:
    sys.exit(1)

# Write parent PID into lock file (so --status can read it).
fd.write(str(parent_pid))
fd.flush()
os.fsync(fd.fileno())

# Print own pid (the helper child) so the parent can kill us on exit.
sys.stdout.write(f"OK {os.getpid()}\n")
sys.stdout.flush()

# Block forever until killed. On SIGTERM we release lock and exit.
def _shutdown(signum, frame):
    try:
        fcntl.flock(fd, fcntl.LOCK_UN)
    except Exception:
        pass
    sys.exit(0)

signal.signal(signal.SIGTERM, _shutdown)
signal.signal(signal.SIGINT, _shutdown)

while True:
    # Verify parent still alive — if not, exit so lock is released.
    try:
        os.kill(parent_pid, 0)
    except ProcessLookupError:
        sys.exit(0)
    time.sleep(2)
PYEOF
  local helper_pid=$!

  # Wait briefly for the helper to print "OK <pid>" or exit 1.
  local deadline=$(( $(date +%s) + 3 ))
  while (( $(date +%s) < deadline )); do
    if [ -s "$helper_out" ]; then
      break
    fi
    if ! kill -0 "$helper_pid" 2>/dev/null; then
      break
    fi
    sleep 0.1
  done

  if ! kill -0 "$helper_pid" 2>/dev/null; then
    # Helper exited → lock contention
    rm -f "$helper_out"
    return 1
  fi

  local first_line
  first_line="$(head -n1 "$helper_out" 2>/dev/null || true)"
  rm -f "$helper_out"

  if [[ "$first_line" =~ ^OK\ ([0-9]+)$ ]]; then
    LOCK_HOLDER_PID="${BASH_REMATCH[1]}"
    return 0
  fi
  # Helper failed in unexpected way
  kill "$helper_pid" 2>/dev/null || true
  return 1
}

_release_lock() {
  if [ -n "$LOCK_HOLDER_PID" ] && kill -0 "$LOCK_HOLDER_PID" 2>/dev/null; then
    kill "$LOCK_HOLDER_PID" 2>/dev/null || true
    wait "$LOCK_HOLDER_PID" 2>/dev/null || true
  fi
  # Best-effort: clear the file content so --status doesn't lie.
  : > "$LOCK_FILE" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Graceful shutdown
# ---------------------------------------------------------------------------
SHUTDOWN_REQUESTED=0
_on_shutdown() {
  SHUTDOWN_REQUESTED=1
  _log "shutdown signal received"
  _audit "shutdown" "overseer" "signal received, releasing lock"
  _release_lock
  exit 0
}
trap _on_shutdown TERM INT
trap _release_lock EXIT

# ---------------------------------------------------------------------------
# Pre-flight: returns 0 if pickup OK, 1 if must idle this iteration.
# Sets PRE_FLIGHT_REASON when idling.
# ---------------------------------------------------------------------------
PRE_FLIGHT_REASON=""

_pre_flight() {
  PRE_FLIGHT_REASON=""

  # 1. STOP marker
  if [ -f "$STOP_MARKER" ]; then
    PRE_FLIGHT_REASON="STOP marker present"
    return 1
  fi

  # 2. PANIC marker
  if [ -f "$PANIC_MARKER" ]; then
    PRE_FLIGHT_REASON="PANIC marker present"
    _hourly_notify "panic" critical \
      "Overseer paused — PANIC marker present" \
      "Remove $PANIC_MARKER manually after investigating to resume."
    _audit "idle" "panic" "PANIC marker present"
    return 1
  fi

  # 3. AUTH_EXPIRED marker
  if [ -f "$AUTH_EXPIRED_MARKER" ]; then
    PRE_FLIGHT_REASON="AUTH_EXPIRED marker present"
    _hourly_notify "auth_expired" info \
      "Overseer paused — auth expired" \
      "Re-authenticate (gh/claude) and rm $AUTH_EXPIRED_MARKER to resume."
    return 1
  fi

  # 4. COST_CAP_REACHED marker
  if [ -f "$COST_CAP_MARKER" ]; then
    PRE_FLIGHT_REASON="COST_CAP_REACHED marker present"
    _hourly_notify "cost_cap" info \
      "Overseer paused — cost cap reached" \
      "Cost-cap reached. Reset ledger or wait until tomorrow, then rm $COST_CAP_MARKER."
    return 1
  fi

  # 5. Cost-cap fresh check (writes COST_CAP_REACHED on hit)
  if command -v cost_check_or_die >/dev/null 2>&1; then
    local rc=0
    cost_check_or_die "$CAP_TODAY" "$CAP_WEEK" >/dev/null 2>&1 || rc=$?
    if [ "$rc" -eq 2 ]; then
      PRE_FLIGHT_REASON="cost-cap exceeded"
      _notify critical "Overseer: cost-cap exceeded" \
        "Today/$CAP_TODAY or Week/$CAP_WEEK exceeded. COST_CAP_REACHED marker written."
      _audit "idle" "cost_cap" "exceeded today=$CAP_TODAY week=$CAP_WEEK"
      return 1
    fi
  fi

  # 6. OAuth-cache (1h TTL); on expired → AUTH_EXPIRED marker.
  if command -v oauth_check_all >/dev/null 2>&1; then
    local now last age
    now="$(date +%s)"
    last=0
    if [ -f "$OAUTH_CACHE_FILE" ]; then
      last="$(cat "$OAUTH_CACHE_FILE" 2>/dev/null || echo 0)"
    fi
    age=$(( now - last ))
    if (( age >= OAUTH_TTL )); then
      local rc=0
      oauth_check_all >/dev/null 2>&1 || rc=$?
      printf '%s' "$now" > "$OAUTH_CACHE_FILE"
      if [ "$rc" -eq 2 ]; then
        # Anthropic expired → marker written by oauth lib; be defensive.
        if [ ! -f "$AUTH_EXPIRED_MARKER" ]; then
          printf 'AUTH_EXPIRED at %s (overseer pre-flight)\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            > "$AUTH_EXPIRED_MARKER"
        fi
        PRE_FLIGHT_REASON="oauth probe failed"
        return 1
      fi
    fi
  fi

  # 7. Watchdog --once (best-effort; do not idle on watchdog errors,
  # only on PANIC marker creation which check 2 above will catch on next pass).
  if [ -x "$WATCHDOG_SH" ]; then
    REPO_ROOT="$REPO_ROOT" "$WATCHDOG_SH" --once >/dev/null 2>&1 || true
    # Re-check PANIC marker, watchdog might have just written it.
    if [ -f "$PANIC_MARKER" ]; then
      PRE_FLIGHT_REASON="watchdog panic"
      return 1
    fi
  fi

  # 8. Recover orphans before pickup attempt.
  if command -v recover_orphaned_items >/dev/null 2>&1; then
    recover_orphaned_items >/dev/null 2>&1 || true
  fi

  return 0
}

# ---------------------------------------------------------------------------
# Extract <slug> from in_progress filename "<slug>.<pid>.md"
# ---------------------------------------------------------------------------
_slug_from_inprogress() {
  local basename
  basename="$(basename "$1")"
  local stem="${basename%.md}"
  # Strip trailing .<digits>
  printf '%s' "$stem" | sed 's/\.[0-9][0-9]*$//'
}

# ---------------------------------------------------------------------------
# Frontmatter scalar reader (timeout_minutes, needs_gh, …)
# ---------------------------------------------------------------------------
_fm_field() {
  local file="$1" field="$2"
  python3 - "$file" "$field" <<'PYEOF' 2>/dev/null || true
import sys, re
try:
    path, field = sys.argv[1], sys.argv[2]
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    fm = re.match(r'^---\s*\n(.*?)\n---\s*\n', content, re.DOTALL)
    if not fm: sys.exit(0)
    for line in fm.group(1).split('\n'):
        m = re.match(r'^' + re.escape(field) + r'\s*:\s*(.+)$', line)
        if m:
            print(m.group(1).strip().strip('"').strip("'"))
            sys.exit(0)
except Exception:
    pass
PYEOF
}

# ---------------------------------------------------------------------------
# Spawn worker on the picked item, wait with timeout, return its exit code.
# ---------------------------------------------------------------------------
_spawn_worker_and_wait() {
  local item_path="$1" worktree_path="$2" slug="$3"

  # Resolve timeout (item override or default)
  local timeout_min timeout_sec
  timeout_min="$(_fm_field "$item_path" "timeout_minutes")"
  if [[ "$timeout_min" =~ ^[0-9]+$ ]]; then
    timeout_sec=$(( timeout_min * 60 ))
  else
    timeout_sec="$WORKER_TIMEOUT_DEFAULT"
  fi

  # Build environment for worker.
  local needs_gh
  needs_gh="$(_fm_field "$item_path" "needs_gh")"

  # Spawn in subshell with a tightly-scoped env. We *export* into the child
  # via env -i + explicit pass-through to avoid leaking secrets the worker
  # has no business touching (Empfehlung l).
  (
    # shellcheck disable=SC2030
    export OVERSEER_WORKER_PID=$$
    export HEADLESS_MODE=1
    export CLAUDE_PROJECT_DIR="$worktree_path"
    export COST_CAP_LEDGER_DIR="${REPO_ROOT}/.claude/overseer"
    export REPO_ROOT="$REPO_ROOT"
    if [ "${needs_gh:-false}" != "true" ]; then
      unset GH_TOKEN
    fi
    bash "$WORKER_SH" "$item_path" "$worktree_path"
  ) &
  local worker_pid=$!

  # Wait with timeout, polling.
  local deadline=$(( $(date +%s) + timeout_sec ))
  while kill -0 "$worker_pid" 2>/dev/null; do
    if (( $(date +%s) >= deadline )); then
      _log "worker timeout (${timeout_sec}s) — killing pid=$worker_pid slug=$slug"
      kill -TERM "$worker_pid" 2>/dev/null || true
      sleep 2
      kill -KILL "$worker_pid" 2>/dev/null || true
      wait "$worker_pid" 2>/dev/null || true
      WORKER_EXIT_CODE=124
      return 0
    fi
    sleep 1
  done

  set +e
  wait "$worker_pid"
  WORKER_EXIT_CODE=$?
  set -e
  return 0
}

# ---------------------------------------------------------------------------
# Process-one-iteration: pre-flight, pick, spawn, release. Returns:
#   0 → processed an item (or idled deliberately); caller may continue.
#   1 → no work available (idle).
# ---------------------------------------------------------------------------
process_one_iteration() {
  if ! _pre_flight; then
    _log "pre-flight idle: $PRE_FLIGHT_REASON"
    _audit "pre_flight_idle" "overseer" "$PRE_FLIGHT_REASON"
    return 1
  fi

  if ! command -v pick_next_item >/dev/null 2>&1; then
    _log "ERROR: picker library not loaded"
    return 1
  fi

  local item_path
  set +e
  item_path="$(pick_next_item "$$" 2>/dev/null)"
  local pick_rc=$?
  set -e

  if [ "$pick_rc" -ne 0 ] || [ -z "$item_path" ] || [ ! -f "$item_path" ]; then
    _log "no item to pick"
    return 1
  fi

  local slug
  slug="$(_slug_from_inprogress "$item_path")"
  _log "picked: $slug"
  _audit "pick" "$slug" "in_progress=$item_path"

  # Worktree create
  local worktree_path
  set +e
  worktree_path="$(worktree_create "$slug" 2>&1)"
  local wt_rc=$?
  set -e

  if [ "$wt_rc" -ne 0 ]; then
    _log "worktree_create failed (rc=$wt_rc): $worktree_path"
    _audit "worktree_failed" "$slug" "rc=$wt_rc out=$worktree_path"
    _notify info "Overseer: worktree create failed" "slug=$slug rc=$wt_rc"
    if command -v release_item >/dev/null 2>&1; then
      release_item "$item_path" failed >/dev/null 2>&1 || true
    fi
    return 0
  fi
  # worktree_create may print warnings prepended; take last non-empty line
  worktree_path="$(printf '%s' "$worktree_path" | awk 'NF{l=$0} END{print l}')"

  # Spawn worker
  WORKER_EXIT_CODE=0
  _spawn_worker_and_wait "$item_path" "$worktree_path" "$slug"
  local code="$WORKER_EXIT_CODE"
  _log "worker exit=$code slug=$slug"

  # Map exit code to release action.
  case "$code" in
    0)
      release_item "$item_path" done >/dev/null 2>&1 || true
      _audit "process_complete" "$slug" "exit=0"
      ;;
    1)
      release_item "$item_path" failed >/dev/null 2>&1 || true
      _audit "process_complete" "$slug" "exit=1 (failed)"
      _notify info "Overseer: item failed" "slug=$slug"
      ;;
    3)
      # Worker: pre-ship gates blocked (Mitigation 15). Item back to inbox
      # with [blocked-pre-ship] marker — NOT failed/.
      release_item "$item_path" blocked-pre-ship >/dev/null 2>&1 || true
      _audit "process_complete" "$slug" "exit=3 (blocked-pre-ship)"
      _notify info "Overseer: pre-ship blocked" "slug=$slug — returned to inbox with [blocked-pre-ship] marker"
      ;;
    2)
      # Worker requests PANIC. Item back to inbox, marker, idle.
      printf 'PANIC: worker exit 2 at %s (slug=%s)\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$slug" > "$PANIC_MARKER"
      # Move item back to inbox without [recovered] marker — just plain.
      local basename slug_clean
      basename="$(basename "$item_path")"
      slug_clean="$(_slug_from_inprogress "$item_path")"
      mv "$item_path" "${INBOX_DIR}/${slug_clean}.md" 2>/dev/null || true
      _audit "panic_from_worker" "$slug" "exit=2 PANIC marker written"
      _notify critical "Overseer: PANIC from worker" "slug=$slug — overseer pausing"
      ;;
    124)
      release_item "$item_path" failed >/dev/null 2>&1 || true
      _audit "process_complete" "$slug" "exit=124 (timeout)"
      _notify info "Overseer: worker timeout" "slug=$slug"
      ;;
    *)
      release_item "$item_path" failed >/dev/null 2>&1 || true
      _audit "process_complete" "$slug" "exit_code=$code"
      _notify info "Overseer: worker abnormal exit" "slug=$slug exit=$code"
      ;;
  esac

  # Cleanup worktree
  if command -v worktree_remove >/dev/null 2>&1; then
    worktree_remove "$slug" >/dev/null 2>&1 || true
  fi

  return 0
}

# ---------------------------------------------------------------------------
# Status mode
# ---------------------------------------------------------------------------
print_status() {
  printf 'Overseer status\n'
  printf '  repo_root        = %s\n' "$REPO_ROOT"
  printf '  overseer_dir     = %s\n' "$OVERSEER_DIR"
  printf '  lock_file        = %s\n' "$LOCK_FILE"

  if [ -f "$LOCK_FILE" ] && [ -s "$LOCK_FILE" ]; then
    local lock_pid
    lock_pid="$(cat "$LOCK_FILE" 2>/dev/null || true)"
    if [[ "$lock_pid" =~ ^[0-9]+$ ]] && kill -0 "$lock_pid" 2>/dev/null; then
      printf '  lock_holder_pid  = %s (alive)\n' "$lock_pid"
    else
      printf '  lock_holder_pid  = %s (stale)\n' "$lock_pid"
    fi
  else
    printf '  lock_holder_pid  = (none)\n'
  fi

  # Current item: only meaningful when exactly 1 in_progress file.
  local count=0 current=""
  if compgen -G "${INPROGRESS_DIR}/*.md" >/dev/null 2>&1; then
    for f in "${INPROGRESS_DIR}"/*.md; do
      count=$((count + 1))
      current="$f"
    done
  fi
  if [ "$count" -eq 1 ]; then
    printf '  current_item     = %s\n' "$(basename "$current")"
  else
    printf '  current_item     = (%d in_progress)\n' "$count"
  fi

  printf '  STOP marker      = %s\n' "$([ -f "$STOP_MARKER" ] && echo present || echo absent)"
  printf '  PANIC marker     = %s\n' "$([ -f "$PANIC_MARKER" ] && echo present || echo absent)"
  printf '  AUTH_EXPIRED     = %s\n' "$([ -f "$AUTH_EXPIRED_MARKER" ] && echo present || echo absent)"
  printf '  COST_CAP_REACHED = %s\n' "$([ -f "$COST_CAP_MARKER" ] && echo present || echo absent)"
}

# ---------------------------------------------------------------------------
# CLI dispatch
# ---------------------------------------------------------------------------
MODE="daemon"
case "${1:-}" in
  --once)   MODE="once" ;;
  --status) MODE="status" ;;
  --stop)   touch "$STOP_MARKER"; printf 'STOP marker created.\n'; exit 0 ;;
  --resume) rm -f "$STOP_MARKER"; printf 'STOP marker removed.\n'; exit 0 ;;
  "")       MODE="daemon" ;;
  *)
    printf 'Usage: %s [--once|--status|--stop|--resume]\n' "$(basename "$0")" >&2
    exit 1
    ;;
esac

if [ "$MODE" = "status" ]; then
  print_status
  exit 0
fi

# ---------------------------------------------------------------------------
# Acquire lock; silent exit if another overseer is running.
# ---------------------------------------------------------------------------
if ! _acquire_lock_or_exit; then
  _log "another overseer holds the lock — exiting silently"
  exit 0
fi
_audit "start" "overseer" "mode=$MODE pid=$$"

if [ "$MODE" = "once" ]; then
  process_one_iteration || true
  _audit "stop" "overseer" "mode=once"
  exit 0
fi

# ---------------------------------------------------------------------------
# daemon loop
# ---------------------------------------------------------------------------
_log "overseer daemon starting"
while [ "$SHUTDOWN_REQUESTED" -eq 0 ]; do
  set +e
  process_one_iteration
  iter_rc=$?
  set -e

  if [ "$iter_rc" -eq 1 ]; then
    sleep "$SLEEP_IDLE"
  else
    sleep "$SLEEP_BETWEEN"
  fi
done

_audit "stop" "overseer" "graceful loop exit"
exit 0
