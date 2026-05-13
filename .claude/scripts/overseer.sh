#!/usr/bin/env bash
# overseer.sh — Long-running daemon that processes items from
# .claude/overseer/inbox/ via N-worker pool (Phase 2, default N=2, hard-cap N=3).
#
# Architecture inspiration: ComposioHQ agent-orchestrator (MIT-licensed)
#   https://github.com/ComposioHQ/agent-orchestrator
# We borrow the pattern (atomic-move queue → worker spawn in isolated
# workspace → graceful shutdown markers) but no code.
#
# CLI:
#   overseer.sh           — daemon-loop (default)
#   overseer.sh --once    — one pool-management iteration, then exit
#   overseer.sh --status  — print lock holder PID + current items + pre-flight state
#   overseer.sh --stop    — touch STOP marker
#   overseer.sh --resume  — remove STOP marker
#
# Markers (in $OVERSEER_DIR):
#   STOP                — graceful pause (no pickup; resume via --resume)
#   PANIC               — full halt (set by watchdog or worker exit 2)
#   AUTH_EXPIRED        — set by oauth-check when claude probe fails
#   COST_CAP_REACHED    — set by cost_check_or_die
#
# Worker-Pool (P2-1):
#   OVERSEER_MAX_WORKERS — max parallel workers (default 2, hard-cap 3)
#   Worker state tracked in $OVERSEER_DIR/state/workers/<pid>.pid (JSON)
#   Each worker writes exit-code to <pid>.exit on trap-EXIT.
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
WORKERS_STATE_DIR="${OVERSEER_DIR}/state/workers"
HEALTH_JSON="${OVERSEER_DIR}/health.json"

# Stakeholder-Triage paths (P2-4)
STAKEHOLDER_DIR="${REPO_ROOT}/.claude/stakeholder"
STAKEHOLDER_INBOX_DIR="${STAKEHOLDER_DIR}/inbox"
STAKEHOLDER_TRIAGED_DIR="${STAKEHOLDER_DIR}/triaged"
STAKEHOLDER_QUARANTINE_DIR="${STAKEHOLDER_DIR}/quarantine"
STAKEHOLDER_PROCESSED_DIR="${STAKEHOLDER_DIR}/processed"
TRIAGE_LAST_RUN_FILE="${OVERSEER_DIR}/state/triage-last-run.ts"
TRIAGE_INTERVAL="${OVERSEER_TRIAGE_INTERVAL:-60}"   # seconds between triage sweeps
TRIAGE_BUDGET_PER_ITEM="${OVERSEER_TRIAGE_BUDGET:-0.50}"
VALIDATOR_BUDGET_PER_ITEM="${OVERSEER_VALIDATOR_BUDGET:-0.20}"

WORKER_SH="${SCRIPT_DIR}/worker.sh"
NOTIFY_SH="${SCRIPT_DIR}/notify.sh"
WATCHDOG_SH="${SCRIPT_DIR}/watchdog.sh"

LIB_PICKER="${SCRIPT_DIR}/lib/picker.sh"
LIB_WORKTREE="${SCRIPT_DIR}/lib/worktree.sh"
LIB_COST="${SCRIPT_DIR}/lib/cost-cap.sh"
LIB_AUDIT="${SCRIPT_DIR}/lib/audit.sh"
LIB_OAUTH="${SCRIPT_DIR}/lib/oauth-check.sh"
LIB_PANIC="${SCRIPT_DIR}/lib/panic.sh"

mkdir -p "$OVERSEER_DIR" "$INBOX_DIR" "$INPROGRESS_DIR" "$DONE_DIR" "$FAILED_DIR" "$OVERSEER_DIR/state" "$WORKERS_STATE_DIR" \
  "$STAKEHOLDER_INBOX_DIR" "$STAKEHOLDER_TRIAGED_DIR" "$STAKEHOLDER_QUARANTINE_DIR" "$STAKEHOLDER_PROCESSED_DIR"

# ---------------------------------------------------------------------------
# Source libraries (optional — degrade gracefully if missing)
# ---------------------------------------------------------------------------
for lib in "$LIB_PICKER" "$LIB_WORKTREE" "$LIB_COST" "$LIB_AUDIT" "$LIB_OAUTH" "$LIB_PANIC"; do
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

# Cloud-Heartbeat (P3-12): interval in seconds (default 60 min)
HEARTBEAT_INTERVAL="${OVERSEER_HEARTBEAT_INTERVAL:-3600}"
HEARTBEAT_PING_SH="${SCRIPT_DIR}/cloud-heartbeat-ping.sh"
_last_heartbeat_ts=0

# Worker-Pool tunables (P2-1)
# Note: clamp + log happen after _log is defined (see _pool_init_worker_pool below).
_RAW_MAX_WORKERS="${OVERSEER_MAX_WORKERS:-2}"
POOL_MAX_WORKERS=2  # resolved in _pool_init_worker_pool
POOL_MAX_WORKERS_CLAMP_WARN=""  # set if clamped, logged after _log defined
# Health-JSON stale threshold for disk-watchdog-pause (seconds)
HEALTH_JSON_STALE_TTL=60

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
_log() { printf '[overseer %s pid=%d] %s\n' "$(date -u +%H:%M:%S)" "$$" "$*" >&2; }

# Resolve POOL_MAX_WORKERS now that _log is defined.
_pool_init_worker_pool() {
  if (( _RAW_MAX_WORKERS > 3 )); then
    _log "WARN: OVERSEER_MAX_WORKERS=${_RAW_MAX_WORKERS} > 3 — clamping to 3"
    POOL_MAX_WORKERS=3
  elif (( _RAW_MAX_WORKERS < 1 )); then
    POOL_MAX_WORKERS=1
  else
    POOL_MAX_WORKERS="${_RAW_MAX_WORKERS}"
  fi
  unset _RAW_MAX_WORKERS
}
_pool_init_worker_pool

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
# Stakeholder-Triage Pipeline (P2-4)
# ---------------------------------------------------------------------------

# _triage_slug_from_file <filepath> → derive slug from filename
_triage_slug_from_file() {
  local base
  base="$(basename "$1" .md)"
  printf '%s' "$base"
}

# _run_stakeholder_triage_pipeline <inbox_file>
# Runs triage + validator for a single stakeholder inbox item.
# Handles cost-check, audit, quarantine/pass routing.
# Rate-limit: 1 triage per second (enforced by caller sweep loop).
_run_stakeholder_triage_pipeline() {
  local inbox_file="$1"
  local slug
  slug="$(_triage_slug_from_file "$inbox_file")"

  _log "triage: starting pipeline for slug=$slug"
  _audit "triage_started" "$slug" "inbox_file=$inbox_file"

  # Cost-check before invoking triage LLM
  if command -v cost_check_or_die >/dev/null 2>&1; then
    local cc_rc=0
    cost_check_or_die "$CAP_TODAY" "$CAP_WEEK" >/dev/null 2>&1 || cc_rc=$?
    if [ "$cc_rc" -eq 2 ]; then
      _log "triage: cost-cap exceeded — aborting triage for slug=$slug"
      _audit "triage_skipped" "$slug" "cost-cap exceeded"
      return 1
    fi
  fi

  # Record triage cost
  if command -v cost_record >/dev/null 2>&1; then
    cost_record "stakeholder-triage" "$TRIAGE_BUDGET_PER_ITEM" >/dev/null 2>&1 || true
  fi

  # Invoke triage agent
  local triage_rc=0
  set +e
  claude --print --agent stakeholder-triage \
    "Process stakeholder inbox file: ${inbox_file}" \
    >/dev/null 2>&1
  triage_rc=$?
  set -e

  if [ "$triage_rc" -ne 0 ]; then
    _log "triage: agent failed (rc=$triage_rc) for slug=$slug"
    _audit "triage_agent_failed" "$slug" "rc=$triage_rc"
    return 1
  fi

  # Determine triage output type by checking which file was written
  local triaged_file="${STAKEHOLDER_TRIAGED_DIR}/01-stakeholder-${slug}.md"
  local quarantine_triage_file="${STAKEHOLDER_QUARANTINE_DIR}/${slug}.md"
  local response_file="${STAKEHOLDER_DIR}/responses/${slug}.md"

  if [ -f "$quarantine_triage_file" ]; then
    # Triage agent detected injection-attempt → already quarantined
    _log "triage: injection-attempt quarantined by triage agent: slug=$slug"
    _audit "triage_quarantined" "$slug" "injection-attempt detected by triage agent"
    _notify info "Stakeholder-Item quarantined (triage): $slug" \
      "see ${quarantine_triage_file}"
    # Move original to processed
    mv "$inbox_file" "${STAKEHOLDER_PROCESSED_DIR}/${slug}.md" 2>/dev/null || \
      cp "$inbox_file" "${STAKEHOLDER_PROCESSED_DIR}/${slug}.md" && rm -f "$inbox_file" || true
    return 0
  fi

  if [ -f "$response_file" ]; then
    # Triage agent answered a question → no backlog item needed
    _log "triage: question answered for slug=$slug"
    _audit "triage_question_answered" "$slug" "response=$response_file"
    mv "$inbox_file" "${STAKEHOLDER_PROCESSED_DIR}/${slug}.md" 2>/dev/null || \
      cp "$inbox_file" "${STAKEHOLDER_PROCESSED_DIR}/${slug}.md" && rm -f "$inbox_file" || true
    return 0
  fi

  if [ ! -f "$triaged_file" ]; then
    _log "triage: no output file found for slug=$slug — agent may have failed silently"
    _audit "triage_no_output" "$slug" "expected $triaged_file"
    return 1
  fi

  # Triage produced a backlog item — run validator
  _log "triage: running validator for slug=$slug"

  # Record validator cost
  if command -v cost_record >/dev/null 2>&1; then
    cost_record "stakeholder-validator" "$VALIDATOR_BUDGET_PER_ITEM" >/dev/null 2>&1 || true
  fi

  local validator_rc=0
  set +e
  claude --print --agent stakeholder-validator \
    "Validate triage output file: ${triaged_file}" \
    >/dev/null 2>&1
  validator_rc=$?
  set -e

  if [ "$validator_rc" -ne 0 ]; then
    _log "triage: validator agent failed (rc=$validator_rc) for slug=$slug"
    _audit "triage_validator_failed" "$slug" "rc=$validator_rc"
    return 1
  fi

  # Check validator decision: look for .cleared marker (pass) or -rejected.md (quarantine)
  local cleared_marker="${STAKEHOLDER_TRIAGED_DIR}/${slug}.cleared"
  local rejected_file="${STAKEHOLDER_QUARANTINE_DIR}/${slug}-rejected.md"

  local validator_result="unknown"

  if [ -f "$cleared_marker" ]; then
    validator_result="pass"
    # Validator wrote to .claude/overseer/inbox/01-stakeholder-<slug>.md already
    _log "triage: validator PASS for slug=$slug — item forwarded to overseer inbox"
    # Clean up triaged file (validator already forwarded it)
    rm -f "$triaged_file" "$cleared_marker" 2>/dev/null || true
  elif [ -f "$rejected_file" ]; then
    validator_result="quarantine"
    _log "triage: validator QUARANTINE for slug=$slug — see $rejected_file"
    _notify info "Stakeholder-Item quarantined: $slug" \
      "see ${rejected_file}"
    # Clean up triaged file (quarantined)
    rm -f "$triaged_file" 2>/dev/null || true
  else
    # Validator produced no recognisable output — treat as quarantine by default
    validator_result="unknown-quarantine"
    _log "triage: validator produced no output for slug=$slug — treating as quarantine"
    _audit "triage_validator_no_output" "$slug" "expected cleared or rejected marker"
  fi

  _audit "triage_validated" "$slug" "$validator_result"

  # Move original inbox item to processed
  mv "$inbox_file" "${STAKEHOLDER_PROCESSED_DIR}/${slug}.md" 2>/dev/null || \
    { cp "$inbox_file" "${STAKEHOLDER_PROCESSED_DIR}/${slug}.md" && rm -f "$inbox_file"; } || true

  return 0
}

# _run_stakeholder_triage_sweep
# Processes all items in stakeholder/inbox/ (max 1 per second — rate limit).
# Called from process_pool_iteration when triage interval has elapsed.
_run_stakeholder_triage_sweep() {
  local now
  now="$(date +%s)"

  # Check if triage interval has elapsed
  local last=0
  if [ -f "$TRIAGE_LAST_RUN_FILE" ]; then
    last="$(cat "$TRIAGE_LAST_RUN_FILE" 2>/dev/null || echo 0)"
  fi

  local elapsed=$(( now - last ))
  if (( elapsed < TRIAGE_INTERVAL )); then
    return 0  # not yet time for next sweep
  fi

  # Update last-run timestamp
  printf '%s' "$now" > "$TRIAGE_LAST_RUN_FILE"

  # Find all inbox items
  local inbox_files=()
  if compgen -G "${STAKEHOLDER_INBOX_DIR}/*.md" >/dev/null 2>&1; then
    while IFS= read -r -d '' f; do
      inbox_files+=("$f")
    done < <(find "$STAKEHOLDER_INBOX_DIR" -maxdepth 1 -name '*.md' -print0 2>/dev/null)
  fi

  if [ "${#inbox_files[@]}" -eq 0 ]; then
    return 0  # nothing to do
  fi

  # Sort by mtime ascending (oldest first), then cap at 5 per iteration
  local sorted_files=()
  while IFS= read -r f; do
    sorted_files+=("$f")
  done < <(
    for f in "${inbox_files[@]}"; do
      # macOS: stat -f %m; Linux: stat -c %Y
      local mtime
      if mtime="$(stat -f %m "$f" 2>/dev/null)"; then
        :
      elif mtime="$(stat -c %Y "$f" 2>/dev/null)"; then
        :
      else
        mtime=0
      fi
      printf '%s\t%s\n' "$mtime" "$f"
    done | sort -n | awk -F'\t' '{print $2}'
  )

  local cap=5
  local processed=0

  _log "triage-sweep: found ${#inbox_files[@]} item(s) in stakeholder inbox (cap=$cap per iteration)"

  for inbox_file in "${sorted_files[@]}"; do
    [ -f "$inbox_file" ] || continue
    if (( processed >= cap )); then
      _log "triage-sweep: cap=$cap reached — deferring remaining items to next iteration"
      break
    fi

    # Rate-limit: 1 triage per second
    _run_stakeholder_triage_pipeline "$inbox_file" || true
    processed=$(( processed + 1 ))
    sleep 1
  done
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
# Worker-Pool helpers (P2-1)
# ---------------------------------------------------------------------------

# _pool_pid_file <pid> → path to PID state file
_pool_pid_file() { printf '%s/%s.pid' "$WORKERS_STATE_DIR" "$1"; }

# _pool_exit_file <pid> → path to exit-code file written by worker on EXIT
_pool_exit_file() { printf '%s/%s.exit' "$WORKERS_STATE_DIR" "$1"; }

# _pool_write_pid_file <pid> <slug> <item_path> <worktree>
# Writes JSON state file for a running worker.
_pool_write_pid_file() {
  local pid="$1" slug="$2" item_path="$3" worktree="$4"
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local pidfile
  pidfile="$(_pool_pid_file "$pid")"
  printf '{"pid":%s,"slug":"%s","item_path":"%s","worktree":"%s","started":"%s"}\n' \
    "$pid" "$slug" "$item_path" "$worktree" "$ts" > "$pidfile"
}

# _pool_active_count → echo number of workers whose PID is still alive
_pool_active_count() {
  local count=0
  if compgen -G "${WORKERS_STATE_DIR}/*.pid" >/dev/null 2>&1; then
    for pidfile in "${WORKERS_STATE_DIR}/"*.pid; do
      [ -f "$pidfile" ] || continue
      local pid
      pid="$(python3 -c "import sys,json; d=json.load(open(sys.argv[1])); print(d['pid'])" "$pidfile" 2>/dev/null || true)"
      [[ "$pid" =~ ^[0-9]+$ ]] || continue
      if kill -0 "$pid" 2>/dev/null; then
        count=$(( count + 1 ))
      fi
    done
  fi
  echo "$count"
}

# _pool_reap — check all PID-files, reap finished workers.
# For each finished worker: reads exit-code from .exit file (or assumes 1),
# calls release_item + worktree_remove, writes audit, removes state files.
_pool_reap() {
  if ! compgen -G "${WORKERS_STATE_DIR}/*.pid" >/dev/null 2>&1; then
    return 0
  fi

  for pidfile in "${WORKERS_STATE_DIR}/"*.pid; do
    [ -f "$pidfile" ] || continue

    # Parse state
    local pid slug item_path worktree
    pid="$(python3 -c "import sys,json; d=json.load(open(sys.argv[1])); print(d['pid'])" "$pidfile" 2>/dev/null || true)"
    slug="$(python3 -c "import sys,json; d=json.load(open(sys.argv[1])); print(d['slug'])" "$pidfile" 2>/dev/null || true)"
    item_path="$(python3 -c "import sys,json; d=json.load(open(sys.argv[1])); print(d['item_path'])" "$pidfile" 2>/dev/null || true)"
    worktree="$(python3 -c "import sys,json; d=json.load(open(sys.argv[1])); print(d['worktree'])" "$pidfile" 2>/dev/null || true)"

    if [[ ! "$pid" =~ ^[0-9]+$ ]]; then
      # Malformed pid-file — clean up
      rm -f "$pidfile"
      continue
    fi

    # Still running? Skip.
    if kill -0 "$pid" 2>/dev/null; then
      continue
    fi

    # Worker finished — read exit code from .exit file.
    # The renamer subshell (spawned by _pool_spawn) has up to 5s to move the
    # uuid temp file to <pid>.exit. Give it a 1s grace period before defaulting
    # to code=1 (which would incorrectly move the item to failed/).
    local exitfile code
    exitfile="$(_pool_exit_file "$pid")"
    code=1  # safe default
    if [ ! -f "$exitfile" ]; then
      # Brief grace period: poll up to 1s for the renamer to deliver the exit file.
      local grace_deadline=$(( $(date +%s) + 1 ))
      while [ "$(date +%s)" -lt "$grace_deadline" ]; do
        sleep 0.1
        if [ -f "$exitfile" ]; then break; fi
      done
    fi
    if [ -f "$exitfile" ]; then
      local raw
      raw="$(cat "$exitfile" 2>/dev/null || true)"
      if [[ "$raw" =~ ^[0-9]+$ ]]; then
        code="$raw"
      fi
    fi

    _log "reap: pid=$pid slug=${slug:-?} exit=$code exitfile=$exitfile exitfile_exists=$([ -f "$exitfile" ] && echo yes || echo no)"

    # Release item (same logic as original process_one_iteration)
    if [ -n "$item_path" ] && [ -n "$slug" ] && command -v release_item >/dev/null 2>&1; then
      case "$code" in
        0)
          release_item "$item_path" done >/dev/null 2>&1 || true
          _audit "process_complete" "$slug" "exit=0 (pool-reap)"
          # P3-7: success → reset consecutive-failure counter
          if command -v record_worker_success >/dev/null 2>&1; then
            record_worker_success "$slug" 2>/dev/null || true
          fi
          ;;
        1)
          release_item "$item_path" failed >/dev/null 2>&1 || true
          _audit "process_complete" "$slug" "exit=1 (pool-reap)"
          _notify info "Overseer: item failed" "slug=$slug"
          # P3-7: failure → increment counter (may trigger panic)
          if command -v record_worker_failure >/dev/null 2>&1; then
            record_worker_failure "$slug" "$code" 2>/dev/null || true
          fi
          ;;
        3)
          release_item "$item_path" blocked-pre-ship >/dev/null 2>&1 || true
          _audit "process_complete" "$slug" "exit=3 blocked-pre-ship (pool-reap)"
          _notify info "Overseer: pre-ship blocked" "slug=$slug"
          # P3-7: exit 3 is a user/pre-ship issue — do NOT increment failure counter
          ;;
        2)
          # Worker requests PANIC — also record for bookkeeping (no double-trigger
          # since enter_panic writes the marker first, then record_worker_failure
          # sees the marker and skips re-enter).
          printf 'PANIC: worker exit 2 at %s (slug=%s pid=%s)\n' \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$slug" "$pid" > "$PANIC_MARKER"
          local slug_clean
          slug_clean="$(_slug_from_inprogress "$item_path")"
          mv "$item_path" "${INBOX_DIR}/${slug_clean}.md" 2>/dev/null || true
          _audit "panic_from_worker" "$slug" "exit=2 PANIC marker written (pool-reap)"
          _notify critical "Overseer: PANIC from worker" "slug=$slug"
          # P3-7: bookkeeping only — PANIC marker already set above
          if command -v record_worker_failure >/dev/null 2>&1; then
            record_worker_failure "$slug" "$code" 2>/dev/null || true
          fi
          ;;
        124)
          release_item "$item_path" failed >/dev/null 2>&1 || true
          _audit "process_complete" "$slug" "exit=124 timeout (pool-reap)"
          _notify info "Overseer: worker timeout" "slug=$slug"
          # P3-7: timeout counts as failure
          if command -v record_worker_failure >/dev/null 2>&1; then
            record_worker_failure "$slug" "$code" 2>/dev/null || true
          fi
          ;;
        *)
          release_item "$item_path" failed >/dev/null 2>&1 || true
          _audit "process_complete" "$slug" "exit=$code (pool-reap)"
          _notify info "Overseer: worker abnormal exit" "slug=$slug exit=$code"
          # P3-7: any other non-zero exit counts as failure
          if command -v record_worker_failure >/dev/null 2>&1; then
            record_worker_failure "$slug" "$code" 2>/dev/null || true
          fi
          ;;
      esac
    fi

    # Cleanup worktree
    if [ -n "$slug" ] && command -v worktree_remove >/dev/null 2>&1; then
      worktree_remove "$slug" >/dev/null 2>&1 || true
    fi

    # Remove state files
    rm -f "$pidfile" "$exitfile"
  done
}

# _pool_disk_panic → returns 0 (panic) if health.json is fresh and panic=true,
# returns 1 (no panic / unknown) otherwise.
_pool_disk_panic() {
  [ -f "$HEALTH_JSON" ] || return 1
  local mtime now age
  # macOS: stat -f %m; Linux: stat -c %Y
  if mtime="$(stat -f %m "$HEALTH_JSON" 2>/dev/null)"; then
    : # macOS
  elif mtime="$(stat -c %Y "$HEALTH_JSON" 2>/dev/null)"; then
    : # Linux
  else
    return 1
  fi
  now="$(date +%s)"
  age=$(( now - mtime ))
  if (( age > HEALTH_JSON_STALE_TTL )); then
    return 1  # stale — don't block on stale data
  fi
  # Check panic field
  local panic_val
  panic_val="$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('panic','false'))" \
    "$HEALTH_JSON" 2>/dev/null || true)"
  if [[ "$panic_val" == "True" ]] || [[ "$panic_val" == "true" ]]; then
    return 0  # panic!
  fi
  return 1  # no panic
}

# _pool_spawn <item_path> <slug>
# Creates worktree, spawns worker.sh in background, records PID-file.
# Returns 0 on successful spawn, non-zero on error.
_pool_spawn() {
  local item_path="$1" slug="$2"

  # Disk-watchdog-pause: check health.json before worktree_create
  if _pool_disk_panic; then
    _log "disk-panic in health.json — skipping spawn for slug=$slug"
    _audit "spawn_skipped" "$slug" "disk-watchdog panic"
    # Return item to inbox
    if command -v release_item >/dev/null 2>&1; then
      release_item "$item_path" failed >/dev/null 2>&1 || true
    fi
    return 1
  fi

  # Derive worktree-compatible short slug (strip priority-prefix + truncate).
  local wt_slug
  wt_slug="$(_worktree_slug_from_inprogress "$item_path")"

  # Create worktree
  local worktree_path
  set +e
  worktree_path="$(worktree_create "$wt_slug" 2>&1)"
  local wt_rc=$?
  set -e

  if [ "$wt_rc" -ne 0 ]; then
    _log "worktree_create failed (rc=$wt_rc): $worktree_path slug=$slug wt_slug=$wt_slug"
    _audit "worktree_failed" "$slug" "rc=$wt_rc out=$worktree_path"
    _notify info "Overseer: worktree create failed" "slug=$slug rc=$wt_rc"
    if command -v release_item >/dev/null 2>&1; then
      release_item "$item_path" failed >/dev/null 2>&1 || true
    fi
    return 1
  fi
  # worktree_create may print warnings prepended; take last non-empty line
  worktree_path="$(printf '%s' "$worktree_path" | awk 'NF{l=$0} END{print l}')"

  # Resolve item-level timeout
  local timeout_min timeout_sec
  timeout_min="$(_fm_field "$item_path" "timeout_minutes")"
  if [[ "$timeout_min" =~ ^[0-9]+$ ]]; then
    timeout_sec=$(( timeout_min * 60 ))
  else
    timeout_sec="$WORKER_TIMEOUT_DEFAULT"
  fi

  local needs_gh
  needs_gh="$(_fm_field "$item_path" "needs_gh")"

  # Spawn worker as background job.
  # Exit-code strategy: use a UUID-named temp file, rename to <pid>.exit after fork.
  # This avoids BASHPID issues in subshells on macOS.
  local workers_state_dir="$WORKERS_STATE_DIR"
  local repo_root="$REPO_ROOT"
  local uuid_exitfile
  uuid_exitfile="${workers_state_dir}/_tmp_$(date +%s%N 2>/dev/null || date +%s)_${RANDOM}.exit.tmp"

  (
    export OVERSEER_WORKER_PID=$$
    export HEADLESS_MODE=1
    export CLAUDE_PROJECT_DIR="$worktree_path"
    export COST_CAP_LEDGER_DIR="${repo_root}/.claude/overseer"
    export REPO_ROOT="$repo_root"
    if [ "${needs_gh:-false}" != "true" ]; then
      unset GH_TOKEN
    fi

    # Run worker with timeout watchdog
    bash "$WORKER_SH" "$item_path" "$worktree_path" &
    local inner_pid=$!

    local deadline=$(( $(date +%s) + timeout_sec ))
    local rc=0
    while kill -0 "$inner_pid" 2>/dev/null; do
      if (( $(date +%s) >= deadline )); then
        kill -TERM "$inner_pid" 2>/dev/null || true
        sleep 2
        kill -KILL "$inner_pid" 2>/dev/null || true
        wait "$inner_pid" 2>/dev/null || true
        rc=124
        break
      fi
      sleep 1
    done
    if [ "$rc" -eq 0 ]; then
      set +e
      wait "$inner_pid"
      rc=$?
      set -e
    fi

    # Write exit-code to UUID temp file; overseer renames it after fork.
    printf '%s\n' "$rc" > "$uuid_exitfile" 2>/dev/null || true
    # shellcheck disable=SC2030
    printf '[worker-wrapper pid=%d] wrote rc=%s to uuid_file=%s\n' "$$" "$rc" "$uuid_exitfile" >&2 2>/dev/null || true
    exit "$rc"
  ) &
  local worker_pid=$!

  # Rename UUID temp exit file to <pid>.exit so reaper finds it.
  # (We do this after fork, so worker_pid is known.)
  local final_exitfile
  final_exitfile="$(_pool_exit_file "$worker_pid")"
  # Rename happens in background — must outlive the worker so the file
  # actually appears (worker writes uuid_exitfile only at its own exit).
  # Wait until worker_pid is gone OR worker timeout + 60s elapses.
  (
    local hard_deadline=$(( $(date +%s) + timeout_sec + 60 ))
    while (( $(date +%s) < hard_deadline )); do
      if [ -f "$uuid_exitfile" ]; then
        mv "$uuid_exitfile" "$final_exitfile" 2>/dev/null || true
        exit 0
      fi
      # Worker dead and no uuid file → it crashed before writing; let reaper default to 1.
      if ! kill -0 "$worker_pid" 2>/dev/null; then
        # Give a tiny grace window for filesystem visibility after worker exit.
        sleep 0.5
        if [ -f "$uuid_exitfile" ]; then
          mv "$uuid_exitfile" "$final_exitfile" 2>/dev/null || true
        fi
        exit 0
      fi
      sleep 1
    done
  ) &

  # Register PID-file immediately so reaper can track it
  mkdir -p "$WORKERS_STATE_DIR"
  _pool_write_pid_file "$worker_pid" "$slug" "$item_path" "$worktree_path"

  _log "spawned: pid=$worker_pid slug=$slug timeout=${timeout_sec}s"
  _audit "spawn" "$slug" "pid=$worker_pid worktree=$worktree_path"
  return 0
}

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

# _worktree_slug_from_inprogress <path>
# Same as _slug_from_inprogress but trimmed for worktree-create:
# - strips priority-prefix (00-followup-, 01-stakeholder-, 02-analyzer-).
# - truncates to 30 chars (worktree.sh slug-regex limit ^[a-z0-9][a-z0-9-]{0,30}$).
# - strips trailing hyphens after truncation.
_worktree_slug_from_inprogress() {
  local full
  full="$(_slug_from_inprogress "$1")"
  # Strip known priority-prefixes (NN-name-)
  full="$(printf '%s' "$full" | sed -E 's/^(00-followup-|01-stakeholder-|02-analyzer-)//')"
  # Truncate to 31 chars (1 leading + 30 trailing as per worktree.sh regex)
  full="${full:0:31}"
  # Strip trailing hyphens so we don't end with -
  printf '%s' "$full" | sed 's/-*$//'
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
# process_one_iteration: legacy single-worker wrapper (used by --once mode).
# Pre-flight, pick, spawn, wait inline. Returns:
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

  # Derive worktree-compatible short slug
  local wt_slug
  wt_slug="$(_worktree_slug_from_inprogress "$item_path")"

  # Worktree create
  local worktree_path
  set +e
  worktree_path="$(worktree_create "$wt_slug" 2>&1)"
  local wt_rc=$?
  set -e

  if [ "$wt_rc" -ne 0 ]; then
    _log "worktree_create failed (rc=$wt_rc): $worktree_path wt_slug=$wt_slug"
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
      # P3-7: success → reset consecutive-failure counter
      if command -v record_worker_success >/dev/null 2>&1; then
        record_worker_success "$slug" 2>/dev/null || true
      fi
      ;;
    1)
      release_item "$item_path" failed >/dev/null 2>&1 || true
      _audit "process_complete" "$slug" "exit=1 (failed)"
      _notify info "Overseer: item failed" "slug=$slug"
      # P3-7: failure → increment counter (may trigger panic)
      if command -v record_worker_failure >/dev/null 2>&1; then
        record_worker_failure "$slug" "$code" 2>/dev/null || true
      fi
      ;;
    3)
      # Worker: pre-ship gates blocked (Mitigation 15). Item back to inbox
      # with [blocked-pre-ship] marker — NOT failed/.
      release_item "$item_path" blocked-pre-ship >/dev/null 2>&1 || true
      _audit "process_complete" "$slug" "exit=3 (blocked-pre-ship)"
      _notify info "Overseer: pre-ship blocked" "slug=$slug — returned to inbox with [blocked-pre-ship] marker"
      # P3-7: exit 3 is a user/pre-ship issue — do NOT increment failure counter
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
      # P3-7: bookkeeping only — PANIC marker already set above
      if command -v record_worker_failure >/dev/null 2>&1; then
        record_worker_failure "$slug" "$code" 2>/dev/null || true
      fi
      ;;
    124)
      release_item "$item_path" failed >/dev/null 2>&1 || true
      _audit "process_complete" "$slug" "exit=124 (timeout)"
      _notify info "Overseer: worker timeout" "slug=$slug"
      # P3-7: timeout counts as failure
      if command -v record_worker_failure >/dev/null 2>&1; then
        record_worker_failure "$slug" "$code" 2>/dev/null || true
      fi
      ;;
    *)
      release_item "$item_path" failed >/dev/null 2>&1 || true
      _audit "process_complete" "$slug" "exit_code=$code"
      _notify info "Overseer: worker abnormal exit" "slug=$slug exit=$code"
      # P3-7: any other non-zero exit counts as failure
      if command -v record_worker_failure >/dev/null 2>&1; then
        record_worker_failure "$slug" "$code" 2>/dev/null || true
      fi
      ;;
  esac

  # Cleanup worktree
  if command -v worktree_remove >/dev/null 2>&1; then
    worktree_remove "$slug" >/dev/null 2>&1 || true
  fi

  return 0
}

# ---------------------------------------------------------------------------
# process_pool_iteration (P2-1): one tick of the N-worker pool loop.
# Reaps finished workers, then fills open slots with new items.
# Returns:
#   0 → at least one worker active or an item was spawned (not fully idle).
#   1 → no active workers AND inbox empty (fully idle).
# ---------------------------------------------------------------------------
process_pool_iteration() {
  # 0. Reap finished workers FIRST — before pre-flight's recover_orphaned_items
  # sees stale in_progress files (files with the previous overseer's PID).
  # Without this, orphan-recovery re-queues items that the pool already owns.
  _pool_reap

  # 1. Pre-flight
  if ! _pre_flight; then
    _log "pre-flight idle: $PRE_FLIGHT_REASON"
    _audit "pre_flight_idle" "overseer" "$PRE_FLIGHT_REASON"
    # Reap again in case a worker finished during pre-flight
    _pool_reap
    return 1
  fi

  # 1b. Stakeholder-triage sub-tick (P2-4): run every TRIAGE_INTERVAL seconds.
  # Runs independently of worker-pool state — even when pool is full.
  _run_stakeholder_triage_sweep || true

  # 2. Reap finished workers (second pass: catches workers that finished between
  #    step 0 and now, e.g. during pre-flight's oauth check or watchdog call).
  _pool_reap

  # Check for PANIC after reap (worker exit 2 may have written it)
  if [ -f "$PANIC_MARKER" ]; then
    _log "PANIC marker present after reap — idling"
    return 1
  fi

  if ! command -v pick_next_item >/dev/null 2>&1; then
    _log "ERROR: picker library not loaded"
    return 1
  fi

  # 3. Fill open slots
  local active
  active="$(_pool_active_count)"
  local spawned=0

  while (( active < POOL_MAX_WORKERS )); do
    # Re-check PANIC before each spawn attempt
    if [ -f "$PANIC_MARKER" ]; then
      _log "PANIC marker — stopping spawn loop"
      break
    fi

    # Pick next item
    local item_path
    set +e
    item_path="$(pick_next_item "$$" 2>/dev/null)"
    local pick_rc=$?
    set -e

    if [ "$pick_rc" -ne 0 ] || [ -z "$item_path" ] || [ ! -f "$item_path" ]; then
      # Nothing to pick right now
      break
    fi

    local slug
    slug="$(_slug_from_inprogress "$item_path")"
    _log "picked: $slug (pool slot $((active + 1))/$POOL_MAX_WORKERS)"
    _audit "pick" "$slug" "in_progress=$item_path pool_active=$active"

    if _pool_spawn "$item_path" "$slug"; then
      spawned=$(( spawned + 1 ))
      active=$(( active + 1 ))
    else
      # spawn failed — slot not taken, stop trying this tick
      break
    fi
  done

  # 4. Determine idle status
  local final_active
  final_active="$(_pool_active_count)"

  # Check inbox non-empty
  local has_inbox=0
  if compgen -G "${INBOX_DIR}/*.md" >/dev/null 2>&1; then
    has_inbox=1
  fi

  if (( final_active == 0 )) && (( has_inbox == 0 )); then
    return 1  # fully idle
  fi
  return 0  # work in progress or more items available
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

  # Current items in progress
  local count=0
  if compgen -G "${INPROGRESS_DIR}/*.md" >/dev/null 2>&1; then
    for f in "${INPROGRESS_DIR}"/*.md; do
      count=$((count + 1))
    done
  fi
  printf '  in_progress      = %d item(s)\n' "$count"
  printf '  worker_pool_max  = %d (POOL_MAX_WORKERS)\n' "${POOL_MAX_WORKERS:-2}"
  printf '  active_workers   = %d\n' "$(_pool_active_count 2>/dev/null || echo '?')"

  printf '  STOP marker      = %s\n' "$([ -f "$STOP_MARKER" ] && echo present || echo absent)"
  printf '  PANIC marker     = %s\n' "$([ -f "$PANIC_MARKER" ] && echo present || echo absent)"
  printf '  AUTH_EXPIRED     = %s\n' "$([ -f "$AUTH_EXPIRED_MARKER" ] && echo present || echo absent)"
  printf '  COST_CAP_REACHED = %s\n' "$([ -f "$COST_CAP_MARKER" ] && echo present || echo absent)"

  # Stakeholder-triage state (P2-4)
  local sh_inbox=0
  if compgen -G "${STAKEHOLDER_INBOX_DIR}/*.md" >/dev/null 2>&1; then
    sh_inbox="$(find "$STAKEHOLDER_INBOX_DIR" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
  fi
  printf '  stakeholder_inbox = %d item(s)\n' "$sh_inbox"
  printf '  triage_interval  = %ss\n' "${TRIAGE_INTERVAL}"
  local last_triage=never
  if [ -f "$TRIAGE_LAST_RUN_FILE" ]; then
    local lt_ts
    lt_ts="$(cat "$TRIAGE_LAST_RUN_FILE" 2>/dev/null || echo 0)"
    if [[ "$lt_ts" =~ ^[0-9]+$ ]]; then
      local age=$(( $(date +%s) - lt_ts ))
      last_triage="${age}s ago"
    fi
  fi
  printf '  last_triage_sweep= %s\n' "$last_triage"
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
_log "worker-pool: max=${POOL_MAX_WORKERS}"

if [ "$MODE" = "once" ]; then
  process_pool_iteration || true
  _audit "stop" "overseer" "mode=once"
  exit 0
fi

# ---------------------------------------------------------------------------
# daemon loop (P2-1: N-worker pool)
# ---------------------------------------------------------------------------
_log "overseer daemon starting"
while [ "$SHUTDOWN_REQUESTED" -eq 0 ]; do
  # Cloud-Heartbeat (P3-12): fire ping every HEARTBEAT_INTERVAL seconds.
  _now="$(date +%s)"
  if (( _now - _last_heartbeat_ts >= HEARTBEAT_INTERVAL )); then
    if [ -x "$HEARTBEAT_PING_SH" ]; then
      REPO_ROOT="$REPO_ROOT" bash "$HEARTBEAT_PING_SH" >/dev/null 2>&1 || true
    fi
    _last_heartbeat_ts="$_now"
  fi

  iter_rc=0
  process_pool_iteration || iter_rc=$?
  # Defensive: process_pool_iteration mutates `set -e` internally (line ~1212);
  # ensure errexit is back on for the loop body's other commands.
  set -e

  if [ "$iter_rc" -eq 1 ]; then
    sleep "$SLEEP_IDLE"
  else
    sleep "$SLEEP_BETWEEN"
  fi
done

_audit "stop" "overseer" "graceful loop exit"
exit 0
