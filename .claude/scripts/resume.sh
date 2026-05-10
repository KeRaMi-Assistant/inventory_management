#!/usr/bin/env bash
# resume.sh — Manual Panic-Resume Script (P3-7, User-only).
#
# Usage: bash .claude/scripts/resume.sh
#
# Prerequisites:
#   - .claude/.user-session-active must be valid (session-start.sh must have
#     been called recently). Workers cannot forge this marker.
#   - The PANIC marker must exist (or we exit silently if already clear).
#
# What it does:
#   1. Validates user-session-active marker.
#   2. Removes .claude/overseer/PANIC.
#   3. Resets consecutive_failures to 0 in failure-counter.json.
#   4. Audit + Notification.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

OVERSEER_DIR="${REPO_ROOT}/.claude/overseer"
PANIC_MARKER="${OVERSEER_DIR}/PANIC"
STATE_DIR="${OVERSEER_DIR}/state"
COUNTER_FILE="${STATE_DIR}/failure-counter.json"
SESSION_MARKER="${REPO_ROOT}/.claude/.user-session-active"
SELF_MOD_LIB="${REPO_ROOT}/.claude/scripts/lib/self-mod-blocklist.sh"
LIB_AUDIT="${REPO_ROOT}/.claude/scripts/lib/audit.sh"
NOTIFY_SH="${REPO_ROOT}/.claude/scripts/notify.sh"

# ---------------------------------------------------------------------------
# Step 1: Validate user-session-active
# ---------------------------------------------------------------------------
if [ ! -f "$SESSION_MARKER" ]; then
  printf 'resume.sh: ERROR: .claude/.user-session-active missing.\n' >&2
  printf '  Run: bash .claude/scripts/session-start.sh\n' >&2
  exit 1
fi

# Validate hash via self-mod-blocklist helper
if [ -f "$SELF_MOD_LIB" ]; then
  # shellcheck disable=SC1090
  SELF_MOD_REPO_ROOT="$REPO_ROOT" source "$SELF_MOD_LIB" 2>/dev/null || true
  if ! _is_session_marker_valid "$SESSION_MARKER" 2>/dev/null; then
    printf 'resume.sh: ERROR: .user-session-active is invalid or expired.\n' >&2
    printf '  Re-run: bash .claude/scripts/session-start.sh\n' >&2
    exit 1
  fi
else
  # Fallback if lib not found: check mere existence (degraded mode)
  if [ ! -s "$SESSION_MARKER" ]; then
    printf 'resume.sh: ERROR: .user-session-active is empty (cannot validate).\n' >&2
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# Source audit library (best-effort)
# ---------------------------------------------------------------------------
if [ -r "$LIB_AUDIT" ]; then
  # shellcheck disable=SC1090
  source "$LIB_AUDIT" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Step 2: Remove PANIC marker
# ---------------------------------------------------------------------------
if [ -f "$PANIC_MARKER" ]; then
  rm -f "$PANIC_MARKER"
  printf 'resume.sh: PANIC marker removed.\n'
else
  printf 'resume.sh: No PANIC marker found — already clear.\n'
fi

# ---------------------------------------------------------------------------
# Step 3: Reset consecutive_failures in counter file
# ---------------------------------------------------------------------------
if [ -f "$COUNTER_FILE" ]; then
  local_ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  new_json="$(python3 - "$COUNTER_FILE" "$local_ts" <<'PYEOF'
import sys, json, os

counter_file = sys.argv[1]
ts           = sys.argv[2]

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
  tmp="${COUNTER_FILE}.resume.tmp.$$"
  printf '%s\n' "$new_json" > "$tmp"
  mv "$tmp" "$COUNTER_FILE"
  printf 'resume.sh: failure counter reset to 0.\n'
fi

# ---------------------------------------------------------------------------
# Step 4: Audit + Notification
# ---------------------------------------------------------------------------
if command -v audit_record >/dev/null 2>&1; then
  audit_record "user" "resume" "" "user-initiated panic-resume" 2>/dev/null || true
fi

topic="${NTFY_TOPIC:-claude-code}"
if [ -x "$NOTIFY_SH" ]; then
  REPO_ROOT="$REPO_ROOT" \
    "$NOTIFY_SH" info "$topic" "Overseer resumed from panic" \
    "Manual resume by user. Overseer will pick up new items on next tick." \
    >/dev/null 2>&1 || true
fi

printf 'resume.sh: Done. Overseer will resume on next iteration.\n'
exit 0
