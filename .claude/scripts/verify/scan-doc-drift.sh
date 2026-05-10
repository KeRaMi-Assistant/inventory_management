#!/usr/bin/env bash
# verify/scan-doc-drift.sh — Self-contained test suite for scan-doc-drift.sh
#
# Tests:
#   1. No code diff vs base ref         → no item
#   2. Code diff + handbook recently updated → no item
#   3. Code diff + handbook stale           → 1 item with correct frontmatter
#   4. Re-run (same drift)               → no duplicate (file-dedup)
#   5. 4th attempt → 7d-pause + no item
#   6. Inbox-Cap > 50                    → SKIP
#
# Exit 0 if all tests pass, exit 1 on first failure.

set -uo pipefail

PASS=0
FAIL=0

_pass() { printf '  [PASS] %s\n' "$1"; PASS=$(( PASS + 1 )); }
_fail() { printf '  [FAIL] %s\n' "$1"; FAIL=$(( FAIL + 1 )); }

# ---------------------------------------------------------------------------
# Locate module
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE="$SCRIPT_DIR/../../analyzer/modules/scan-doc-drift.sh"

if [ ! -f "$MODULE" ]; then
  printf 'ERROR: Module not found: %s\n' "$MODULE"
  exit 1
fi

# ---------------------------------------------------------------------------
# Git mock helpers
#
# We cannot rely on a real git history in the sandbox, so we inject a
# GIT_CMD wrapper script that returns controlled output per-test.
#
# The module calls git in two ways:
#   git diff "$BASE_REF...HEAD" --name-only        → code-changed files
#   git log --since=... --name-only --format="" -- 'docs/handbook/*' → handbook
#
# Our mock dispatches on "$@" pattern.
# ---------------------------------------------------------------------------

_mk_git_mock() {
  local sandbox="$1"
  local diff_output="$2"      # what 'git diff' should return
  local handbook_output="$3"  # what 'git log' for handbook should return

  local bin="$sandbox/bin"
  mkdir -p "$bin"

  # Write the mock git wrapper
  cat > "$bin/git" <<GITEOF
#!/usr/bin/env bash
# Mock git for scan-doc-drift tests

ARGS="\$*"

if echo "\$ARGS" | grep -q "diff"; then
  printf '%s\n' "$diff_output"
  exit 0
fi

if echo "\$ARGS" | grep -q "log"; then
  printf '%s\n' "$handbook_output"
  exit 0
fi

# Fallback: real git (shouldn't be needed in tests)
/usr/bin/git "\$@"
GITEOF
  chmod +x "$bin/git"
  printf '%s/bin/git' "$sandbox"
}

_run_module() {
  local sandbox="$1"
  shift
  CLAUDE_PROJECT_DIR="$sandbox" \
  ANALYZER_STATE_FILE="$sandbox/state/scan-doc-drift.json" \
  OVERSEER_INBOX_DIR="$sandbox/inbox" \
  GIT_CMD="$sandbox/bin/git" \
  DOC_DRIFT_BASE_REF="origin/main" \
  DOC_DRIFT_HANDBOOK_SINCE="7 days ago" \
  NOTIFY_DRY_RUN=1 \
  bash "$MODULE" "$@" 2>&1
}

_mk_sandbox() {
  local sb
  sb="$(mktemp -d)"
  mkdir -p "$sb/inbox" "$sb/state" "$sb/bin" "$sb/docs/handbook"
  printf '%s' "$sb"
}

# ---------------------------------------------------------------------------
# Test 1: No code diff → no item
# ---------------------------------------------------------------------------
printf '\nTest 1: No code diff → no item\n'

SB1="$(_mk_sandbox)"
_mk_git_mock "$SB1" "" "" > /dev/null

_run_module "$SB1" > /dev/null 2>&1

ITEM_COUNT="$(find "$SB1/inbox" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
if [ "$ITEM_COUNT" -eq 0 ]; then
  _pass "no item written when no code diff"
else
  _fail "expected 0 items, got $ITEM_COUNT"
fi
rm -rf "$SB1"

# ---------------------------------------------------------------------------
# Test 2: Code diff + handbook recently updated → no item
# ---------------------------------------------------------------------------
printf '\nTest 2: Code diff + handbook recently updated → no item\n'

SB2="$(_mk_sandbox)"
DIFF_OUT="lib/screens/foo_screen.dart
supabase/functions/my-fn/index.ts"
HANDBOOK_OUT="docs/handbook/03-screens-walkthrough.md"
_mk_git_mock "$SB2" "$DIFF_OUT" "$HANDBOOK_OUT" > /dev/null

_run_module "$SB2" > /dev/null 2>&1

ITEM_COUNT="$(find "$SB2/inbox" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
if [ "$ITEM_COUNT" -eq 0 ]; then
  _pass "no item when handbook recently updated"
else
  _fail "expected 0 items, got $ITEM_COUNT"
fi
rm -rf "$SB2"

# ---------------------------------------------------------------------------
# Test 3: Code diff + handbook stale → 1 item with correct frontmatter
# ---------------------------------------------------------------------------
printf '\nTest 3: Code diff + handbook stale → 1 item + frontmatter\n'

SB3="$(_mk_sandbox)"
DIFF_OUT3="lib/screens/new_screen.dart
supabase/migrations/20260510120000_new_table.sql"
_mk_git_mock "$SB3" "$DIFF_OUT3" "" > /dev/null

_run_module "$SB3" > /dev/null 2>&1

ITEM_COUNT="$(find "$SB3/inbox" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
if [ "$ITEM_COUNT" -eq 1 ]; then
  _pass "exactly 1 item written"
else
  _fail "expected 1 item, got $ITEM_COUNT"
fi

# Frontmatter checks
ITEM_FILE3="$(find "$SB3/inbox" -maxdepth 1 -name "*.md" | head -n1)"
if [ -n "$ITEM_FILE3" ]; then
  if grep -q 'source: tier-3' "$ITEM_FILE3"; then
    _pass "source: tier-3"
  else
    _fail "source field missing or wrong"
  fi

  if grep -q 'touches: \[docs/handbook/\]' "$ITEM_FILE3"; then
    _pass "touches: [docs/handbook/]"
  else
    _fail "touches field missing or wrong (expected 'touches: [docs/handbook/]')"
  fi

  if grep -q 'model: sonnet' "$ITEM_FILE3"; then
    _pass "model: sonnet"
  else
    _fail "model field missing or wrong"
  fi

  if grep -q 'priority: 2' "$ITEM_FILE3"; then
    _pass "priority: 2"
  else
    _fail "priority field missing or wrong"
  fi

  if grep -q 'budget_usd: 1.5' "$ITEM_FILE3"; then
    _pass "budget_usd: 1.5"
  else
    _fail "budget_usd field missing or wrong"
  fi

  if grep -q 'created_from: scan-doc-drift' "$ITEM_FILE3"; then
    _pass "created_from: scan-doc-drift"
  else
    _fail "created_from field missing or wrong"
  fi

  if grep -q 'update-docs' "$ITEM_FILE3"; then
    _pass "body mentions update-docs"
  else
    _fail "body missing update-docs reference"
  fi
else
  _fail "no item file found to inspect frontmatter"
fi

# ---------------------------------------------------------------------------
# Test 4: Re-run → no duplicate (file-dedup)
# ---------------------------------------------------------------------------
printf '\nTest 4: Re-run → no duplicate\n'

_run_module "$SB3" > /dev/null 2>&1

ITEM_COUNT="$(find "$SB3/inbox" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
if [ "$ITEM_COUNT" -eq 1 ]; then
  _pass "still exactly 1 item (no duplicate)"
else
  _fail "expected 1 item, got $ITEM_COUNT (duplicate written)"
fi

rm -rf "$SB3"

# ---------------------------------------------------------------------------
# Test 5: 4th attempt → 7d-pause, no item
# ---------------------------------------------------------------------------
printf '\nTest 5: 4th attempt → 7d-pause, no item\n'

SB5="$(_mk_sandbox)"
DIFF_OUT5="lib/screens/another_screen.dart"
_mk_git_mock "$SB5" "$DIFF_OUT5" "" > /dev/null

# Compute expected hash
SORTED_FILES5="lib/screens/another_screen.dart|"
HASH_INPUT5="scan-doc-drift${SORTED_FILES5}"
FULL_HASH5="$(printf '%s' "$HASH_INPUT5" | shasum -a 256 | awk '{print $1}')"

NOW_ISO5="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
A1="$(python3 -c "import datetime; print((datetime.datetime.utcnow() - datetime.timedelta(days=5)).strftime('%Y-%m-%dT%H:%M:%SZ'))")"
A2="$(python3 -c "import datetime; print((datetime.datetime.utcnow() - datetime.timedelta(days=3)).strftime('%Y-%m-%dT%H:%M:%SZ'))")"
A3="$(python3 -c "import datetime; print((datetime.datetime.utcnow() - datetime.timedelta(days=1)).strftime('%Y-%m-%dT%H:%M:%SZ'))")"

python3 - "$SB5/state/scan-doc-drift.json" "$FULL_HASH5" "$A1" "$A2" "$A3" "$NOW_ISO5" <<'PYEOF'
import sys, json
sf, h, a1, a2, a3, first = sys.argv[1:]
state = {
    "last_run": first,
    "subjects": {
        h: {
            "label": "doc-drift-test",
            "first_seen": first,
            "last_attempts": [a1, a2, a3],
            "paused_until": None,
        }
    }
}
with open(sf, 'w') as f:
    json.dump(state, f, indent=2)
PYEOF

_run_module "$SB5" > /dev/null 2>&1

ITEM_COUNT5="$(find "$SB5/inbox" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
PAUSED5="$(python3 -c "
import json
with open('$SB5/state/scan-doc-drift.json') as f:
    d = json.load(f)
subjs = d.get('subjects', {})
paused = any(v.get('paused_until') for v in subjs.values())
print(paused)
" 2>/dev/null || echo False)"

if [ "$ITEM_COUNT5" -eq 0 ] && [ "$PAUSED5" = "True" ]; then
  _pass "4th attempt paused subject, no item written"
elif [ "$ITEM_COUNT5" -gt 0 ]; then
  _fail "expected 0 items after pause trigger, got $ITEM_COUNT5"
else
  _fail "expected paused_until set; PAUSED=$PAUSED5 items=$ITEM_COUNT5"
fi

rm -rf "$SB5"

# ---------------------------------------------------------------------------
# Test 6: Inbox-Cap > 50 → SKIP
# ---------------------------------------------------------------------------
printf '\nTest 6: Inbox-Cap > 50 → SKIP\n'

SB6="$(_mk_sandbox)"
DIFF_OUT6="lib/screens/capped_screen.dart"
_mk_git_mock "$SB6" "$DIFF_OUT6" "" > /dev/null

# Fill inbox with 51 dummy files
for i in $(seq 1 51); do
  printf -- '---\nslug: dummy-%d\n---\n' "$i" > "$SB6/inbox/dummy-${i}.md"
done

OUTPUT6="$(_run_module "$SB6" 2>&1)"

if printf '%s' "$OUTPUT6" | grep -q 'SKIP'; then
  _pass "inbox-cap triggered SKIP"
else
  _fail "expected SKIP in output, got: $OUTPUT6"
fi

rm -rf "$SB6"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n========================================\n'
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"
printf '========================================\n'

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
