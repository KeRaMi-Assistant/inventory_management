#!/usr/bin/env bash
# verify/scan-l10n-drift.sh — Self-contained test suite for scan-l10n-drift.sh
#
# Tests:
#   1. Clean (mock check-l10n exit 0, empty drift)  → no item written
#   2. Mock-Drift → 1 item with correct frontmatter
#   3. Re-Run → no duplicate (file-dedup)
#   4. 4th attempt → 7d pause + notify (no item)
#   5. Inbox-Cap > 50 → SKIP
#   6. --dry-run → stdout, no file
#   7. Frontmatter fields: source=tier-3, touches=[lib/l10n/], model=haiku
#
# Exit 0 if all tests pass, exit 1 on first failure.

set -uo pipefail

PASS=0
FAIL=0

_pass() { printf '  [PASS] %s\n' "$1"; PASS=$(( PASS + 1 )); }
_fail() { printf '  [FAIL] %s\n' "$1"; FAIL=$(( FAIL + 1 )); }

# ---------------------------------------------------------------------------
# Setup sandbox
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE="$SCRIPT_DIR/../../analyzer/modules/scan-l10n-drift.sh"

if [ ! -f "$MODULE" ]; then
  printf 'ERROR: Module not found: %s\n' "$MODULE"
  exit 1
fi

# Create sandbox directory structure
mkdir -p "$SANDBOX/inbox"
mkdir -p "$SANDBOX/state"
mkdir -p "$SANDBOX/bin"
mkdir -p "$SANDBOX/notify"

# Mock notify.sh (no-op)
cat > "$SANDBOX/notify/notify.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$SANDBOX/notify/notify.sh"

# Helper: create mock check-l10n.py stub
_mk_stub_clean() {
  cat > "$SANDBOX/bin/check-l10n-stub.py" <<'EOF'
#!/usr/bin/env python3
import json, sys
print(json.dumps({
    "date": "2026-05-10",
    "de_keys": 10,
    "en_keys": 10,
    "missing_in_en": [],
    "missing_in_de": [],
    "placeholder_mismatch": [],
    "metadata_warnings": [],
    "hardcoded_strings": [],
    "fixed_keys": [],
    "has_findings": False,
}))
sys.exit(0)
EOF
  chmod +x "$SANDBOX/bin/check-l10n-stub.py"
}

_mk_stub_drift() {
  cat > "$SANDBOX/bin/check-l10n-stub.py" <<'EOF'
#!/usr/bin/env python3
import json, sys
print(json.dumps({
    "date": "2026-05-10",
    "de_keys": 12,
    "en_keys": 10,
    "missing_in_en": ["keyA", "keyB"],
    "missing_in_de": [],
    "placeholder_mismatch": [{"key": "keyC", "de": ["count"], "en": []}],
    "metadata_warnings": [],
    "hardcoded_strings": [{"file": "lib/screens/foo.dart", "line": 42, "snippet": "Text('Schließen')", "text": "Schließen"}],
    "fixed_keys": [],
    "has_findings": True,
}))
sys.exit(1)
EOF
  chmod +x "$SANDBOX/bin/check-l10n-stub.py"
}

_run_module() {
  CLAUDE_PROJECT_DIR="$SANDBOX" \
  ANALYZER_STATE_FILE="$SANDBOX/state/scan-l10n-drift.json" \
  OVERSEER_INBOX_DIR="$SANDBOX/inbox" \
  CHECK_L10N_CMD="python3 $SANDBOX/bin/check-l10n-stub.py" \
  NOTIFY_DRY_RUN=1 \
  bash "$MODULE" "$@" 2>&1
}

# ---------------------------------------------------------------------------
# Test 1: Clean — no drift → no item
# ---------------------------------------------------------------------------
printf '\nTest 1: Clean (empty drift) → no item\n'
_mk_stub_clean
_run_module > /dev/null 2>&1

ITEM_COUNT="$(find "$SANDBOX/inbox" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
if [ "$ITEM_COUNT" -eq 0 ]; then
  _pass "no item written"
else
  _fail "expected 0 items, got $ITEM_COUNT"
fi

# ---------------------------------------------------------------------------
# Test 2: Mock drift → exactly 1 item
# ---------------------------------------------------------------------------
printf '\nTest 2: Mock drift → 1 item\n'
_mk_stub_drift
_run_module > /dev/null 2>&1

ITEM_COUNT="$(find "$SANDBOX/inbox" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
if [ "$ITEM_COUNT" -eq 1 ]; then
  _pass "exactly 1 item written"
else
  _fail "expected 1 item, got $ITEM_COUNT"
fi

# ---------------------------------------------------------------------------
# Test 7: Frontmatter fields (source, touches, model) — checked on the item from Test 2
# ---------------------------------------------------------------------------
printf '\nTest 7: Frontmatter fields\n'
ITEM_FILE="$(find "$SANDBOX/inbox" -maxdepth 1 -name "*.md" | head -n1)"

if [ -z "$ITEM_FILE" ]; then
  _fail "no item file to inspect"
else
  if grep -q 'source: tier-3' "$ITEM_FILE"; then
    _pass "source: tier-3"
  else
    _fail "source field missing or wrong"
  fi

  if grep -q 'touches: \[lib/l10n/\]' "$ITEM_FILE"; then
    _pass "touches: [lib/l10n/]"
  else
    _fail "touches field missing or wrong (expected 'touches: [lib/l10n/]')"
  fi

  if grep -q 'model: haiku' "$ITEM_FILE"; then
    _pass "model: haiku"
  else
    _fail "model field missing or wrong"
  fi

  if grep -q 'priority: 1' "$ITEM_FILE"; then
    _pass "priority: 1"
  else
    _fail "priority field missing or wrong"
  fi
fi

# ---------------------------------------------------------------------------
# Test 3: Re-run → no duplicate (file already exists)
# ---------------------------------------------------------------------------
printf '\nTest 3: Re-run → no duplicate\n'
_mk_stub_drift
_run_module > /dev/null 2>&1

ITEM_COUNT="$(find "$SANDBOX/inbox" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
if [ "$ITEM_COUNT" -eq 1 ]; then
  _pass "still exactly 1 item (no duplicate)"
else
  _fail "expected 1 item, got $ITEM_COUNT (duplicate written)"
fi

# ---------------------------------------------------------------------------
# Test 4: 4th attempt (after 3 previous) → pause + no new item
# ---------------------------------------------------------------------------
printf '\nTest 4: 4th attempt → 7d-pause, no item\n'

# New sandbox for clean state
SANDBOX4="$(mktemp -d)"
mkdir -p "$SANDBOX4/inbox" "$SANDBOX4/state" "$SANDBOX4/bin" "$SANDBOX4/notify"
cp "$SANDBOX/bin/check-l10n-stub.py" "$SANDBOX4/bin/check-l10n-stub.py"

# Inject state with 3 recent attempts for the expected drift hash
DRIFT_KEYS="keyA|keyB|keyC|lib/screens/foo.dart:42"
HASH_INPUT="scan-l10n-drift${DRIFT_KEYS}"
FULL_HASH="$(printf '%s' "$HASH_INPUT" | shasum -a 256 | awk '{print $1}')"

NOW_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
ATTEMPT1="$(python3 -c "import datetime; print((datetime.datetime.utcnow() - datetime.timedelta(days=5)).strftime('%Y-%m-%dT%H:%M:%SZ'))")"
ATTEMPT2="$(python3 -c "import datetime; print((datetime.datetime.utcnow() - datetime.timedelta(days=3)).strftime('%Y-%m-%dT%H:%M:%SZ'))")"
ATTEMPT3="$(python3 -c "import datetime; print((datetime.datetime.utcnow() - datetime.timedelta(days=1)).strftime('%Y-%m-%dT%H:%M:%SZ'))")"

python3 - "$SANDBOX4/state/scan-l10n-drift.json" "$FULL_HASH" "$ATTEMPT1" "$ATTEMPT2" "$ATTEMPT3" "$NOW_ISO" <<'PYEOF'
import sys, json
sf, h, a1, a2, a3, first = sys.argv[1:]
state = {
    "last_run": first,
    "subjects": {
        h: {
            "label": "l10n-drift-test",
            "first_seen": first,
            "last_attempts": [a1, a2, a3],
            "paused_until": None,
        }
    }
}
with open(sf, 'w') as f:
    json.dump(state, f, indent=2)
PYEOF

OUTPUT4="$(CLAUDE_PROJECT_DIR="$SANDBOX4" \
  ANALYZER_STATE_FILE="$SANDBOX4/state/scan-l10n-drift.json" \
  OVERSEER_INBOX_DIR="$SANDBOX4/inbox" \
  CHECK_L10N_CMD="python3 $SANDBOX4/bin/check-l10n-stub.py" \
  NOTIFY_DRY_RUN=1 \
  bash "$MODULE" 2>&1)"

ITEM_COUNT4="$(find "$SANDBOX4/inbox" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
PAUSED="$(python3 -c "
import json, sys
with open('$SANDBOX4/state/scan-l10n-drift.json') as f:
    d = json.load(f)
subjs = d.get('subjects', {})
paused = any(v.get('paused_until') for v in subjs.values())
print(paused)
" 2>/dev/null || echo False)"

if [ "$ITEM_COUNT4" -eq 0 ] && [ "$PAUSED" = "True" ]; then
  _pass "4th attempt paused subject, no item written"
elif [ "$ITEM_COUNT4" -gt 0 ]; then
  _fail "expected 0 items after pause trigger, got $ITEM_COUNT4"
else
  _fail "expected paused_until set; PAUSED=$PAUSED items=$ITEM_COUNT4"
fi

rm -rf "$SANDBOX4"

# ---------------------------------------------------------------------------
# Test 5: Inbox-Cap > 50 → SKIP
# ---------------------------------------------------------------------------
printf '\nTest 5: Inbox-Cap > 50 → SKIP\n'

SANDBOX5="$(mktemp -d)"
mkdir -p "$SANDBOX5/inbox" "$SANDBOX5/state" "$SANDBOX5/bin"
cp "$SANDBOX/bin/check-l10n-stub.py" "$SANDBOX5/bin/check-l10n-stub.py"
# Create 51 dummy md files in inbox
for i in $(seq 1 51); do
  printf -- '---\nslug: dummy-%d\n---\n' "$i" > "$SANDBOX5/inbox/dummy-${i}.md"
done

OUTPUT5="$(CLAUDE_PROJECT_DIR="$SANDBOX5" \
  ANALYZER_STATE_FILE="$SANDBOX5/state/scan-l10n-drift.json" \
  OVERSEER_INBOX_DIR="$SANDBOX5/inbox" \
  CHECK_L10N_CMD="python3 $SANDBOX5/bin/check-l10n-stub.py" \
  NOTIFY_DRY_RUN=1 \
  bash "$MODULE" 2>&1)"

if printf '%s' "$OUTPUT5" | grep -q 'SKIP'; then
  _pass "inbox-cap triggered SKIP"
else
  _fail "expected SKIP in output, got: $OUTPUT5"
fi

rm -rf "$SANDBOX5"

# ---------------------------------------------------------------------------
# Test 6: --dry-run → stdout, no file written
# ---------------------------------------------------------------------------
printf '\nTest 6: --dry-run → stdout, no file\n'

SANDBOX6="$(mktemp -d)"
mkdir -p "$SANDBOX6/inbox" "$SANDBOX6/state" "$SANDBOX6/bin"
cp "$SANDBOX/bin/check-l10n-stub.py" "$SANDBOX6/bin/check-l10n-stub.py"

OUTPUT6="$(CLAUDE_PROJECT_DIR="$SANDBOX6" \
  ANALYZER_STATE_FILE="$SANDBOX6/state/scan-l10n-drift.json" \
  OVERSEER_INBOX_DIR="$SANDBOX6/inbox" \
  CHECK_L10N_CMD="python3 $SANDBOX6/bin/check-l10n-stub.py" \
  NOTIFY_DRY_RUN=1 \
  bash "$MODULE" --dry-run 2>&1)"

ITEM_COUNT6="$(find "$SANDBOX6/inbox" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"

if printf '%s' "$OUTPUT6" | grep -q 'dry-run'; then
  _pass "--dry-run output contains 'dry-run'"
else
  _fail "--dry-run output missing 'dry-run' marker; got: $OUTPUT6"
fi

if [ "$ITEM_COUNT6" -eq 0 ]; then
  _pass "--dry-run wrote no file"
else
  _fail "--dry-run should not write files, got $ITEM_COUNT6"
fi

rm -rf "$SANDBOX6"

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
