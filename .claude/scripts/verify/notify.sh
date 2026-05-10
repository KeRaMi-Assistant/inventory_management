#!/usr/bin/env bash
# verify/notify.sh — Sandbox tests for notify.sh
#
# Usage: bash .claude/scripts/verify/notify.sh
# Exit 0 = all pass, exit 1 = one or more failures.
#
# Mock strategy:
#   NOTIFY_DRY_RUN=1        — logs to sent.jsonl instead of real curl
#   NOTIFY_MOCK_HOUR=<H>    — overrides current hour for Quiet-Hours tests
#   NOTIFY_DEDUP_TTL=<sec>  — overrides dedup TTL (use low value for tests)
#
# Isolation: each test gets a fresh temp dir as NOTIFY_TEST_DIR.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOTIFY="$SCRIPT_DIR/../notify.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# ---------------------------------------------------------------------------
# Test framework
# ---------------------------------------------------------------------------
_pass=0
_fail=0

ok() {
  printf '  [PASS] %s\n' "$1"
  _pass=$(( _pass + 1 ))
}

fail() {
  printf '  [FAIL] %s\n' "$1" >&2
  _fail=$(( _fail + 1 ))
}

assert_eq() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [ "$expected" = "$actual" ]; then
    ok "$label (expected=$expected)"
  else
    fail "$label (expected=$expected, actual=$actual)"
  fi
}

# ---------------------------------------------------------------------------
# Setup: point overseer/notifications to a temp dir for isolation
# ---------------------------------------------------------------------------
_tmpdir="$(mktemp -d /tmp/notify_verify.XXXXXX)"
trap 'rm -rf "$_tmpdir"' EXIT INT TERM

# Patch: override the NOTIF_DIR by providing a fake repo root structure.
# We symlink the real scripts/lib so audit.sh can be sourced.
mkdir -p "$_tmpdir/repo/.claude/scripts/lib"
mkdir -p "$_tmpdir/repo/.claude/overseer/notifications"
# Copy notify.sh into fake repo hierarchy
cp "$NOTIFY" "$_tmpdir/repo/.claude/scripts/notify.sh"
# Copy notify-impl.sh shim-target if present (P0-7 split)
if [ -f "$SCRIPT_DIR/../lib/notify-impl.sh" ]; then
  cp "$SCRIPT_DIR/../lib/notify-impl.sh" "$_tmpdir/repo/.claude/scripts/lib/notify-impl.sh"
  chmod +x "$_tmpdir/repo/.claude/scripts/lib/notify-impl.sh"
fi
chmod +x "$_tmpdir/repo/.claude/scripts/notify.sh"
# Copy audit lib if present
[ -f "$REPO_ROOT/.claude/scripts/lib/audit.sh" ] && \
  cp "$REPO_ROOT/.claude/scripts/lib/audit.sh" "$_tmpdir/repo/.claude/scripts/lib/audit.sh"

# Wrapper: invoke notify.sh with REPO_ROOT pointing at our sandbox.
# We also need to override the repo-root detection inside notify.sh.
# Strategy: the script uses SCRIPT_DIR to find REPO_ROOT. Since we copied
# notify.sh into _tmpdir/repo/.claude/scripts/, REPO_ROOT auto-resolves to
# _tmpdir/repo — which is exactly what we want.

NOTIF_DIR="$_tmpdir/repo/.claude/overseer/notifications"
SENT="$NOTIF_DIR/sent.jsonl"
QUEUED="$NOTIF_DIR/queued.jsonl"
DEDUP="$NOTIF_DIR/dedup.jsonl"

# Use NOTIFY_MOCK_HOUR=12 (noon) so tests run outside Quiet-Hours by default.
_notify() {
  NOTIFY_DRY_RUN=1 NTFY_TOPIC=test-topic NOTIFY_MOCK_HOUR=12 \
    bash "$_tmpdir/repo/.claude/scripts/notify.sh" "$@" 2>/dev/null
}

_notify_stderr() {
  NOTIFY_DRY_RUN=1 NTFY_TOPIC=test-topic NOTIFY_MOCK_HOUR=12 \
    bash "$_tmpdir/repo/.claude/scripts/notify.sh" "$@" 2>&1 1>/dev/null
}

_count_sent() {
  wc -l < "$SENT" 2>/dev/null | tr -d ' ' || echo 0
}

_count_queued() {
  wc -l < "$QUEUED" 2>/dev/null | tr -d ' ' || echo 0
}

_reset() {
  : > "$SENT"
  : > "$QUEUED"
  : > "$DEDUP"
}

# ---------------------------------------------------------------------------
# Test 1: 2× identical info-push binnen 4h → 1 send, 1 skip (dedup)
# ---------------------------------------------------------------------------
printf '\nTest 1: Dedup — 2 identical info pushes → only 1 sent\n'
_reset
_notify info test-topic "Test Title" "Test body"
_notify info test-topic "Test Title" "Test body"
_cnt="$(_count_sent)"
assert_eq "Sent count = 1" "1" "$_cnt"

# ---------------------------------------------------------------------------
# Test 2: 2× identical critical-push → 2 sends (dedup bypass)
# ---------------------------------------------------------------------------
printf '\nTest 2: Dedup bypass for critical — 2 identical critical pushes → 2 sent\n'
_reset
_notify critical test-topic "Critical Alert" "Disk full"
_notify critical test-topic "Critical Alert" "Disk full"
_cnt="$(_count_sent)"
assert_eq "Sent count = 2" "2" "$_cnt"

# ---------------------------------------------------------------------------
# Test 3: Quiet-Hours info — mock hour 23 → queued, not sent
# ---------------------------------------------------------------------------
printf '\nTest 3: Quiet-Hours — info at 23:30 → queued\n'
_reset
NOTIFY_DRY_RUN=1 NTFY_TOPIC=test-topic NOTIFY_MOCK_HOUR=23 QUIET_HOURS_START=22 QUIET_HOURS_END=8 \
  bash "$_tmpdir/repo/.claude/scripts/notify.sh" info test-topic "Night title" "Night body" 2>/dev/null || true
_sent="$(_count_sent)"
_queued="$(_count_queued)"
assert_eq "Sent count = 0 (quiet)" "0" "$_sent"
assert_eq "Queued count = 1" "1" "$_queued"

# ---------------------------------------------------------------------------
# Test 4: Quiet-Hours critical — mock hour 23 → sent (bypass)
# ---------------------------------------------------------------------------
printf '\nTest 4: Quiet-Hours bypass for critical — critical at 23:30 → sent\n'
_reset
NOTIFY_DRY_RUN=1 NTFY_TOPIC=test-topic NOTIFY_MOCK_HOUR=23 QUIET_HOURS_START=22 QUIET_HOURS_END=8 \
  bash "$_tmpdir/repo/.claude/scripts/notify.sh" critical test-topic "CRITICAL Night" "Something broke" 2>/dev/null || true
_sent="$(_count_sent)"
_queued="$(_count_queued)"
assert_eq "Sent count = 1 (critical bypasses quiet)" "1" "$_sent"
assert_eq "Queued count = 0" "0" "$_queued"

# ---------------------------------------------------------------------------
# Test 5: noise → no send, only stderr log
# ---------------------------------------------------------------------------
printf '\nTest 5: Noise severity → no send, stderr note\n'
_reset
_stderr="$(_notify_stderr noise test-topic "Worker started" "Running task abc")"
_sent="$(_count_sent)"
assert_eq "Sent count = 0 for noise" "0" "$_sent"
if printf '%s' "$_stderr" | grep -q "noise:"; then
  ok "stderr contains 'noise:' note"
else
  fail "stderr missing noise note (got: $_stderr)"
fi

# ---------------------------------------------------------------------------
# Test 6: make_action_buttons → valid JSON
# ---------------------------------------------------------------------------
printf '\nTest 6: make_action_buttons → valid ntfy Actions JSON\n'
# Call make_action_buttons by sourcing notify.sh helpers in a subshell.
# We need the path available inside the subshell, so export it first.
export _NOTIFY_SH_PATH="$_tmpdir/repo/.claude/scripts/notify.sh"
# P0-7 split: extract from notify-impl.sh if shim is in use
if grep -q "exec.*notify-impl.sh" "$_NOTIFY_SH_PATH" 2>/dev/null \
   && [ -f "$_tmpdir/repo/.claude/scripts/lib/notify-impl.sh" ]; then
  export _NOTIFY_SH_PATH="$_tmpdir/repo/.claude/scripts/lib/notify-impl.sh"
fi
_json="$(bash <<'SUBSH'
# Extract the make_action_buttons function definition from notify.sh and eval it
_func_def="$(python3 -c "
import re, sys
txt = open(sys.argv[1]).read()
m = re.search(r'(make_action_buttons\(\) \{.*?\n\})', txt, re.DOTALL)
if m: print(m.group(1))
" "$_NOTIFY_SH_PATH")"
eval "$_func_def"
make_action_buttons "Pause:https://example.com/pause" "Details:https://example.com/detail"
SUBSH
)"
# Validate JSON
if python3 -c "import sys,json; a=json.loads(sys.argv[1]); assert len(a)==2; assert a[0]['action']=='http'" "$_json" 2>/dev/null; then
  ok "make_action_buttons produced valid ntfy JSON with 2 actions"
else
  fail "make_action_buttons JSON invalid: $_json"
fi

# Test the label parsing
_label="$(python3 -c "import sys,json; a=json.loads(sys.argv[1]); print(a[0]['label'])" "$_json" 2>/dev/null || echo "")"
assert_eq "First button label = Pause" "Pause" "$_label"

# ---------------------------------------------------------------------------
# Test 7: Truncation — title > 50 chars → truncated
# ---------------------------------------------------------------------------
printf '\nTest 7: Truncation — title >50 chars\n'
_reset
_long_title="This is a very long title that exceeds the fifty-character limit set by mobile UX policy"
_notify info test-topic "$_long_title" "Normal body"
# Read from sent.jsonl and check title length
_sent_title="$(python3 -c "
import sys, json
try:
    with open(sys.argv[1]) as f:
        lines = [l.strip() for l in f if l.strip()]
    if lines:
        d = json.loads(lines[-1])
        print(d.get('title',''))
except Exception as e:
    print('ERROR:' + str(e))
" "$SENT" 2>/dev/null || echo "")"
_title_len="${#_sent_title}"
if [ "$_title_len" -le 50 ]; then
  ok "Sent title length <= 50 (got: $_title_len, value: '$_sent_title')"
else
  fail "Sent title too long: $_title_len chars: '$_sent_title'"
fi
# Check that it ends with "..."
if [[ "$_sent_title" == *"..." ]]; then
  ok "Truncated title ends with '...'"
else
  fail "Truncated title does not end with '...': '$_sent_title'"
fi

# ---------------------------------------------------------------------------
# Test 8: Failed curl (mock) → notify.sh exits 0 (graceful)
# ---------------------------------------------------------------------------
printf '\nTest 8: Failed curl → graceful exit 0\n'
# Use a fake curl that fails; bypass NOTIFY_DRY_RUN so real curl path is taken.
_fake_curl_dir="$(mktemp -d /tmp/fakecurl.XXXXXX)"
cat > "$_fake_curl_dir/curl" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$_fake_curl_dir/curl"

# Run without dry-run so the real curl codepath is exercised.
_exit_code=0
PATH="$_fake_curl_dir:$PATH" NTFY_TOPIC=test-topic NOTIFY_MOCK_HOUR=12 \
  bash "$_tmpdir/repo/.claude/scripts/notify.sh" info test-topic "Net fail" "curl fails" 2>/dev/null || _exit_code=$?
rm -rf "$_fake_curl_dir"
assert_eq "Exit code = 0 on curl failure" "0" "$_exit_code"

# ---------------------------------------------------------------------------
# Test 9: Backwards-compat legacy invocation → treated as info, stderr warning
# ---------------------------------------------------------------------------
printf '\nTest 9: Backwards-compat — legacy 3-arg invocation\n'
_reset
_stderr="$( NOTIFY_DRY_RUN=1 NTFY_TOPIC=test-topic NOTIFY_MOCK_HOUR=12 \
  bash "$_tmpdir/repo/.claude/scripts/notify.sh" "Old Title" "Old body" "success" 2>&1 1>/dev/null)"
if printf '%s' "$_stderr" | grep -q "legacy invocation"; then
  ok "stderr contains 'legacy invocation' warning"
else
  fail "stderr missing legacy warning (got: $_stderr)"
fi
# And it should still have sent something
_sent="$(_count_sent)"
if [ "$_sent" -ge 1 ]; then
  ok "Legacy call still triggered a send (sent=$_sent)"
else
  fail "Legacy call did not send anything"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n--- Verify Summary ---\n'
printf 'PASS: %d  FAIL: %d\n' "$_pass" "$_fail"

if [ "$_fail" -gt 0 ]; then
  exit 1
fi
exit 0
