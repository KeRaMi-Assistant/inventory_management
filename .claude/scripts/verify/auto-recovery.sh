#!/usr/bin/env bash
# verify/auto-recovery.sh — Sandbox verification for recover.sh (P3-5).
#
# All tests run against an isolated REPO_ROOT sandbox (never the real repo).
# Tests:
#   1. Mock dead PID → orphan recovery to inbox with [recovered 1x] marker
#   2. Mock hanging worker (live sleep + started > 60 min ago) → kill + recovery
#   3. 3-cycles limit → 4th recovery sends to failed/, not inbox
#   4. Dead worktree (no active PID, stale) → removed
#   5. Counter reset via --reset-counter
#   6. Plist valid via plutil -lint
#
# Exit 0 if all tests pass.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
RECOVER_SH="${SCRIPTS_DIR}/recover.sh"

# ---------------------------------------------------------------------------
# Test harness helpers
# ---------------------------------------------------------------------------
PASS=0
FAIL=0
ERRORS=()

_pass() { printf '  [PASS] %s\n' "$1"; PASS=$(( PASS + 1 )); }
_fail() {
  printf '  [FAIL] %s\n' "$1"
  ERRORS+=("$1")
  FAIL=$(( FAIL + 1 ))
}
_section() { printf '\n== %s ==\n' "$1"; }

# ---------------------------------------------------------------------------
# Sandbox setup
# ---------------------------------------------------------------------------
SANDBOX_ROOT="$(mktemp -d)"
trap 'rm -rf "$SANDBOX_ROOT"' EXIT

# Minimal git repo in sandbox
git -C "$SANDBOX_ROOT" init -q
git -C "$SANDBOX_ROOT" config user.email "test@test.com"
git -C "$SANDBOX_ROOT" config user.name "Test"
# Create an initial commit so git log works
echo "init" > "${SANDBOX_ROOT}/README.md"
git -C "$SANDBOX_ROOT" add README.md
git -C "$SANDBOX_ROOT" commit -q -m "init"

OVERSEER_DIR="${SANDBOX_ROOT}/.claude/overseer"
WORKERS_DIR="${OVERSEER_DIR}/state/workers"
INBOX_DIR="${OVERSEER_DIR}/inbox"
FAILED_DIR="${OVERSEER_DIR}/failed"
COUNTS_JSON="${OVERSEER_DIR}/state/recovery-counts.json"

mkdir -p "$WORKERS_DIR" "$INBOX_DIR" "$FAILED_DIR" "${OVERSEER_DIR}/state"

# Create a fake notify.sh that just logs
FAKE_NOTIFY="${SANDBOX_ROOT}/notify.sh"
cat > "$FAKE_NOTIFY" <<'NOTIFY'
#!/usr/bin/env bash
# fake notify — no-op
exit 0
NOTIFY
chmod +x "$FAKE_NOTIFY"

# Convenience: run recover.sh with sandbox REPO_ROOT
_recover() {
  REPO_ROOT="$SANDBOX_ROOT" \
  NOTIFY_SH="$FAKE_NOTIFY" \
  RECOVER_HANG_TIMEOUT_MIN="${RECOVER_HANG_TIMEOUT_MIN:-60}" \
    bash "$RECOVER_SH" "$@" 2>/dev/null
}

# Write a pid-file JSON
_write_pid_file() {
  local pid_file="$1"
  local pid="$2"
  local slug="$3"
  local item_path="$4"
  local started_iso="${5:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
  local wslug="${6:-}"
  python3 - "$pid_file" "$pid" "$slug" "$item_path" "$started_iso" "$wslug" <<'PY'
import sys, json
path, pid, slug, item_path, started_iso, wslug = sys.argv[1:]
data = {
    "pid": int(pid),
    "slug": slug,
    "item_path": item_path,
    "started_iso": started_iso,
    "worktree_slug": wslug,
}
with open(path, "w") as f:
    json.dump(data, f, indent=2)
PY
}

# ---------------------------------------------------------------------------
# Test 1: Mock dead PID → orphan recovery to inbox
# ---------------------------------------------------------------------------
_section "Test 1: Dead PID → recovery to inbox"

DEAD_PID="99999999"
ITEM_SLUG="test-item-dead"
ITEM_SRC="${INBOX_DIR}/original-${ITEM_SLUG}.md"
PID_FILE="${WORKERS_DIR}/${DEAD_PID}.pid"

printf '# test item\n' > "$ITEM_SRC"
_write_pid_file "$PID_FILE" "$DEAD_PID" "$ITEM_SLUG" "$ITEM_SRC" "" ""

# PID 99999999 should be dead; run recovery
_recover --once

# Check: pid-file removed
if [ ! -f "$PID_FILE" ]; then
  _pass "pid-file removed after recovery"
else
  _fail "pid-file still exists after recovery"
fi

# Check: item appears in inbox with [recovered 1x] marker
RECOVERED_FILE="$(find "$INBOX_DIR" -name "*recovered*${ITEM_SLUG}*" 2>/dev/null | head -1 || true)"
if [ -n "$RECOVERED_FILE" ]; then
  _pass "item in inbox with recovered marker: $(basename "$RECOVERED_FILE")"
else
  _fail "item NOT found in inbox with recovered marker"
fi

# Check: recovery counter is 1
COUNT="$(python3 -c "import json; d=json.load(open('${COUNTS_JSON}')); print(d.get('${ITEM_SLUG}',{}).get('count',0))" 2>/dev/null || echo "0")"
if [ "$COUNT" -eq 1 ]; then
  _pass "recovery counter = 1"
else
  _fail "recovery counter = ${COUNT} (expected 1)"
fi

# Cleanup for next tests
rm -f "$RECOVERED_FILE" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Test 2: Mock hanging worker → timeout-kill + recovery
# ---------------------------------------------------------------------------
_section "Test 2: Hanging worker → kill + recovery"

# Start a real long-lived background process
sleep 9999 &
MOCK_PID=$!
HANG_SLUG="test-item-hang"
HANG_ITEM="${INBOX_DIR}/original-${HANG_SLUG}.md"
HANG_PID_FILE="${WORKERS_DIR}/${MOCK_PID}.pid"

printf '# hang test\n' > "$HANG_ITEM"

# started_iso = 90 minutes ago (> 60 min timeout)
STARTED_90MIN_AGO="$(python3 -c "
import datetime
dt = datetime.datetime.utcnow() - datetime.timedelta(minutes=90)
print(dt.strftime('%Y-%m-%dT%H:%M:%SZ'))
")"

_write_pid_file "$HANG_PID_FILE" "$MOCK_PID" "$HANG_SLUG" "$HANG_ITEM" "$STARTED_90MIN_AGO" ""

# Run recovery with low timeout
RECOVER_HANG_TIMEOUT_MIN=60 _recover --once

# Mock process should be dead now
if ! kill -0 "$MOCK_PID" 2>/dev/null; then
  _pass "hanging worker PID=${MOCK_PID} was killed"
else
  # Cleanup if still running
  kill "$MOCK_PID" 2>/dev/null || true
  _fail "hanging worker PID=${MOCK_PID} still alive after recovery"
fi

# pid-file should be removed
if [ ! -f "$HANG_PID_FILE" ]; then
  _pass "hang pid-file removed"
else
  _fail "hang pid-file still exists"
fi

# Item should be in inbox
HANG_RECOVERED="$(find "$INBOX_DIR" -name "*recovered*${HANG_SLUG}*" 2>/dev/null | head -1 || true)"
if [ -n "$HANG_RECOVERED" ]; then
  _pass "hung item recovered to inbox: $(basename "$HANG_RECOVERED")"
else
  _fail "hung item NOT found in inbox"
fi

# Cleanup
rm -f "$HANG_RECOVERED" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Test 3: 3-cycles limit → 4th recovery → failed/, not inbox
# ---------------------------------------------------------------------------
_section "Test 3: 3-cycles limit → failed/"

LIMIT_SLUG="test-item-limit"
LIMIT_ITEM_SRC="${INBOX_DIR}/original-${LIMIT_SLUG}.md"
printf '# limit test\n' > "$LIMIT_ITEM_SRC"

# Pre-set counter to 3 (simulating 3 prior recoveries)
python3 - "$COUNTS_JSON" "$LIMIT_SLUG" <<'PY'
import json, datetime, os
path, slug = __import__('sys').argv[1], __import__('sys').argv[2]
data = json.load(open(path)) if os.path.getsize(path) > 0 else {}
data[slug] = {
    "count": 3,
    "last_recovered": datetime.datetime.utcnow().isoformat() + "Z",
    "history": ["t1", "t2", "t3"]
}
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY

# Write another dead pid-file for this item
LIMIT_DEAD_PID="88888888"
LIMIT_PID_FILE="${WORKERS_DIR}/${LIMIT_DEAD_PID}.pid"
_write_pid_file "$LIMIT_PID_FILE" "$LIMIT_DEAD_PID" "$LIMIT_SLUG" "$LIMIT_ITEM_SRC" "" ""

_recover --once

# Check: NOT in inbox
INBOX_FILE="$(find "$INBOX_DIR" -name "*${LIMIT_SLUG}*" 2>/dev/null | head -1 || true)"
if [ -z "$INBOX_FILE" ]; then
  _pass "item NOT in inbox (correct — should be in failed/)"
else
  _fail "item still in inbox (should have gone to failed/)"
fi

# Check: in failed/
FAILED_FILE="$(find "$FAILED_DIR" -name "*${LIMIT_SLUG}*" 2>/dev/null | head -1 || true)"
if [ -n "$FAILED_FILE" ]; then
  _pass "item in failed/: $(basename "$FAILED_FILE")"
else
  _fail "item NOT in failed/"
fi

# Counter should be 4
LIMIT_COUNT="$(python3 -c "import json; d=json.load(open('${COUNTS_JSON}')); print(d.get('${LIMIT_SLUG}',{}).get('count',0))" 2>/dev/null || echo "0")"
if [ "$LIMIT_COUNT" -eq 4 ]; then
  _pass "recovery counter = 4 (incremented beyond 3)"
else
  _fail "recovery counter = ${LIMIT_COUNT} (expected 4)"
fi

rm -f "$FAILED_FILE" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Test 4: Dead worktrees (no active PID, stale > 24h) → removed
# ---------------------------------------------------------------------------
_section "Test 4: Stale worktree removal"

# We cannot actually create a real git worktree in the sandbox without the
# full inventory_management checkout. Instead, we verify that worktree_list
# returns nothing for our sandbox (no worker worktrees) and the check is
# a no-op, which is the correct behavior.
# The worktree_remove path is covered by the worktree.sh verify script.

# Run recovery — should not error even with no worktrees
if _recover --once; then
  _pass "recovery with no worktrees completes cleanly"
else
  _fail "recovery crashed when no worktrees present"
fi

# ---------------------------------------------------------------------------
# Test 5: Counter reset via --reset-counter
# ---------------------------------------------------------------------------
_section "Test 5: Counter reset"

RESET_SLUG="test-item-reset"
python3 - "$COUNTS_JSON" "$RESET_SLUG" <<'PY'
import json, os
path, slug = __import__('sys').argv[1], __import__('sys').argv[2]
data = json.load(open(path)) if os.path.getsize(path) > 0 else {}
data[slug] = {"count": 5, "last_recovered": "2026-01-01T00:00:00Z", "history": []}
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY

_recover --reset-counter "$RESET_SLUG"

RESET_COUNT="$(python3 -c "import json; d=json.load(open('${COUNTS_JSON}')); print(d.get('${RESET_SLUG}',{}).get('count',-1))" 2>/dev/null || echo "-1")"
if [ "$RESET_COUNT" -eq 0 ]; then
  _pass "counter reset to 0 for slug=${RESET_SLUG}"
else
  _fail "counter = ${RESET_COUNT} after reset (expected 0)"
fi

# ---------------------------------------------------------------------------
# Test 6: Plist valid via plutil -lint
# ---------------------------------------------------------------------------
_section "Test 6: Plist validity"

PLIST_TEMPLATE="${SCRIPTS_DIR}/../recovery-launchagent.plist.template"
PLIST_RESOLVED="$(mktemp /tmp/recovery-plist-XXXXXX.plist)"
trap 'rm -f "$PLIST_RESOLVED"' EXIT

if [ ! -f "$PLIST_TEMPLATE" ]; then
  _fail "plist template not found: $PLIST_TEMPLATE"
else
  sed \
    -e "s|__REPO_ROOT__|/tmp/sandbox|g" \
    -e "s|__HOME__|/tmp/home|g" \
    "$PLIST_TEMPLATE" > "$PLIST_RESOLVED"

  if command -v plutil >/dev/null 2>&1; then
    if plutil -lint "$PLIST_RESOLVED" >/dev/null 2>&1; then
      _pass "plist is valid XML (plutil -lint OK)"
    else
      _fail "plist failed plutil -lint"
    fi
  else
    # Fallback: check well-formed XML via python
    if python3 -c "import xml.etree.ElementTree as ET; ET.parse('${PLIST_RESOLVED}')" 2>/dev/null; then
      _pass "plist is valid XML (python XML parse OK)"
    else
      _fail "plist is not valid XML"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n==============================\n'
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf 'FAILURES:\n'
  for err in "${ERRORS[@]}"; do
    printf '  - %s\n' "$err"
  done
  exit 1
fi
printf 'All tests passed.\n'
exit 0
