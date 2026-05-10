#!/usr/bin/env bash
# panic.sh — Sourceable library for Panic-Mode logic (P3-7).
#
# Functions:
#   record_worker_failure <slug> <exit_code>
#   record_worker_success <slug>
#   enter_panic <reason>
#   is_in_panic
#
# State: .claude/overseer/state/failure-counter.json
# Panic-Marker: .claude/overseer/PANIC
#
# IMPORTANT: This file is NOT in the Self-Mod-Blocklist so it can be
# iterated on. Blocklisted files that source this: overseer.sh (P1-1).

# Deliberately NO set -e — sourceable library.
set -u

# ---------------------------------------------------------------------------
# Resolve paths (caller may override REPO_ROOT for sandbox tests)
# ---------------------------------------------------------------------------
_PANIC_REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
_PANIC_OVERSEER_DIR="${_PANIC_REPO_ROOT}/.claude/overseer"
_PANIC_STATE_DIR="${_PANIC_OVERSEER_DIR}/state"
_PANIC_COUNTER_FILE="${_PANIC_STATE_DIR}/failure-counter.json"
_PANIC_MARKER="${_PANIC_OVERSEER_DIR}/PANIC"
_PANIC_NOTIFY_SH="${_PANIC_REPO_ROOT}/.claude/scripts/notify.sh"
_PANIC_THRESHOLD="${PANIC_CONSECUTIVE_THRESHOLD:-3}"
_PANIC_HISTORY_CAP="${PANIC_HISTORY_CAP:-20}"

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# _panic_now_iso → ISO 8601 UTC timestamp
_panic_now_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# _panic_read_json → prints current counter JSON or a safe default to stdout
_panic_read_json() {
  if [ -f "$_PANIC_COUNTER_FILE" ]; then
    cat "$_PANIC_COUNTER_FILE" 2>/dev/null || true
  fi
}

# _panic_write_json <json> → atomically overwrites counter file
_panic_write_json() {
  local json="$1"
  mkdir -p "$_PANIC_STATE_DIR"
  local tmp
  tmp="${_PANIC_COUNTER_FILE}.tmp.$$"
  printf '%s\n' "$json" > "$tmp"
  mv "$tmp" "$_PANIC_COUNTER_FILE"
}

# _panic_notify_critical <title> <body>
# Sends a critical notification bypassing Quiet-Hours.
_panic_notify_critical() {
  local title="$1" body="$2"
  local topic="${NTFY_TOPIC:-claude-code}"
  if [ -x "$_PANIC_NOTIFY_SH" ]; then
    REPO_ROOT="$_PANIC_REPO_ROOT" \
      "$_PANIC_NOTIFY_SH" critical "$topic" "$title" "$body" >/dev/null 2>&1 || true
  fi
}

# _panic_audit <action> <subject> <reason>
_panic_audit() {
  local action="$1" subject="$2" reason="${3:-}"
  if command -v audit_record >/dev/null 2>&1; then
    audit_record "panic" "$action" "$subject" "$reason" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# Public: record_worker_failure <slug> <exit_code>
# ---------------------------------------------------------------------------
record_worker_failure() {
  local slug="${1:-unknown}"
  local exit_code="${2:-1}"
  local ts
  ts="$(_panic_now_iso)"

  # Read + update counter via python3 for robust JSON handling
  local new_json
  new_json="$(python3 - "$_PANIC_COUNTER_FILE" "$slug" "$exit_code" "$ts" "$_PANIC_HISTORY_CAP" <<'PYEOF'
import sys, json, os

counter_file = sys.argv[1]
slug         = sys.argv[2]
exit_code    = sys.argv[3]
ts           = sys.argv[4]
history_cap  = int(sys.argv[5])

# Load or init
data = {"consecutive_failures": 0, "history": [], "last_success_ts": None}
if os.path.exists(counter_file):
    try:
        with open(counter_file, 'r') as f:
            data = json.load(f)
    except Exception:
        pass

data["consecutive_failures"] = int(data.get("consecutive_failures", 0)) + 1

history = list(data.get("history", []))
history.append({"ts": ts, "slug": slug, "exit": int(exit_code) if str(exit_code).isdigit() else exit_code})
# Cap history
if len(history) > history_cap:
    history = history[-history_cap:]
data["history"] = history

print(json.dumps(data, indent=2))
PYEOF
)"

  _panic_write_json "$new_json"

  # Read consecutive_failures from updated state
  local consecutive
  consecutive="$(python3 -c "
import json, sys
try:
    data = json.load(open('$_PANIC_COUNTER_FILE'))
    print(data.get('consecutive_failures', 0))
except Exception:
    print(0)
" 2>/dev/null || echo 0)"

  # Trigger panic if threshold reached OR PANIC marker already present
  if (( consecutive >= _PANIC_THRESHOLD )) || [ -f "$_PANIC_MARKER" ]; then
    if [ ! -f "$_PANIC_MARKER" ]; then
      enter_panic "consecutive_failures=${consecutive} (threshold=${_PANIC_THRESHOLD}), last slug=${slug}"
    fi
    # If already in panic, just audit the accounting — no double-trigger
    _panic_audit "failure_recorded_during_panic" "$slug" "exit=${exit_code} consecutive=${consecutive}"
    return 0
  fi

  _panic_audit "failure_recorded" "$slug" "exit=${exit_code} consecutive=${consecutive}"
}

# ---------------------------------------------------------------------------
# Public: record_worker_success <slug>
# ---------------------------------------------------------------------------
record_worker_success() {
  local slug="${1:-unknown}"
  local ts
  ts="$(_panic_now_iso)"

  local new_json
  new_json="$(python3 - "$_PANIC_COUNTER_FILE" "$slug" "$ts" <<'PYEOF'
import sys, json, os

counter_file = sys.argv[1]
slug         = sys.argv[2]
ts           = sys.argv[3]

data = {"consecutive_failures": 0, "history": [], "last_success_ts": None}
if os.path.exists(counter_file):
    try:
        with open(counter_file, 'r') as f:
            data = json.load(f)
    except Exception:
        pass

data["consecutive_failures"] = 0
data["last_success_ts"] = ts

print(json.dumps(data, indent=2))
PYEOF
)"

  _panic_write_json "$new_json"
  _panic_audit "success_recorded" "$slug" "consecutive_failures reset to 0"
}

# ---------------------------------------------------------------------------
# Public: enter_panic <reason>
# ---------------------------------------------------------------------------
enter_panic() {
  local reason="${1:-unknown}"
  local ts
  ts="$(_panic_now_iso)"

  mkdir -p "$_PANIC_OVERSEER_DIR"

  # Write PANIC marker (idempotent)
  printf 'PANIC: %s\ntimestamp: %s\n' "$reason" "$ts" > "$_PANIC_MARKER"

  # Critical notification — bypasses Quiet-Hours (critical severity always sends)
  _panic_notify_critical \
    "Overseer PANIC" \
    "Reason: ${reason}. Resume with: bash .claude/scripts/resume.sh"

  _panic_audit "enter_panic" "overseer" "reason=${reason}"
}

# ---------------------------------------------------------------------------
# Public: is_in_panic
# Returns 0 (true) if PANIC marker exists, 1 (false) otherwise.
# ---------------------------------------------------------------------------
is_in_panic() {
  [ -f "$_PANIC_MARKER" ]
}
