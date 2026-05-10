#!/usr/bin/env bash
# verify/launchagent-overseer.sh — Sandbox tests for install/uninstall-overseer.sh
#
# Uses a temp dir as mock ~/Library/LaunchAgents to avoid touching the real system.
# All launchctl calls are skipped or noted when not available / not on macOS.
#
# Exit 0 = all tests passed (skipped tests are OK, documented below).
# Exit 1 = at least one test FAILED.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
INSTALL_SH="$ROOT/.claude/scripts/install-overseer.sh"
UNINSTALL_SH="$ROOT/.claude/scripts/uninstall-overseer.sh"
TEMPLATE="$ROOT/.claude/overseer-launchagent.plist.template"

PASS=0
FAIL=0
SKIP=0

_pass() { printf '[PASS] %s\n' "$1"; PASS=$((PASS+1)); }
_fail() { printf '[FAIL] %s\n' "$1" >&2; FAIL=$((FAIL+1)); }
_skip() { printf '[SKIP] %s\n' "$1"; SKIP=$((SKIP+1)); }

# ---------------------------------------------------------------------------
# Sandbox: use a tmpdir so we never touch ~/Library/LaunchAgents
# ---------------------------------------------------------------------------
TMPDIR_BASE="$(mktemp -d)"
MOCK_AGENTS="$TMPDIR_BASE/agents"
mkdir -p "$MOCK_AGENTS"
export LAUNCH_AGENTS_DIR="$MOCK_AGENTS"

LABEL="com.inventory.overseer"
TARGET_PLIST="$MOCK_AGENTS/$LABEL.plist"

_cleanup() {
  rm -rf "$TMPDIR_BASE"
}
trap _cleanup EXIT

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
_have_launchctl() {
  command -v launchctl >/dev/null 2>&1
}

_is_macos() {
  [[ "$(uname)" == "Darwin" ]]
}

# ---------------------------------------------------------------------------
# Test 1: install without --load-now → plist exists, NOT loaded
# ---------------------------------------------------------------------------
bash "$INSTALL_SH" >/dev/null 2>&1

if [ -f "$TARGET_PLIST" ]; then
  _pass "T1: plist written to mock LAUNCH_AGENTS_DIR"
else
  _fail "T1: plist NOT found at $TARGET_PLIST"
fi

# Verify NOT loaded (launchctl list should not contain the label in mock context).
# In sandbox (LAUNCH_AGENTS_DIR overridden) launchctl was never called with --load-now,
# so the real system agent is absent. Check via launchctl list if available.
if _have_launchctl && _is_macos; then
  if launchctl list 2>/dev/null | grep -q "^[^$]*[[:space:]]$LABEL$"; then
    _fail "T1: agent is loaded in launchctl — expected NOT loaded (--load-now not passed)"
  else
    _pass "T1: agent not loaded in launchctl (correct — RunAtLoad=false, no --load-now)"
  fi
else
  _skip "T1 launchctl-load-check: launchctl not available or not macOS"
fi

# ---------------------------------------------------------------------------
# Test 2: plist passes plutil / xmllint lint
# ---------------------------------------------------------------------------
if _is_macos && command -v plutil >/dev/null 2>&1; then
  if plutil -lint "$TARGET_PLIST" >/dev/null 2>&1; then
    _pass "T2: plutil -lint OK"
  else
    _fail "T2: plutil -lint FAILED"
  fi
elif command -v xmllint >/dev/null 2>&1; then
  if xmllint --noout "$TARGET_PLIST" 2>/dev/null; then
    _pass "T2: xmllint --noout OK"
  else
    _fail "T2: xmllint FAILED"
  fi
else
  _skip "T2: neither plutil nor xmllint available"
fi

# ---------------------------------------------------------------------------
# Test 3: required plist fields present
# ---------------------------------------------------------------------------
_plist_has() {
  local field="$1" expected="$2"
  if grep -q "$expected" "$TARGET_PLIST" 2>/dev/null; then
    _pass "T3: plist contains $field=$expected"
  else
    _fail "T3: plist MISSING $field=$expected"
  fi
}

_plist_has "Label" "com.inventory.overseer"
_plist_has "KeepAlive" "<true/>"
_plist_has "RunAtLoad" "<false/>"
_plist_has "ThrottleInterval" "<integer>10</integer>"
_plist_has "ProcessType" "Background"

# ProgramArguments: overseer.sh path
if grep -q "overseer.sh" "$TARGET_PLIST"; then
  _pass "T3: ProgramArguments references overseer.sh"
else
  _fail "T3: ProgramArguments does NOT reference overseer.sh"
fi

# CLAUDE_PROJECT_DIR environment variable
if grep -q "CLAUDE_PROJECT_DIR" "$TARGET_PLIST"; then
  _pass "T3: EnvironmentVariables contains CLAUDE_PROJECT_DIR"
else
  _fail "T3: EnvironmentVariables missing CLAUDE_PROJECT_DIR"
fi

# StandardOutPath / StandardErrorPath
if grep -q "overseer.out.log" "$TARGET_PLIST"; then
  _pass "T3: StandardOutPath = overseer.out.log"
else
  _fail "T3: StandardOutPath missing overseer.out.log"
fi

if grep -q "overseer.err.log" "$TARGET_PLIST"; then
  _pass "T3: StandardErrorPath = overseer.err.log"
else
  _fail "T3: StandardErrorPath missing overseer.err.log"
fi

# ---------------------------------------------------------------------------
# Test 4: --load-now flag
# NOTE: We SKIP the actual launchctl load because loading into the real
#   launchd requires the real ~/Library/LaunchAgents path (LaunchAgents
#   dir cannot be overridden in launchctl itself). Running a real load
#   in a sandboxed test would side-effect the user's launchd session.
#   Manual verification procedure is documented below.
# ---------------------------------------------------------------------------
_skip "T4 --load-now: real launchctl load skipped in sandbox (side-effects user launchd). Manual verify: bash install-overseer.sh --load-now && launchctl list | grep com.inventory.overseer"

# ---------------------------------------------------------------------------
# Test 5: Restart-within-10s (plan acceptance criterion)
# NOTE: Requires a real launchd session with the plist loaded into the
#   actual ~/Library/LaunchAgents. Cannot be automated in a sandbox.
#   macOS-only manual verify required.
# ---------------------------------------------------------------------------
_skip "T5 kill-9-restart [macOS-only manual verify required]: load agent → kill -9 \$(pgrep -f overseer.sh) → should restart within ThrottleInterval (10s) via KeepAlive=true. Run manually after 'bash install-overseer.sh --load-now'."

# ---------------------------------------------------------------------------
# Test 6: Uninstall — plist removed, launchctl unloaded
# ---------------------------------------------------------------------------
# plist still present from T1 install; now uninstall.
bash "$UNINSTALL_SH" >/dev/null 2>&1 || true

if [ ! -f "$TARGET_PLIST" ]; then
  _pass "T6: plist removed after uninstall"
else
  _fail "T6: plist still exists after uninstall"
fi

# After uninstall, agent must not be in launchctl list.
if _have_launchctl && _is_macos; then
  if launchctl list 2>/dev/null | grep -q "^[^$]*[[:space:]]$LABEL$"; then
    _fail "T6: agent still in launchctl after uninstall"
  else
    _pass "T6: agent absent from launchctl after uninstall"
  fi
else
  _skip "T6 launchctl-unload-check: not macOS or no launchctl"
fi

# Idempotent second uninstall — must not fail
bash "$UNINSTALL_SH" >/dev/null 2>&1 && _pass "T6: uninstall idempotent (second call exit 0)" \
  || _fail "T6: second uninstall call failed (not idempotent)"

# ---------------------------------------------------------------------------
# Test 7: Conflict-check — mock headless plist in sandbox dir triggers warning
#
# We cannot mock `launchctl list` reliably across all environments, so we
# simulate the check by temporarily creating a com.inventory.headless plist
# and inspecting that the script *would* check launchctl. The install script
# warns only when launchctl list matches the headless label — which in our
# sandbox it won't, since we didn't load anything. We verify:
#   a) install completes exit 0 regardless (no block)
#   b) the script references the headless label (grep script source)
# ---------------------------------------------------------------------------
mkdir -p "$MOCK_AGENTS"
# Create a dummy headless plist file (won't be loaded, but presence tests path logic)
touch "$MOCK_AGENTS/com.kerami.inventory.headless.plist"

set +e
install_out="$(bash "$INSTALL_SH" 2>&1)"
install_rc=$?
set -e

if [ "$install_rc" -eq 0 ]; then
  _pass "T7: install exits 0 even when headless plist present in LAUNCH_AGENTS_DIR"
else
  _fail "T7: install exits $install_rc with headless plist present (expected 0)"
fi

# Verify the script source contains conflict-check logic referencing headless label.
if grep -q "com.kerami.inventory.headless" "$INSTALL_SH"; then
  _pass "T7: install-overseer.sh contains conflict-check for headless label"
else
  _fail "T7: install-overseer.sh missing conflict-check for headless label"
fi

# Clean up
rm -f "$MOCK_AGENTS/com.kerami.inventory.headless.plist"

# ---------------------------------------------------------------------------
# Template integrity: all __PLACEHOLDER__ values are substituted in plist
# ---------------------------------------------------------------------------
if [ -f "$MOCK_AGENTS/$LABEL.plist" ] && grep -q '__REPO_ROOT__\|__HOME__' "$MOCK_AGENTS/$LABEL.plist" 2>/dev/null; then
  _fail "Template: unsubstituted placeholders found in generated plist"
else
  _pass "Template: all placeholders substituted in generated plist"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n'
printf '=== launchagent-overseer verify summary ===\n'
printf 'PASS: %d  FAIL: %d  SKIP: %d\n' "$PASS" "$FAIL" "$SKIP"

if [ "$SKIP" -gt 0 ]; then
  printf '\nSkipped tests require manual macOS verification:\n'
  printf '  T4: bash .claude/scripts/install-overseer.sh --load-now\n'
  printf '       → launchctl list | grep com.inventory.overseer\n'
  printf '  T5: kill -9 $(pgrep -f overseer.sh)\n'
  printf '       → process restarts within 10s (ThrottleInterval=10, KeepAlive=true)\n'
fi

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
