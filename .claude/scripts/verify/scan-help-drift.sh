#!/usr/bin/env bash
# verify/scan-help-drift.sh — Self-contained test suite for scan-help-drift.sh
#
# Tests:
#   1. No UI diff → no item written
#   2. lib/screens diff + help recently updated → no item (no drift)
#   3. lib/screens diff + help stale (>7d) → 1 item
#   4. ARB changes + ARB stale → drift detected (1 item)
#   5. Re-run → no duplicate
#   6. 4th attempt → 7d pause, no item
#   7. --dry-run → stdout, no file
#   8. --status → state JSON to stdout
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
MODULE="$SCRIPT_DIR/../../analyzer/modules/scan-help-drift.sh"

if [ ! -f "$MODULE" ]; then
  printf 'ERROR: Module not found: %s\n' "$MODULE"
  exit 1
fi

# ---------------------------------------------------------------------------
# Helper: run module in a given sandbox with overrides
# ---------------------------------------------------------------------------
_run_module() {
  local sb="$1"; shift
  local diff_files="${DIFF_FILES_OVERRIDE:-}"
  local help_mtime="${HELP_MTIME_OVERRIDE:-0}"
  local arb_de_mtime="${ARB_DE_MTIME_OVERRIDE:-0}"
  local arb_en_mtime="${ARB_EN_MTIME_OVERRIDE:-0}"

  CLAUDE_PROJECT_DIR="$sb" \
  ANALYZER_STATE_FILE="$sb/state/scan-help-drift.json" \
  OVERSEER_INBOX_DIR="$sb/inbox" \
  GIT_DIFF_CMD="printf '%s\n' \"${diff_files}\"" \
  HELP_SCREEN_MTIME="$help_mtime" \
  ARB_DE_MTIME="$arb_de_mtime" \
  ARB_EN_MTIME="$arb_en_mtime" \
  NOTIFY_DRY_RUN=1 \
  bash "$MODULE" "$@" 2>&1
}

_mk_sandbox() {
  local sb
  sb="$(mktemp -d)"
  mkdir -p "$sb/inbox" "$sb/state"
  mkdir -p "$sb/lib/screens" "$sb/lib/l10n" "$sb/lib/services"
  printf '// help_screen placeholder\n' > "$sb/lib/screens/help_screen.dart"
  printf '// login_screen placeholder\n' > "$sb/lib/screens/login_screen.dart"
  printf '// service placeholder\n' > "$sb/lib/services/inbox_service.dart"
  printf '{}' > "$sb/lib/l10n/app_de.arb"
  printf '{}' > "$sb/lib/l10n/app_en.arb"
  echo "$sb"
}

NOW_EPOCH="$(date -u +%s)"
RECENT_MTIME="$NOW_EPOCH"                          # just now → not stale
STALE_MTIME=$(( NOW_EPOCH - 8 * 86400 ))           # 8 days ago → stale

# ---------------------------------------------------------------------------
# Test 1: No UI diff → no item
# ---------------------------------------------------------------------------
printf '\nTest 1: No UI diff → no item\n'
SB1="$(_mk_sandbox)"
trap 'rm -rf "$SB1"' EXIT

DIFF_FILES_OVERRIDE="" \
HELP_MTIME_OVERRIDE="$RECENT_MTIME" \
ARB_DE_MTIME_OVERRIDE="$RECENT_MTIME" \
ARB_EN_MTIME_OVERRIDE="$RECENT_MTIME" \
_run_module "$SB1" > /dev/null 2>&1

CNT="$(find "$SB1/inbox" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
if [ "$CNT" -eq 0 ]; then
  _pass "no item written when no diff"
else
  _fail "expected 0 items, got $CNT"
fi

# ---------------------------------------------------------------------------
# Test 2: lib/screens diff but help recently updated → no item
# ---------------------------------------------------------------------------
printf '\nTest 2: lib/screens diff + help recently updated → no drift\n'
SB2="$(_mk_sandbox)"
trap 'rm -rf "$SB1" "$SB2"' EXIT

DIFF_FILES_OVERRIDE="lib/screens/login_screen.dart" \
HELP_MTIME_OVERRIDE="$RECENT_MTIME" \
ARB_DE_MTIME_OVERRIDE="0" \
ARB_EN_MTIME_OVERRIDE="0" \
_run_module "$SB2" > /dev/null 2>&1

CNT="$(find "$SB2/inbox" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
if [ "$CNT" -eq 0 ]; then
  _pass "no item when help recently updated"
else
  _fail "expected 0 items, got $CNT"
fi

# ---------------------------------------------------------------------------
# Test 3: lib/screens diff + help stale → 1 item
# ---------------------------------------------------------------------------
printf '\nTest 3: lib/screens diff + help stale (>7d) → 1 item\n'
SB3="$(_mk_sandbox)"
trap 'rm -rf "$SB1" "$SB2" "$SB3"' EXIT

DIFF_FILES_OVERRIDE="lib/screens/login_screen.dart" \
HELP_MTIME_OVERRIDE="$STALE_MTIME" \
ARB_DE_MTIME_OVERRIDE="$STALE_MTIME" \
ARB_EN_MTIME_OVERRIDE="$STALE_MTIME" \
_run_module "$SB3" > /dev/null 2>&1

CNT="$(find "$SB3/inbox" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
if [ "$CNT" -eq 1 ]; then
  _pass "1 item written on drift"
else
  _fail "expected 1 item, got $CNT"
fi

# Verify frontmatter
ITEM3="$(find "$SB3/inbox" -maxdepth 1 -name "*.md" | head -n1)"
if [ -n "$ITEM3" ]; then
  if grep -q 'source: tier-3' "$ITEM3"; then
    _pass "frontmatter: source=tier-3"
  else
    _fail "frontmatter: source missing or wrong"
  fi
  if grep -q 'model: sonnet' "$ITEM3"; then
    _pass "frontmatter: model=sonnet"
  else
    _fail "frontmatter: model missing or wrong"
  fi
  if grep -q 'priority: 2' "$ITEM3"; then
    _pass "frontmatter: priority=2"
  else
    _fail "frontmatter: priority missing or wrong"
  fi
  if grep -q 'touches:' "$ITEM3" && grep -q 'help_screen.dart' "$ITEM3"; then
    _pass "frontmatter: touches contains help_screen.dart"
  else
    _fail "frontmatter: touches missing or wrong"
  fi
fi

# ---------------------------------------------------------------------------
# Test 4: ARB changes + ARB stale → drift detected
# ---------------------------------------------------------------------------
printf '\nTest 4: ARB changes + ARB stale → drift detected\n'
SB4="$(_mk_sandbox)"
trap 'rm -rf "$SB1" "$SB2" "$SB3" "$SB4"' EXIT

DIFF_FILES_OVERRIDE="lib/l10n/app_de.arb" \
HELP_MTIME_OVERRIDE="$STALE_MTIME" \
ARB_DE_MTIME_OVERRIDE="$STALE_MTIME" \
ARB_EN_MTIME_OVERRIDE="$STALE_MTIME" \
_run_module "$SB4" > /dev/null 2>&1

CNT="$(find "$SB4/inbox" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
if [ "$CNT" -eq 1 ]; then
  _pass "ARB drift detected → 1 item"
else
  _fail "expected 1 item for ARB drift, got $CNT"
fi

# ---------------------------------------------------------------------------
# Test 5: Re-run → no duplicate
# ---------------------------------------------------------------------------
printf '\nTest 5: Re-run → no duplicate\n'
# Re-use SB3 which already has 1 item from Test 3
DIFF_FILES_OVERRIDE="lib/screens/login_screen.dart" \
HELP_MTIME_OVERRIDE="$STALE_MTIME" \
ARB_DE_MTIME_OVERRIDE="$STALE_MTIME" \
ARB_EN_MTIME_OVERRIDE="$STALE_MTIME" \
_run_module "$SB3" > /dev/null 2>&1

CNT="$(find "$SB3/inbox" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
if [ "$CNT" -eq 1 ]; then
  _pass "still 1 item on re-run (no duplicate)"
else
  _fail "expected 1 item, got $CNT (duplicate written)"
fi

# ---------------------------------------------------------------------------
# Test 6: 4th attempt → 7d-pause, no item
# ---------------------------------------------------------------------------
printf '\nTest 6: 4th attempt → 7d-pause, no item\n'
SB6="$(_mk_sandbox)"
trap 'rm -rf "$SB1" "$SB2" "$SB3" "$SB4" "$SB6"' EXIT

# Compute the drift hash for our diff string
DIFF_STR="lib/screens/login_screen.dart"
# The module sorts + pipes to produce hash input: "scan-help-drift<file>|"
SORTED="$(printf '%s\n' "$DIFF_STR" | sort | tr '\n' '|')"
HASH_INPUT="scan-help-drift${SORTED}"
FULL_HASH="$(printf '%s' "$HASH_INPUT" | shasum -a 256 | awk '{print $1}')"

A1="$(python3 -c "import datetime; print((datetime.datetime.utcnow() - datetime.timedelta(days=5)).strftime('%Y-%m-%dT%H:%M:%SZ'))")"
A2="$(python3 -c "import datetime; print((datetime.datetime.utcnow() - datetime.timedelta(days=3)).strftime('%Y-%m-%dT%H:%M:%SZ'))")"
A3="$(python3 -c "import datetime; print((datetime.datetime.utcnow() - datetime.timedelta(days=1)).strftime('%Y-%m-%dT%H:%M:%SZ'))")"
NOW_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

python3 - "$SB6/state/scan-help-drift.json" "$FULL_HASH" "$A1" "$A2" "$A3" "$NOW_ISO" <<'PYEOF'
import sys, json
sf, h, a1, a2, a3, first = sys.argv[1:]
state = {
    "last_run": first,
    "subjects": {
        h: {
            "label": "help-drift-test",
            "first_seen": first,
            "last_attempts": [a1, a2, a3],
            "paused_until": None,
        }
    }
}
with open(sf, 'w') as f:
    json.dump(state, f, indent=2)
PYEOF

DIFF_FILES_OVERRIDE="lib/screens/login_screen.dart" \
HELP_MTIME_OVERRIDE="$STALE_MTIME" \
ARB_DE_MTIME_OVERRIDE="$STALE_MTIME" \
ARB_EN_MTIME_OVERRIDE="$STALE_MTIME" \
_run_module "$SB6" > /dev/null 2>&1

CNT6="$(find "$SB6/inbox" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
PAUSED="$(python3 -c "
import json
with open('$SB6/state/scan-help-drift.json') as f:
    d = json.load(f)
subjs = d.get('subjects', {})
paused = any(v.get('paused_until') for v in subjs.values())
print(paused)
" 2>/dev/null || echo False)"

if [ "$CNT6" -eq 0 ] && [ "$PAUSED" = "True" ]; then
  _pass "4th attempt: subject paused, no item written"
elif [ "$CNT6" -gt 0 ]; then
  _fail "expected 0 items after pause trigger, got $CNT6"
else
  _fail "expected paused_until set; PAUSED=$PAUSED items=$CNT6"
fi

# ---------------------------------------------------------------------------
# Test 7: --dry-run → stdout, no file
# ---------------------------------------------------------------------------
printf '\nTest 7: --dry-run → stdout, no file\n'
SB7="$(_mk_sandbox)"
trap 'rm -rf "$SB1" "$SB2" "$SB3" "$SB4" "$SB6" "$SB7"' EXIT

OUT7="$(DIFF_FILES_OVERRIDE="lib/screens/login_screen.dart" \
  HELP_MTIME_OVERRIDE="$STALE_MTIME" \
  ARB_DE_MTIME_OVERRIDE="$STALE_MTIME" \
  ARB_EN_MTIME_OVERRIDE="$STALE_MTIME" \
  _run_module "$SB7" --dry-run 2>&1)"

CNT7="$(find "$SB7/inbox" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"

if printf '%s' "$OUT7" | grep -q 'dry-run'; then
  _pass "--dry-run output contains 'dry-run'"
else
  _fail "--dry-run output missing 'dry-run' marker; got: $OUT7"
fi

if [ "$CNT7" -eq 0 ]; then
  _pass "--dry-run wrote no file"
else
  _fail "--dry-run should not write files, got $CNT7"
fi

# ---------------------------------------------------------------------------
# Test 8: --status → JSON to stdout
# ---------------------------------------------------------------------------
printf '\nTest 8: --status → state JSON to stdout\n'
SB8="$(_mk_sandbox)"
trap 'rm -rf "$SB1" "$SB2" "$SB3" "$SB4" "$SB6" "$SB7" "$SB8"' EXIT

# First run to create state
DIFF_FILES_OVERRIDE="lib/screens/login_screen.dart" \
HELP_MTIME_OVERRIDE="$STALE_MTIME" \
ARB_DE_MTIME_OVERRIDE="$STALE_MTIME" \
ARB_EN_MTIME_OVERRIDE="$STALE_MTIME" \
_run_module "$SB8" > /dev/null 2>&1

OUT8="$(CLAUDE_PROJECT_DIR="$SB8" \
  ANALYZER_STATE_FILE="$SB8/state/scan-help-drift.json" \
  OVERSEER_INBOX_DIR="$SB8/inbox" \
  NOTIFY_DRY_RUN=1 \
  bash "$MODULE" --status 2>&1)"

if python3 -c "import sys,json; json.loads(sys.argv[1])" "$OUT8" 2>/dev/null; then
  _pass "--status returns valid JSON"
else
  _fail "--status did not return valid JSON: $OUT8"
fi

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
