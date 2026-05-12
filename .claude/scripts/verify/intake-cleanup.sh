#!/usr/bin/env bash
# verify/intake-cleanup.sh — Acceptance tests for intake-cleanup.sh (T16).
#
# Exit 0 = all tests passed.
# Exit 1 = one or more tests failed.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
INTAKE_CLEANUP_SH="$REAL_REPO_ROOT/.claude/scripts/intake-cleanup.sh"

# ---------------------------------------------------------------------------
# Harness
# ---------------------------------------------------------------------------
PASS=0
FAIL=0

_pass() { printf '  [PASS] %s\n' "$1"; PASS=$(( PASS + 1 )); }
_fail() { printf '  [FAIL] %s\n' "$1"; FAIL=$(( FAIL + 1 )); }
_section() { printf '\n--- %s ---\n' "$1"; }

# ---------------------------------------------------------------------------
# Sandbox
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d)"
_cleanup() {
  chflags -R nouchg "$SANDBOX" 2>/dev/null || true
  chmod -R u+w "$SANDBOX" 2>/dev/null || true
  rm -rf "$SANDBOX"
}
trap '_cleanup' EXIT

MOCK_REPO="$SANDBOX/repo"
PENDING_DIR="$MOCK_REPO/.claude/stakeholder/pending-approval"
STALE_DIR="$PENDING_DIR/stale"
NOTIFY_SENT="$MOCK_REPO/.claude/overseer/notifications/sent.jsonl"

# Build minimal sandbox
mkdir -p "$PENDING_DIR/stale"
mkdir -p "$MOCK_REPO/.claude/overseer/notifications"
mkdir -p "$MOCK_REPO/.claude/audit"
mkdir -p "$MOCK_REPO/.claude/scripts/lib"
mkdir -p "$MOCK_REPO/.claude/intake-council/state"

# Stub audit.sh (no-op for test speed)
cat > "$MOCK_REPO/.claude/scripts/lib/audit.sh" <<'STUB'
#!/usr/bin/env bash
audit_record() { :; }
STUB

# Stub notify.sh — records to sent.jsonl
mkdir -p "$MOCK_REPO/.claude/scripts"
cat > "$MOCK_REPO/.claude/scripts/notify.sh" <<'STUB'
#!/usr/bin/env bash
mkdir -p "${REPO_ROOT:-/tmp}/.claude/overseer/notifications"
printf '{"severity":"%s","topic":"%s","title":"%s","body":"%s"}\n' \
  "${1:-}" "${2:-}" "${3:-}" "${4:-}" \
  >> "${REPO_ROOT:-/tmp}/.claude/overseer/notifications/sent.jsonl"
STUB
chmod +x "$MOCK_REPO/.claude/scripts/notify.sh"

# Helper: create a pending-approval file with given created_at (ISO)
_make_pending() {
  local slug="$1" created_at="$2"
  local file="$PENDING_DIR/${slug}.md"
  cat > "$file" <<MDEOF
---
id: ${slug}
created_at: ${created_at}
state: pending-approval
user_id: 12345
---
# ${slug}
MDEOF
}

# Helper: create a stale file with an explicit mtime (days ago)
_make_stale() {
  local slug="$1" days_ago="$2"
  local file="$STALE_DIR/${slug}.md"
  printf -- '---\nid: %s\nstate: stale\n---\n' "$slug" > "$file"
  # Set mtime to days_ago days in the past
  local ts=$(( $(date +%s) - days_ago * 86400 ))
  touch -t "$(date -r "$ts" +%Y%m%d%H%M.%S 2>/dev/null || date -d "@$ts" +%Y%m%d%H%M.%S 2>/dev/null)" \
    "$file" 2>/dev/null || true
}

# Common runner
run_cleanup() {
  REPO_ROOT="$MOCK_REPO" \
  INTAKE_STALE_DAYS="${INTAKE_STALE_DAYS_OVERRIDE:-7}" \
  INTAKE_PURGE_DAYS="${INTAKE_PURGE_DAYS_OVERRIDE:-30}" \
  INTAKE_REMINDER_MIN="${INTAKE_REMINDER_MIN_OVERRIDE:-3}" \
  INTAKE_REMINDER_H="${INTAKE_REMINDER_H_OVERRIDE:-24}" \
    bash "$INTAKE_CLEANUP_SH" "$@" 2>/dev/null
}

printf '\n=== intake-cleanup.sh verification ===\n'

# ---------------------------------------------------------------------------
# Test 1: File older than 7d → moved to stale/
# ---------------------------------------------------------------------------
_section "Test 1: stale-move (>7d)"
_make_pending "old-proposal" "2000-01-01T00:00:00Z"
_make_pending "new-proposal" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

run_cleanup

if [ -f "$STALE_DIR/old-proposal.md" ]; then
  _pass "old-proposal moved to stale/"
else
  _fail "old-proposal NOT in stale/ (expected move)"
fi

if [ -f "$PENDING_DIR/new-proposal.md" ]; then
  _pass "new-proposal stays in pending-approval/"
else
  _fail "new-proposal should NOT have been moved"
fi

# ---------------------------------------------------------------------------
# Test 2: stale/ file older than 30d → deleted
# ---------------------------------------------------------------------------
_section "Test 2: purge (>30d mtime)"
_make_stale "very-old-stale" 35

run_cleanup

if [ ! -f "$STALE_DIR/very-old-stale.md" ]; then
  _pass "very-old-stale.md purged after 35d"
else
  _fail "very-old-stale.md should have been purged"
fi

# ---------------------------------------------------------------------------
# Test 3: ≥3 files older than 24h → reminder sent
# ---------------------------------------------------------------------------
_section "Test 3: reminder (>= 3 files older than 24h)"
# Clear pending dir
rm -f "$PENDING_DIR"/*.md
# Create 3 old files
_make_pending "remind-a" "2000-01-01T00:00:00Z"
_make_pending "remind-b" "2000-01-02T00:00:00Z"
_make_pending "remind-c" "2000-01-03T00:00:00Z"
rm -f "$NOTIFY_SENT"

INTAKE_STALE_DAYS_OVERRIDE=9999 \
INTAKE_PURGE_DAYS_OVERRIDE=9999 \
INTAKE_REMINDER_MIN_OVERRIDE=3 \
INTAKE_REMINDER_H_OVERRIDE=24 \
run_cleanup

if [ -f "$NOTIFY_SENT" ] && grep -q "intake-stale-reminder" "$NOTIFY_SENT"; then
  _pass "Reminder notification sent"
else
  _fail "Reminder notification NOT sent (expected notify with topic intake-stale-reminder)"
fi

# ---------------------------------------------------------------------------
# Test 4: --dry-run → no files moved
# ---------------------------------------------------------------------------
_section "Test 4: --dry-run no changes"
rm -f "$PENDING_DIR"/*.md
_make_pending "dry-old" "2000-01-01T00:00:00Z"

run_cleanup --dry-run

if [ -f "$PENDING_DIR/dry-old.md" ] && [ ! -f "$STALE_DIR/dry-old.md" ]; then
  _pass "--dry-run: file NOT moved (correct)"
else
  _fail "--dry-run: file was moved (should not have been)"
fi

# ---------------------------------------------------------------------------
# Test 5: < INTAKE_REMINDER_MIN old files → no reminder
# ---------------------------------------------------------------------------
_section "Test 5: no reminder when < threshold"
rm -f "$PENDING_DIR"/*.md
rm -f "$NOTIFY_SENT"
_make_pending "only-one" "2000-01-01T00:00:00Z"

INTAKE_STALE_DAYS_OVERRIDE=9999 \
INTAKE_REMINDER_MIN_OVERRIDE=3 \
run_cleanup

if [ ! -f "$NOTIFY_SENT" ] || ! grep -q "intake-stale-reminder" "$NOTIFY_SENT" 2>/dev/null; then
  _pass "No reminder sent (only 1 old file, threshold 3)"
else
  _fail "Reminder sent unexpectedly with only 1 old file"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
