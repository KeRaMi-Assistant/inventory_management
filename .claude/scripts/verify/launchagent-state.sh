#!/usr/bin/env bash
# Verify correct LaunchAgent state after Phase-4 migration.
# Exit 0 = all tests pass.

set -euo pipefail

PASS=0
FAIL=0
WARN=0

HEADLESS_LABEL="com.kerami.inventory.headless"
OVERSEER_LABEL="com.inventory.overseer"
HEADLESS_PLIST="$HOME/Library/LaunchAgents/$HEADLESS_LABEL.plist"
UNINSTALL_SCRIPT="$(cd "$(dirname "$0")/../.." && pwd)/scripts/uninstall-headless.sh"
CLAUDE_MD="$(cd "$(dirname "$0")/../.." && pwd)/../CLAUDE.md"

pass() { echo "  PASS: $1"; ((PASS++)) || true; }
fail() { echo "  FAIL: $1"; ((FAIL++)) || true; }
warn() { echo "  WARN: $1"; ((WARN++)) || true; }

# --- Mock support ---
LAUNCHCTL="launchctl"
if [[ "${MOCK_LAUNCHCTL:-}" == "1" ]]; then
  if [[ -z "${MOCK_LAUNCHCTL_DIR:-}" ]]; then
    echo "ERROR: MOCK_LAUNCHCTL=1 requires MOCK_LAUNCHCTL_DIR to be set." >&2
    exit 2
  fi
  LAUNCHCTL="$MOCK_LAUNCHCTL_DIR/launchctl"
fi

echo "=== LaunchAgent State Verification (Phase-4 Migration) ==="
echo ""

# Test 1: Headless LaunchAgent NOT loaded
echo "[1] Headless LaunchAgent not loaded"
if "$LAUNCHCTL" list 2>/dev/null | grep -qi "$HEADLESS_LABEL"; then
  fail "$HEADLESS_LABEL is still loaded — run: bash .claude/scripts/uninstall-headless.sh"
else
  pass "$HEADLESS_LABEL is not loaded"
fi

# Test 2: Headless plist file removed
echo "[2] Headless plist file removed"
if [[ -f "$HEADLESS_PLIST" ]]; then
  fail "Plist still exists at $HEADLESS_PLIST"
else
  pass "Plist file absent ($HEADLESS_PLIST)"
fi

# Test 3: uninstall-headless.sh still in repo
echo "[3] uninstall-headless.sh present (fallback)"
if [[ -f "$UNINSTALL_SCRIPT" ]]; then
  pass "uninstall-headless.sh exists at $UNINSTALL_SCRIPT"
else
  fail "uninstall-headless.sh missing — should remain in repo as fallback"
fi

# Test 4: CLAUDE.md contains Phase-4 migration note
echo "[4] CLAUDE.md contains Phase-4 migration note"
if grep -qiE "(Phase.4.*Migration|autonomous.swarm|overseer.*übernimmt)" "$CLAUDE_MD" 2>/dev/null; then
  pass "CLAUDE.md contains Phase-4 migration reference"
else
  fail "CLAUDE.md missing Phase-4 migration note — add to § Headless-Loop"
fi

# Test 5 (optional): Overseer LaunchAgent available
echo "[5] Overseer LaunchAgent (optional — loaded or not)"
if "$LAUNCHCTL" list 2>/dev/null | grep -qi "$OVERSEER_LABEL"; then
  pass "$OVERSEER_LABEL is loaded"
else
  warn "$OVERSEER_LABEL is not loaded yet — OK if Phase-4 setup not complete"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed, $WARN warnings ==="

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
