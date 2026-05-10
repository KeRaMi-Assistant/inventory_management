#!/usr/bin/env bash
# analyzer.sh — Analyzer-Daemon: runs all analyzer modules once per iteration.
#
# Usage:
#   analyzer.sh --once    # single iteration, then exit (default for LaunchAgent)
#   analyzer.sh --daemon  # long-running loop (sleep 3600 between iterations)
#   analyzer.sh --status  # print last-run info from state
#
# Modules run sequentially:
#   1. scan-tech-debt.sh
#   2. scan-l10n-drift.sh
#   3. scan-failure-lessons-expiry.sh
#
# Pre-flight checks per iteration:
#   STOP / PANIC / COST_CAP_REACHED → idle
#   ANALYZER_PAUSE (watchdog: inbox > 50) → idle
#   AUTH_EXPIRED → idle
#   cost_check_or_die $ANALYZER_CAP_TODAY $ANALYZER_CAP_WEEK → idle on hit
#
# IMPORTANT: This file is in the Self-Mod-Blocklist (P0-0).

set -uo pipefail

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

OVERSEER_DIR="${ROOT}/.claude/overseer"
ANALYZER_DIR="${ROOT}/.claude/analyzer"
STATE_FILE="${ANALYZER_DIR}/state/analyzer-daemon.json"
LOG_PREFIX="[analyzer]"

# Marker paths (shared with overseer/watchdog)
STOP_MARKER="${OVERSEER_DIR}/STOP"
PANIC_MARKER="${OVERSEER_DIR}/PANIC"
COST_CAP_MARKER="${OVERSEER_DIR}/COST_CAP_REACHED"
AUTH_EXPIRED_MARKER="${OVERSEER_DIR}/AUTH_EXPIRED"
ANALYZER_PAUSE_MARKER="${OVERSEER_DIR}/ANALYZER_PAUSE"

# Caps (can be overridden via env)
ANALYZER_CAP_TODAY="${ANALYZER_CAP_TODAY:-5}"
ANALYZER_CAP_WEEK="${ANALYZER_CAP_WEEK:-30}"

# Daemon sleep interval
DAEMON_SLEEP="${ANALYZER_DAEMON_SLEEP:-3600}"

# Libraries — prefer ROOT-relative paths so sandbox overrides work via ROOT.
# COST_CAP_SH / AUDIT_SH / NOTIFY_SH can also be overridden via env for tests.
COST_CAP_SH="${ANALYZER_COST_CAP_SH:-${ROOT}/.claude/scripts/lib/cost-cap.sh}"
AUDIT_SH="${ANALYZER_AUDIT_SH:-${ROOT}/.claude/scripts/lib/audit.sh}"
NOTIFY_SH="${ANALYZER_NOTIFY_SH:-${ROOT}/.claude/scripts/notify.sh}"

# Modules
MODULE_DIR="${ANALYZER_DIR}/modules"
MODULES=(
  "scan-tech-debt.sh"
  "scan-l10n-drift.sh"
  "scan-failure-lessons-expiry.sh"
)

# ---------------------------------------------------------------------------
# CLI args
# ---------------------------------------------------------------------------
MODE="once"  # default
for arg in "$@"; do
  case "$arg" in
    --once)   MODE="once"   ;;
    --daemon) MODE="daemon" ;;
    --status) MODE="status" ;;
    *)
      printf '%s Unknown argument: %s\n' "$LOG_PREFIX" "$arg" >&2
      printf 'Usage: %s [--once|--daemon|--status]\n' "$(basename "$0")" >&2
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
_iso_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

_log() { printf '%s %s\n' "$LOG_PREFIX" "$*"; }

_audit() {
  if [ -f "$AUDIT_SH" ]; then
    # shellcheck source=/dev/null
    source "$AUDIT_SH" 2>/dev/null || true
    audit_record "analyzer" "${1:-info}" "${2:-}" "${3:-}" 2>/dev/null || true
  fi
}

_notify() {
  local level="$1" title="$2" msg="${3:-}"
  if [ -f "$NOTIFY_SH" ]; then
    REPO_ROOT="$ROOT" bash "$NOTIFY_SH" "$level" "analyzer" "$title" "$msg" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# State helpers
# ---------------------------------------------------------------------------
_load_state() {
  if [ -f "$STATE_FILE" ]; then
    cat "$STATE_FILE"
  else
    printf '{"last_run":null,"last_run_status":null,"runs_total":0}\n'
  fi
}

_save_state() {
  local status="$1"
  mkdir -p "$(dirname "$STATE_FILE")"
  local now
  now="$(_iso_now)"
  python3 - "$STATE_FILE" "$now" "$status" <<'PYEOF'
import sys, json, os

state_file, now, status = sys.argv[1], sys.argv[2], sys.argv[3]

d = {}
if os.path.exists(state_file):
    try:
        with open(state_file) as f:
            d = json.load(f)
    except Exception:
        d = {}

d['last_run'] = now
d['last_run_status'] = status
d['runs_total'] = d.get('runs_total', 0) + 1

with open(state_file, 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
PYEOF
}

# ---------------------------------------------------------------------------
# Status mode
# ---------------------------------------------------------------------------
if [ "$MODE" = "status" ]; then
  _log "status:"
  if [ -f "$STATE_FILE" ]; then
    cat "$STATE_FILE"
  else
    printf '{"last_run":null,"last_run_status":null,"runs_total":0}\n'
  fi
  _log "markers:"
  for marker in "$STOP_MARKER" "$PANIC_MARKER" "$COST_CAP_MARKER" "$AUTH_EXPIRED_MARKER" "$ANALYZER_PAUSE_MARKER"; do
    name="$(basename "$marker")"
    if [ -f "$marker" ]; then
      printf '  %-25s PRESENT\n' "$name"
    else
      printf '  %-25s absent\n' "$name"
    fi
  done
  exit 0
fi

# ---------------------------------------------------------------------------
# Source cost-cap library
# ---------------------------------------------------------------------------
if [ -f "$COST_CAP_SH" ]; then
  # shellcheck source=/dev/null
  source "$COST_CAP_SH"
else
  _log "WARNING: cost-cap.sh not found at $COST_CAP_SH — cost checks disabled"
  # Provide no-op stubs
  cost_check_or_die() { return 0; }
  cost_record() { return 0; }
fi

# ---------------------------------------------------------------------------
# Pre-flight check: returns 0 if OK to run, 1 if should idle
# ---------------------------------------------------------------------------
_preflight() {
  # 1. STOP marker
  if [ -f "$STOP_MARKER" ]; then
    _log "IDLE: STOP marker present"
    return 1
  fi

  # 2. PANIC marker
  if [ -f "$PANIC_MARKER" ]; then
    _log "IDLE: PANIC marker present"
    return 1
  fi

  # 3. COST_CAP_REACHED marker
  if [ -f "$COST_CAP_MARKER" ]; then
    _log "IDLE: COST_CAP_REACHED marker present"
    return 1
  fi

  # 4. ANALYZER_PAUSE (watchdog: inbox overflow)
  if [ -f "$ANALYZER_PAUSE_MARKER" ]; then
    _log "IDLE: ANALYZER_PAUSE marker present (inbox > 50)"
    return 1
  fi

  # 5. AUTH_EXPIRED
  if [ -f "$AUTH_EXPIRED_MARKER" ]; then
    _log "IDLE: AUTH_EXPIRED marker present"
    return 1
  fi

  # 6. Cost-cap check
  if ! cost_check_or_die "$ANALYZER_CAP_TODAY" "$ANALYZER_CAP_WEEK"; then
    _log "IDLE: cost cap hit (today=$ANALYZER_CAP_TODAY week=$ANALYZER_CAP_WEEK)"
    _notify info "Analyzer: Cost Cap Hit" \
      "today_cap=${ANALYZER_CAP_TODAY} week_cap=${ANALYZER_CAP_WEEK}"
    _audit "cost_cap_idle" "preflight" "cap today=$ANALYZER_CAP_TODAY week=$ANALYZER_CAP_WEEK"
    return 1
  fi

  return 0
}

# ---------------------------------------------------------------------------
# Run one iteration: pre-flight + run all modules
# ---------------------------------------------------------------------------
_run_iteration() {
  local iteration_ts
  iteration_ts="$(_iso_now)"
  _log "iteration start at $iteration_ts"
  _audit "iteration_start" "analyzer" "ts=$iteration_ts"

  # Pre-flight
  if ! _preflight; then
    _audit "iteration_skip" "analyzer" "preflight failed — idle"
    return 0
  fi

  # Heartbeat cost record (even though modules are bash-only, record presence)
  cost_record "analyzer-tick" "0.001" 2>/dev/null || true

  local modules_ok=0
  local modules_fail=0

  for module_name in "${MODULES[@]}"; do
    local module_path="${MODULE_DIR}/${module_name}"

    # Check module exists (allow PATH-override stubs in tests)
    local actual_cmd="$module_path"
    if command -v "$module_name" >/dev/null 2>&1 && [ ! -f "$module_path" ]; then
      actual_cmd="$module_name"
    fi

    _audit "module_start" "analyzer" "module=$module_name"
    _log "running module: $module_name"

    # Run module, capture output + exit code
    local module_output
    local module_rc=0
    module_output="$(CLAUDE_PROJECT_DIR="$ROOT" bash "$actual_cmd" 2>&1)" || module_rc=$?

    # Parse item count from module output (look for "Items generated: N" or "items=N")
    local item_count=0
    if printf '%s' "$module_output" | grep -qiE 'items generated: [0-9]+|items=[0-9]+|item.*written'; then
      item_count="$(printf '%s' "$module_output" \
        | grep -oiE 'items generated: [0-9]+|items=[0-9]+' \
        | grep -oE '[0-9]+' | tail -1 || echo 0)"
    fi

    if [ "$module_rc" -eq 0 ]; then
      _log "module done: $module_name (exit=0 items=${item_count:-0})"
      _audit "module_complete" "analyzer" "module=$module_name exit=0 items=${item_count:-0}"
      modules_ok=$(( modules_ok + 1 ))
    else
      _log "module FAILED: $module_name (exit=$module_rc)"
      _audit "module_fail" "analyzer" "module=$module_name exit=$module_rc items=${item_count:-0}"
      _notify info "Analyzer: Module Failed" \
        "module=$module_name exit=$module_rc"
      modules_fail=$(( modules_fail + 1 ))
      # Continue to next module (non-blocking)
    fi

    # Print module output for log capture
    if [ -n "$module_output" ]; then
      printf '%s\n' "$module_output" | sed "s/^/$LOG_PREFIX [$module_name] /"
    fi
  done

  local run_status="ok"
  [ "$modules_fail" -gt 0 ] && run_status="partial_fail(${modules_fail})"

  _save_state "$run_status"
  _audit "iteration_complete" "analyzer" \
    "modules_ok=$modules_ok modules_fail=$modules_fail status=$run_status"
  _log "iteration complete — ok=$modules_ok fail=$modules_fail status=$run_status"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
case "$MODE" in
  once)
    _run_iteration
    ;;
  daemon)
    _log "daemon mode started (sleep=${DAEMON_SLEEP}s between iterations)"
    while true; do
      _run_iteration
      _log "sleeping ${DAEMON_SLEEP}s until next iteration..."
      sleep "$DAEMON_SLEEP"
    done
    ;;
esac
