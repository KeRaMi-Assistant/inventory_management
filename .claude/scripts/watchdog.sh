#!/usr/bin/env bash
# watchdog.sh — Resource-Watchdog for the Autonomous Council Swarm (P0-5).
#
# Usage:
#   watchdog.sh           — daemon-loop (every 300s)
#   watchdog.sh --once    — single iteration, then exit
#   watchdog.sh --status  — print health.json, exit 0 if ok, exit 1 if panic
#
# Checks per iteration:
#   1. Disk free  (< 15% or < 10 GB → warn; < 5% or < 5 GB → critical)
#   2. Worktree count  (> 3 → warn)
#   3. Open inbox items  (> 50 → ANALYZER_PAUSE; ≤ 25 and marker exists → remove)
#   4. Stash count  (> 10 → drop oldest)
#   5. Cost-cap  (via cost_check_or_die; exceeded → PANIC marker + critical notify)
#
# Outputs:
#   .claude/overseer/health.json
#   .claude/overseer/ANALYZER_PAUSE  (created/removed by check 3)
#   .claude/overseer/PANIC            (created by check 5; must be manually removed)
#
# Environment:
#   OVERSEER_CAP_TODAY=20   (default)
#   OVERSEER_CAP_WEEK=100   (default)
#   NOTIFY_DRY_RUN=1        (set for tests; all notifications go to sent.jsonl)
#   MOCK_DISK_FREE_GB       (override disk free GB for tests)
#   MOCK_DISK_FREE_PCT      (override disk free % for tests)
#   MOCK_WORKTREE_COUNT     (override worktree count for tests)
#   MOCK_INBOX_COUNT        (override inbox item count for tests)
#   MOCK_STASH_COUNT        (override stash count for tests)
#   COST_CAP_LEDGER_DIR     (override ledger dir; forwarded to cost-cap.sh)
#   WATCHDOG_INTERVAL       (override sleep interval; default 300)
#
# IMPORTANT: This file is in the Self-Mod-Blocklist.

set -uo pipefail

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Allow REPO_ROOT to be overridden via env (used by verify/sandbox tests).
REPO_ROOT="${REPO_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

LIB_COST="${SCRIPT_DIR}/lib/cost-cap.sh"
LIB_WORKTREE="${SCRIPT_DIR}/lib/worktree.sh"
LIB_AUDIT="${SCRIPT_DIR}/lib/audit.sh"
NOTIFY_SH="${SCRIPT_DIR}/notify.sh"

OVERSEER_DIR="${REPO_ROOT}/.claude/overseer"
HEALTH_JSON="${OVERSEER_DIR}/health.json"
PANIC_MARKER="${OVERSEER_DIR}/PANIC"
ANALYZER_PAUSE_MARKER="${OVERSEER_DIR}/ANALYZER_PAUSE"
INBOX_DIR="${REPO_ROOT}/.claude/overseer/inbox"

# ---------------------------------------------------------------------------
# Source libraries
# ---------------------------------------------------------------------------
if [ -f "$LIB_COST" ];     then source "$LIB_COST";     fi
if [ -f "$LIB_WORKTREE" ]; then source "$LIB_WORKTREE"; fi
if [ -f "$LIB_AUDIT" ];    then source "$LIB_AUDIT";    fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
_log() { printf '[watchdog] %s\n' "$*" >&2; }

_notify() {
  local severity="$1"   # info | critical
  local title="$2"
  local body="$3"
  local topic="${NTFY_TOPIC:-claude-code}"
  if [ -x "$NOTIFY_SH" ]; then
    # Forward REPO_ROOT so notify.sh writes to the correct overseer dir in sandboxed tests.
    REPO_ROOT="$REPO_ROOT" "$NOTIFY_SH" "$severity" "$topic" "$title" "$body" || true
  else
    _log "WARN: notify.sh not found/executable: $NOTIFY_SH"
  fi
}

_audit() {
  local action="$1"
  local subject="$2"
  local reason="$3"
  if command -v audit_record >/dev/null 2>&1; then
    audit_record "watchdog" "$action" "$subject" "$reason" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# _get_disk_info — sets DISK_FREE_GB and DISK_FREE_PCT
# ---------------------------------------------------------------------------
_get_disk_info() {
  if [ -n "${MOCK_DISK_FREE_GB:-}" ]; then
    DISK_FREE_GB="$MOCK_DISK_FREE_GB"
  else
    local avail_kb
    avail_kb=$(df -k "$REPO_ROOT" 2>/dev/null | awk 'NR==2{print $4}')
    DISK_FREE_GB=$(( avail_kb / 1024 / 1024 ))
  fi

  if [ -n "${MOCK_DISK_FREE_PCT:-}" ]; then
    DISK_FREE_PCT="$MOCK_DISK_FREE_PCT"
  else
    local use_pct
    use_pct=$(df -k "$REPO_ROOT" 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5); print $5}')
    DISK_FREE_PCT=$(( 100 - use_pct ))
  fi
}

# ---------------------------------------------------------------------------
# _get_worktree_count — sets WORKTREE_COUNT
# ---------------------------------------------------------------------------
_get_worktree_count() {
  if [ -n "${MOCK_WORKTREE_COUNT:-}" ]; then
    WORKTREE_COUNT="$MOCK_WORKTREE_COUNT"
  elif command -v worktree_list >/dev/null 2>&1; then
    WORKTREE_COUNT=$(worktree_list 2>/dev/null | wc -l | tr -d ' ')
  else
    WORKTREE_COUNT=0
  fi
}

# ---------------------------------------------------------------------------
# _get_inbox_count — sets INBOX_COUNT
# ---------------------------------------------------------------------------
_get_inbox_count() {
  if [ -n "${MOCK_INBOX_COUNT:-}" ]; then
    INBOX_COUNT="$MOCK_INBOX_COUNT"
  else
    if [ -d "$INBOX_DIR" ]; then
      INBOX_COUNT=$(find "$INBOX_DIR" -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
    else
      INBOX_COUNT=0
    fi
  fi
}

# ---------------------------------------------------------------------------
# _get_stash_count — sets STASH_COUNT
# ---------------------------------------------------------------------------
_get_stash_count() {
  if [ -n "${MOCK_STASH_COUNT:-}" ]; then
    STASH_COUNT="$MOCK_STASH_COUNT"
  else
    STASH_COUNT=$(git -C "$REPO_ROOT" stash list 2>/dev/null | wc -l | tr -d ' ')
  fi
}

# ---------------------------------------------------------------------------
# _get_cost_info — sets COST_TODAY and COST_WEEK
# ---------------------------------------------------------------------------
_get_cost_info() {
  if command -v cost_today_usd >/dev/null 2>&1; then
    COST_TODAY=$(cost_today_usd 2>/dev/null || echo "0.00")
    COST_WEEK=$(cost_week_usd 2>/dev/null || echo "0.00")
  else
    COST_TODAY="0.00"
    COST_WEEK="0.00"
  fi
}

# ---------------------------------------------------------------------------
# _write_health_json — writes OVERSEER_DIR/health.json
# ---------------------------------------------------------------------------
_write_health_json() {
  local ts="$1"
  local panic="$2"
  local disk_pct="$3"
  local disk_gb="$4"
  local disk_ok="$5"
  local wt_count="$6"
  local wt_ok="$7"
  local inbox_count="$8"
  local inbox_paused="$9"
  local inbox_ok="${10}"
  local stash_count="${11}"
  local stash_ok="${12}"
  local cost_today="${13}"
  local cost_week="${14}"
  local cost_ok="${15}"
  local notifications_sent="${16}"

  mkdir -p "$OVERSEER_DIR"

  python3 - \
    "$HEALTH_JSON" "$ts" "$panic" \
    "$disk_pct" "$disk_gb" "$disk_ok" \
    "$wt_count" "$wt_ok" \
    "$inbox_count" "$inbox_paused" "$inbox_ok" \
    "$stash_count" "$stash_ok" \
    "$cost_today" "$cost_week" "$cost_ok" \
    "$notifications_sent" \
    <<'PYEOF'
import sys, json

(health_file, ts, panic,
 disk_pct, disk_gb, disk_ok,
 wt_count, wt_ok,
 inbox_count, inbox_paused, inbox_ok,
 stash_count, stash_ok,
 cost_today, cost_week, cost_ok,
 notifications_sent) = sys.argv[1:]

def _bool(v): return v.lower() in ('true', '1', 'yes')
def _int(v):
    try: return int(v)
    except: return 0
def _float(v):
    try: return float(v)
    except: return 0.0

notif_list = [x for x in notifications_sent.split(',') if x]

health = {
    "ts": ts,
    "panic": _bool(panic),
    "checks": {
        "disk":      {"free_pct": _int(disk_pct),      "free_gb": _int(disk_gb),    "ok": _bool(disk_ok)},
        "worktrees": {"count":    _int(wt_count),                                    "ok": _bool(wt_ok)},
        "inbox":     {"count":    _int(inbox_count),    "paused":  _bool(inbox_paused), "ok": _bool(inbox_ok)},
        "stash":     {"count":    _int(stash_count),                                 "ok": _bool(stash_ok)},
        "cost":      {"today_usd":_float(cost_today),   "week_usd":_float(cost_week), "ok": _bool(cost_ok)},
    },
    "notifications_sent": notif_list,
}
with open(health_file, 'w') as fh:
    json.dump(health, fh, indent=2)
    fh.write('\n')
PYEOF
}

# ---------------------------------------------------------------------------
# run_iteration — single watchdog iteration
# ---------------------------------------------------------------------------
run_iteration() {
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  mkdir -p "$OVERSEER_DIR"

  # Collect metrics
  _get_disk_info
  _get_worktree_count
  _get_inbox_count
  _get_stash_count
  _get_cost_info

  local panic=false
  local notifications_sent=""

  # If PANIC marker already exists → persist panic=true
  if [ -f "$PANIC_MARKER" ]; then
    panic=true
  fi

  # -----------------------------------------------------------------------
  # Check 1: Disk free
  # -----------------------------------------------------------------------
  local disk_ok=true
  local disk_severity=""

  # Critical: < 5% OR < 5 GB
  if python3 -c "import sys; sys.exit(0 if (int('${DISK_FREE_PCT}') < 5 or int('${DISK_FREE_GB}') < 5) else 1)" 2>/dev/null; then
    disk_ok=false
    disk_severity="critical"
    panic=true
    _log "CRITICAL: disk free: ${DISK_FREE_PCT}% / ${DISK_FREE_GB}GB"
    _notify critical "Watchdog: Disk CRITICAL" \
      "Disk free: ${DISK_FREE_PCT}% / ${DISK_FREE_GB}GB (threshold: <5% or <5GB)"
    notifications_sent="${notifications_sent:+${notifications_sent},}disk_critical"
    _audit "panic_triggered" "disk" "disk_free: ${DISK_FREE_PCT}%/${DISK_FREE_GB}GB < critical threshold"
  # Warning: < 15% OR < 10 GB
  elif python3 -c "import sys; sys.exit(0 if (int('${DISK_FREE_PCT}') < 15 or int('${DISK_FREE_GB}') < 10) else 1)" 2>/dev/null; then
    disk_ok=false
    disk_severity="warn"
    _log "WARN: disk free: ${DISK_FREE_PCT}% / ${DISK_FREE_GB}GB"
    _notify info "Watchdog: Disk Low" \
      "Disk free: ${DISK_FREE_PCT}% / ${DISK_FREE_GB}GB (threshold: <15% or <10GB)"
    notifications_sent="${notifications_sent:+${notifications_sent},}disk_warn"
    _audit "warn" "disk" "disk_free: ${DISK_FREE_PCT}%/${DISK_FREE_GB}GB < warn threshold"
  fi

  # -----------------------------------------------------------------------
  # Check 2: Worktree count
  # -----------------------------------------------------------------------
  local wt_ok=true
  if [ "${WORKTREE_COUNT}" -gt 3 ] 2>/dev/null; then
    wt_ok=false
    panic=true
    _log "WARN: worktree count ${WORKTREE_COUNT} > 3 (hard-cap violation)"
    _notify info "Watchdog: Worktree Hard-Cap Violated" \
      "Active worker worktrees: ${WORKTREE_COUNT} (max 3)"
    notifications_sent="${notifications_sent:+${notifications_sent},}worktrees_warn"
    _audit "panic_triggered" "worktrees" "count ${WORKTREE_COUNT} > hard-cap 3"
  fi

  # -----------------------------------------------------------------------
  # Check 3: Open inbox items
  # -----------------------------------------------------------------------
  local inbox_ok=true
  local inbox_paused=false

  if [ "${INBOX_COUNT}" -gt 50 ] 2>/dev/null; then
    inbox_ok=false
    inbox_paused=true
    if [ ! -f "$ANALYZER_PAUSE_MARKER" ]; then
      touch "$ANALYZER_PAUSE_MARKER"
      _log "INFO: inbox ${INBOX_COUNT} > 50 — ANALYZER_PAUSE marker set"
      _notify info "Watchdog: Analyzer Paused" \
        "Inbox items: ${INBOX_COUNT} > 50. ANALYZER_PAUSE marker created."
      notifications_sent="${notifications_sent:+${notifications_sent},}inbox_pause"
      _audit "marker_set" "ANALYZER_PAUSE" "inbox count ${INBOX_COUNT} > 50"
    fi
  elif [ "${INBOX_COUNT}" -le 25 ] 2>/dev/null && [ -f "$ANALYZER_PAUSE_MARKER" ]; then
    rm -f "$ANALYZER_PAUSE_MARKER"
    _log "INFO: inbox ${INBOX_COUNT} <= 25 — ANALYZER_PAUSE marker removed"
    _notify info "Watchdog: Analyzer Resumed" \
      "Inbox items: ${INBOX_COUNT} ≤ 25. ANALYZER_PAUSE marker removed."
    notifications_sent="${notifications_sent:+${notifications_sent},}inbox_resume"
    _audit "marker_cleared" "ANALYZER_PAUSE" "inbox count ${INBOX_COUNT} <= 25"
  elif [ -f "$ANALYZER_PAUSE_MARKER" ]; then
    # Count is between 26 and 50 — still paused
    inbox_paused=true
    inbox_ok=false
  fi

  # -----------------------------------------------------------------------
  # Check 4: Stash count
  # -----------------------------------------------------------------------
  local stash_ok=true
  if [ "${STASH_COUNT}" -gt 10 ] 2>/dev/null; then
    stash_ok=false
    _log "INFO: stash count ${STASH_COUNT} > 10 — dropping oldest stash"
    local oldest_idx=$(( STASH_COUNT - 1 ))
    if [ -z "${MOCK_STASH_COUNT:-}" ]; then
      # Only drop when not mocked (real git stash)
      git -C "$REPO_ROOT" stash drop "stash@{${oldest_idx}}" 2>/dev/null || true
    fi
    _notify info "Watchdog: Stash Trimmed" \
      "Stash count ${STASH_COUNT} > 10. Dropped oldest (stash@{${oldest_idx}})."
    notifications_sent="${notifications_sent:+${notifications_sent},}stash_trim"
  fi

  # -----------------------------------------------------------------------
  # Check 5: Cost-cap
  # -----------------------------------------------------------------------
  local cost_ok=true
  local cap_today="${OVERSEER_CAP_TODAY:-20}"
  local cap_week="${OVERSEER_CAP_WEEK:-100}"

  if command -v cost_check_or_die >/dev/null 2>&1; then
    local cost_rc=0
    cost_check_or_die "$cap_today" "$cap_week" 2>/dev/null || cost_rc=$?
    if [ "$cost_rc" -eq 2 ]; then
      cost_ok=false
      panic=true
      # Write PANIC marker
      {
        printf 'PANIC: cost-cap exceeded at %s\n' "$ts"
        printf 'today=%s/%s week=%s/%s\n' "$COST_TODAY" "$cap_today" "$COST_WEEK" "$cap_week"
      } > "$PANIC_MARKER"
      _log "CRITICAL: cost-cap exceeded — today=${COST_TODAY}/${cap_today} week=${COST_WEEK}/${cap_week}"
      _notify critical "Watchdog: Cost-Cap EXCEEDED" \
        "today=${COST_TODAY}/${cap_today}USD week=${COST_WEEK}/${cap_week}USD. PANIC marker written."
      notifications_sent="${notifications_sent:+${notifications_sent},}cost_cap_critical"
      _audit "panic_triggered" "cost_cap" "today=${COST_TODAY}/${cap_today} week=${COST_WEEK}/${cap_week}"
    fi
  fi

  # -----------------------------------------------------------------------
  # Write health.json
  # -----------------------------------------------------------------------
  _write_health_json \
    "$ts" \
    "$panic" \
    "${DISK_FREE_PCT}" "${DISK_FREE_GB}" "$disk_ok" \
    "${WORKTREE_COUNT}" "$wt_ok" \
    "${INBOX_COUNT}" "$inbox_paused" "$inbox_ok" \
    "${STASH_COUNT}" "$stash_ok" \
    "${COST_TODAY}" "${COST_WEEK}" "$cost_ok" \
    "${notifications_sent}"

  _log "Iteration complete — panic=${panic} ts=${ts}"
}

# ---------------------------------------------------------------------------
# CLI arg parsing
# ---------------------------------------------------------------------------
MODE="daemon"  # daemon | once | status
for arg in "$@"; do
  case "$arg" in
    --once)   MODE="once" ;;
    --status) MODE="status" ;;
    *)
      printf 'Usage: %s [--once|--status]\n' "$(basename "$0")" >&2
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# --status mode
# ---------------------------------------------------------------------------
if [ "$MODE" = "status" ]; then
  if [ ! -f "$HEALTH_JSON" ]; then
    printf '{"error":"health.json not found"}\n'
    exit 1
  fi
  cat "$HEALTH_JSON"
  # Exit 1 if panic=true
  if python3 -c "import json,sys; d=json.load(open('${HEALTH_JSON}')); sys.exit(0 if not d.get('panic',False) else 1)" 2>/dev/null; then
    exit 0
  else
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# --once mode
# ---------------------------------------------------------------------------
if [ "$MODE" = "once" ]; then
  run_iteration
  exit 0
fi

# ---------------------------------------------------------------------------
# daemon mode
# ---------------------------------------------------------------------------
INTERVAL="${WATCHDOG_INTERVAL:-300}"
_log "Starting watchdog daemon (interval=${INTERVAL}s)"

while true; do
  run_iteration || _log "WARN: run_iteration failed (exit $?)"
  sleep "$INTERVAL"
done
