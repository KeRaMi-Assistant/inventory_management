#!/usr/bin/env bash
# verify/scan-test-coverage.sh — Sandbox tests for scan-test-coverage.sh
#
# Tests:
#   1. Mock no flutter in PATH → exit 0, no item
#   2. Mock initial 70% coverage → state updated, no item
#   3. Mock drop to 60% (10pt drop) → 1 item
#   4. Mock drop to 65% (5pt drop from 70) → 1 item (= threshold)
#   5. Mock drop to 67% (3pt drop from 70) → 0 items
#   6. Re-run after alert: hysteresis — no re-alert until recovery
#   7. Inbox-Cap > 50 → SKIP, no item

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
MODULE="$REPO_ROOT/.claude/analyzer/modules/scan-test-coverage.sh"

PASS=0
FAIL=0
_ok()   { printf '  ✓ %s\n' "$1"; PASS=$(( PASS + 1 )); }
_fail() { printf '  ✗ %s\n' "$1"; FAIL=$(( FAIL + 1 )); }

# ---------------------------------------------------------------------------
# Sandbox setup
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d /tmp/verify-scan-test-coverage-XXXXXX)"
trap 'rm -rf "$SANDBOX"' EXIT

INBOX_DIR="$SANDBOX/inbox"
STATE_DIR="$SANDBOX/state"
COVERAGE_DIR="$SANDBOX/coverage"
MOCK_BIN="$SANDBOX/bin"

mkdir -p "$INBOX_DIR" "$STATE_DIR" "$COVERAGE_DIR" "$MOCK_BIN"

STATE_FILE="$STATE_DIR/scan-test-coverage.json"

# Helper: count items in inbox
_item_count() { find "$INBOX_DIR" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l | tr -d ' '; }

# Helper: run module with sandbox environment
_run_module() {
  CLAUDE_PROJECT_DIR="$REPO_ROOT" \
  ANALYZER_STATE_FILE="$STATE_FILE" \
  OVERSEER_INBOX_DIR="$INBOX_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  PATH="$MOCK_BIN:$PATH" \
    bash "$MODULE" "$@" 2>&1
}

# Helper: write lcov.info with given coverage for lib/services/fake.dart
_write_lcov() {
  local hit="$1" found="$2"
  cat > "$COVERAGE_DIR/lcov.info" <<LCOVEOF
SF:lib/services/fake_service.dart
DA:1,1
DA:2,1
DA:3,$( [ "$hit" -ge 3 ] && echo 1 || echo 0 )
LH:${hit}
LF:${found}
end_of_record
LCOVEOF
}

# Helper: write a more accurate lcov with configurable pct
# hit/found determines pct. For pct X%, set found=100, hit=X
_write_lcov_pct() {
  local pct="$1"
  local found=100
  local hit="$pct"
  # Write 100 DA lines
  {
    printf 'SF:lib/services/fake_service.dart\n'
    for i in $(seq 1 100); do
      if [ "$i" -le "$hit" ]; then
        printf 'DA:%d,1\n' "$i"
      else
        printf 'DA:%d,0\n' "$i"
      fi
    done
    printf 'LH:%d\nLF:%d\nend_of_record\n' "$hit" "$found"
  } > "$COVERAGE_DIR/lcov.info"
}

# Helper: write state JSON
_write_state() {
  local last_cov="$1" last_alert="${2:-null}" fix_attempt="${3:-0}" paused="${4:-null}"
  cat > "$STATE_FILE" <<STEOF
{
  "last_run": null,
  "last_coverage_pct": ${last_cov},
  "last_alert_pct": ${last_alert},
  "last_fix_attempt": ${fix_attempt},
  "paused_until": ${paused}
}
STEOF
}

# ---------------------------------------------------------------------------
# Create a mock flutter binary that runs flutter test --coverage
# ---------------------------------------------------------------------------
_install_mock_flutter() {
  # This mock writes coverage/lcov.info (already written by test) and exits 0
  cat > "$MOCK_BIN/flutter" <<'MOCKEOF'
#!/usr/bin/env bash
# Mock flutter: if called with "test --coverage", just exit 0
# (lcov.info is pre-written by the test harness)
if [[ "$*" == *"test"* ]] && [[ "$*" == *"--coverage"* ]]; then
  exit 0
fi
exit 0
MOCKEOF
  chmod +x "$MOCK_BIN/flutter"
}

_remove_mock_flutter() {
  rm -f "$MOCK_BIN/flutter"
}

# ---------------------------------------------------------------------------
# Test 1: No flutter in PATH → exit 0, no item
# ---------------------------------------------------------------------------
printf '\nTest 1: No flutter in PATH → exit 0, no item\n'
rm -f "$STATE_FILE"
rm -f "$INBOX_DIR"/*.md 2>/dev/null || true

# Create a "no-flutter" bin dir that contains everything EXCEPT flutter
NO_FLUTTER_BIN="$SANDBOX/no-flutter-bin"
mkdir -p "$NO_FLUTTER_BIN"
# Add a fake flutter that is NOT executable / doesn't exist
# Use a PATH that has no flutter: override PATH to be minimal
output="$(CLAUDE_PROJECT_DIR="$REPO_ROOT" \
  ANALYZER_STATE_FILE="$STATE_FILE" \
  OVERSEER_INBOX_DIR="$INBOX_DIR" \
  COVERAGE_DIR="$COVERAGE_DIR" \
  PATH="$NO_FLUTTER_BIN:/usr/bin:/bin" \
    bash "$MODULE" 2>&1)" || true
cnt="$(_item_count)"

if printf '%s' "$output" | grep -q "flutter not in PATH"; then
  _ok "warning about missing flutter"
else
  _fail "expected 'flutter not in PATH' warning, got: $output"
fi

if [ "$cnt" -eq 0 ]; then
  _ok "no item generated"
else
  _fail "expected 0 items, got $cnt"
fi

# ---------------------------------------------------------------------------
# Test 2: Initial coverage 70% → state updated, no item
# ---------------------------------------------------------------------------
printf '\nTest 2: Initial 70%% coverage → state updated, no item\n'
_install_mock_flutter
rm -f "$STATE_FILE"
rm -f "$INBOX_DIR"/*.md 2>/dev/null || true
_write_lcov_pct 70

output="$(_run_module 2>&1)"
cnt="$(_item_count)"

if [ "$cnt" -eq 0 ]; then
  _ok "no item on initial coverage"
else
  _fail "expected 0 items, got $cnt"
fi

if [ -f "$STATE_FILE" ]; then
  stored="$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d.get('last_coverage_pct'))")"
  if [ "$stored" = "70.0" ] || [ "$stored" = "70" ]; then
    _ok "state file records 70.0% coverage"
  else
    _fail "state should store 70.0 but got: $stored"
  fi
else
  _fail "state file not created"
fi

# ---------------------------------------------------------------------------
# Test 3: Drop to 60% (10pt drop from 70) → 1 item
# ---------------------------------------------------------------------------
printf '\nTest 3: Drop 70%% → 60%% (10pt) → 1 item\n'
_write_state 70.0 null 0
rm -f "$INBOX_DIR"/*.md 2>/dev/null || true
_write_lcov_pct 60

output="$(_run_module 2>&1)"
cnt="$(_item_count)"

if [ "$cnt" -eq 1 ]; then
  _ok "1 item generated for 10pt drop"
else
  _fail "expected 1 item, got $cnt — output: $output"
fi

# Verify item content
if [ "$cnt" -ge 1 ]; then
  item_file="$(find "$INBOX_DIR" -maxdepth 1 -name '*.md' | head -1)"
  if grep -q 'priority: 0' "$item_file"; then
    _ok "item has priority 0 (high)"
  else
    _fail "item missing priority: 0"
  fi
  if grep -q 'test-coverage-drop' "$item_file"; then
    _ok "item slug contains test-coverage-drop"
  else
    _fail "item slug missing test-coverage-drop"
  fi
fi

# ---------------------------------------------------------------------------
# Test 4: Drop to 65% (exactly 5pt from 70) → 1 item (= threshold)
# ---------------------------------------------------------------------------
printf '\nTest 4: Drop 70%% → 65%% (exactly 5pt) → 1 item\n'
_write_state 70.0 null 0
rm -f "$INBOX_DIR"/*.md 2>/dev/null || true
_write_lcov_pct 65

output="$(_run_module 2>&1)"
cnt="$(_item_count)"

if [ "$cnt" -eq 1 ]; then
  _ok "1 item generated for exactly 5pt drop"
else
  _fail "expected 1 item, got $cnt — output: $output"
fi

# ---------------------------------------------------------------------------
# Test 5: Drop to 67% (3pt drop from 70) → 0 items (below threshold)
# ---------------------------------------------------------------------------
printf '\nTest 5: Drop 70%% → 67%% (3pt) → 0 items\n'
_write_state 70.0 null 0
rm -f "$INBOX_DIR"/*.md 2>/dev/null || true
_write_lcov_pct 67

output="$(_run_module 2>&1)"
cnt="$(_item_count)"

if [ "$cnt" -eq 0 ]; then
  _ok "no item for 3pt drop (below 5pt threshold)"
else
  _fail "expected 0 items, got $cnt"
fi

# ---------------------------------------------------------------------------
# Test 6: Hysteresis — after alert at 60%, no re-alert until recovery
# ---------------------------------------------------------------------------
printf '\nTest 6: Hysteresis — re-run after alert, no second item until recovery\n'
# Simulate: last_cov=60, last_alert=60 (alert was sent at 60%), fix_attempt=1
# Now coverage is still 60 — should NOT alert again
_write_state 60.0 60.0 1
rm -f "$INBOX_DIR"/*.md 2>/dev/null || true
_write_lcov_pct 60

output="$(_run_module 2>&1)"
cnt="$(_item_count)"

if [ "$cnt" -eq 0 ]; then
  _ok "no item on re-run (hysteresis active, coverage at last_alert level)"
else
  _fail "expected 0 items (hysteresis), got $cnt — output: $output"
fi

# Now simulate a slight dip further: 58% — still within last_alert-hysteresis range?
# last_alert=60, hysteresis=2 → recovery required: last_cov must reach 60+2=62 before new alert
# Current last_cov=60 < 62 → suppress
_write_state 60.0 60.0 1
rm -f "$INBOX_DIR"/*.md 2>/dev/null || true
_write_lcov_pct 58  # 2pt drop from 60

output="$(_run_module 2>&1)"
cnt="$(_item_count)"

if [ "$cnt" -eq 0 ]; then
  _ok "no item when last_cov < last_alert+hysteresis (suppress)"
else
  _fail "expected 0 items (suppress), got $cnt — output: $output"
fi

# Now simulate recovery then drop: last_cov=65 (recovered past 62), now drop to 58
_write_state 65.0 60.0 1
rm -f "$INBOX_DIR"/*.md 2>/dev/null || true
_write_lcov_pct 58   # 7pt drop from 65

output="$(_run_module 2>&1)"
cnt="$(_item_count)"

if [ "$cnt" -eq 1 ]; then
  _ok "item generated after recovery (last_cov=65 >= last_alert+hysteresis=62)"
else
  _fail "expected 1 item after recovery, got $cnt — output: $output"
fi

# ---------------------------------------------------------------------------
# Test 7: Inbox-Cap > 50 → SKIP
# ---------------------------------------------------------------------------
printf '\nTest 7: Inbox-Cap > 50 → SKIP\n'
_write_state 70.0 null 0
rm -f "$INBOX_DIR"/*.md 2>/dev/null || true
# Create 51 dummy items
for i in $(seq 1 51); do
  touch "$INBOX_DIR/dummy-item-${i}.md"
done
_write_lcov_pct 55  # Would normally trigger

output="$(_run_module 2>&1)"
# Count only non-dummy items
new_items="$(find "$INBOX_DIR" -maxdepth 1 -name '*.md' -newer "$INBOX_DIR/dummy-item-1.md" 2>/dev/null | wc -l | tr -d ' ')"

if printf '%s' "$output" | grep -qi "SKIP"; then
  _ok "SKIP message present"
else
  _fail "expected SKIP message, got: $output"
fi

total_cnt="$(_item_count)"
if [ "$total_cnt" -eq 51 ]; then
  _ok "no new item when inbox cap exceeded (still 51 dummy items)"
else
  _fail "expected 51 total items (51 dummies, no new), got $total_cnt"
fi

_remove_mock_flutter

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== scan-test-coverage verify: %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
