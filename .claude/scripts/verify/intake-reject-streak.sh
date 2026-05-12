#!/usr/bin/env bash
# verify/intake-reject-streak.sh — Acceptance tests for T17 (Reject-Streak-Notify).
#
# Tests the reject-streak logic in telegram-bot.py via direct Python imports.
#
# Exit 0 = all tests passed.
# Exit 1 = one or more tests failed.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
BOT_PY="$REAL_REPO_ROOT/.claude/scripts/telegram-bot.py"

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
TMP="$(mktemp -d)"
NOTIFY_SENT="$TMP/.claude/overseer/notifications/sent.jsonl"
STREAK_FILE="$TMP/.claude/intake-council/state/reject-streak.json"

_cleanup() {
  chflags -R nouchg "$TMP" 2>/dev/null || true
  chmod -R u+w "$TMP" 2>/dev/null || true
  rm -rf "$TMP"
}
trap '_cleanup' EXIT

mkdir -p "$TMP/.claude/overseer/notifications"
mkdir -p "$TMP/.claude/intake-council/state"
mkdir -p "$TMP/.claude/stakeholder/rejected"
mkdir -p "$TMP/.claude/stakeholder/pending-approval"
mkdir -p "$TMP/.claude/audit"
mkdir -p "$TMP/.claude/scripts/lib"

# Stub audit.sh
cat > "$TMP/.claude/scripts/lib/audit.sh" <<'STUB'
audit_record() { :; }
STUB

# Stub notify.sh
mkdir -p "$TMP/.claude/scripts"
cat > "$TMP/.claude/scripts/notify.sh" <<'STUB'
#!/usr/bin/env bash
mkdir -p "${REPO_ROOT:-/tmp}/.claude/overseer/notifications"
printf '{"severity":"%s","topic":"%s","title":"%s","body":"%s"}\n' \
  "${1:-}" "${2:-}" "${3:-}" "${4:-}" \
  >> "${REPO_ROOT:-/tmp}/.claude/overseer/notifications/sent.jsonl"
STUB
chmod +x "$TMP/.claude/scripts/notify.sh"

# Python helper: run streak test code against the bot module
run_py() {
  local script="$1"
  REPO_ROOT="$TMP" \
  CLAUDE_PROJECT_DIR="$TMP" \
  TELEGRAM_BOT_TOKEN="mock-token" \
  TELEGRAM_ALLOWED_USER_IDS="12345" \
  MOCK_INTAKE_COUNCIL_CMD="echo pass" \
  MOCK_INTAKE_VALIDATOR_CMD="echo pass" \
    python3 - "$BOT_PY" "$TMP" <<PYEOF
import sys, os, pathlib, importlib.util, time, json

bot_path = sys.argv[1]
tmp_root = pathlib.Path(sys.argv[2])

# Patch sys.path and load module without executing __main__
spec = importlib.util.spec_from_file_location("telegram_bot", bot_path)
mod = importlib.util.module_from_spec(spec)
# Avoid running the server loop
import unittest.mock as mock
with mock.patch.object(spec.loader, 'exec_module', lambda m: None):
    pass

# Exec the module manually but patch the blocking parts
original_exec = spec.loader.exec_module
def safe_exec(module):
    # We need the module-level code to run to get function defs, but not
    # the __main__ block. We'll do a selective exec.
    original_exec(module)
spec.loader.exec_module = safe_exec

# Actually just exec the file text as Python with __name__ != '__main__'
src = pathlib.Path(bot_path).read_text(encoding='utf-8')
# Inject REPO_ROOT override before exec
src = f'import os; os.environ["REPO_ROOT"] = {repr(str(tmp_root))}\n' + src
globs = {"__name__": "not_main", "__file__": bot_path}
exec(compile(src, bot_path, 'exec'), globs)

${script}
PYEOF
}

printf '\n=== intake-reject-streak.sh verification ===\n'

# ---------------------------------------------------------------------------
# Test 1: 4 rejects in 48h → count=4, no streak alarm
# ---------------------------------------------------------------------------
_section "Test 1: 4 rejects → count=4, no alarm"
rm -f "$TMP/.claude/overseer/notifications/sent.jsonl"
rm -f "$STREAK_FILE"

python3 - "$BOT_PY" "$TMP" <<PYEOF
import sys, os, pathlib, time, json
tmp_root = pathlib.Path(sys.argv[2])
os.environ["REPO_ROOT"] = str(tmp_root)
os.environ["TELEGRAM_BOT_TOKEN"] = "mock-token"
os.environ["TELEGRAM_ALLOWED_USER_IDS"] = "12345"
os.environ["MOCK_INTAKE_COUNCIL_CMD"] = "echo pass"
os.environ["MOCK_INTAKE_VALIDATOR_CMD"] = "echo pass"

src = pathlib.Path(sys.argv[1]).read_text(encoding='utf-8')
globs = {"__name__": "not_main", "__file__": sys.argv[1]}
exec(compile(src, sys.argv[1], 'exec'), globs)

uid = "12345"
# Simulate 4 rejects
for _ in range(4):
    count = globs["_update_reject_streak"](uid)

streak_file = tmp_root / ".claude" / "intake-council" / "state" / "reject-streak.json"
state = json.loads(streak_file.read_text())
count_48h = state[uid]["count_48h"]
print(f"count_48h={count_48h}")
assert count_48h == 4, f"Expected 4, got {count_48h}"
PYEOF
if [ $? -eq 0 ]; then
  _pass "4 rejects → count_48h=4"
else
  _fail "4 rejects → count check failed"
fi

# No alarm should have fired (below threshold 5)
if [ ! -f "$NOTIFY_SENT" ] || ! grep -q "intake-streak" "$NOTIFY_SENT" 2>/dev/null; then
  _pass "No streak alarm at count=4"
else
  _fail "Streak alarm fired unexpectedly at count=4"
fi

# ---------------------------------------------------------------------------
# Test 2: 5th reject → count=5, streak alarm sent
# ---------------------------------------------------------------------------
_section "Test 2: 5th reject → count=5, critical alarm"
rm -f "$NOTIFY_SENT"
# Keep existing streak state (count=4 from test 1)

python3 - "$BOT_PY" "$TMP" <<PYEOF
import sys, os, pathlib, time, json, subprocess
tmp_root = pathlib.Path(sys.argv[2])
os.environ["REPO_ROOT"] = str(tmp_root)
os.environ["TELEGRAM_BOT_TOKEN"] = "mock-token"
os.environ["TELEGRAM_ALLOWED_USER_IDS"] = "12345"
os.environ["MOCK_INTAKE_COUNCIL_CMD"] = "echo pass"
os.environ["MOCK_INTAKE_VALIDATOR_CMD"] = "echo pass"

src = pathlib.Path(sys.argv[1]).read_text(encoding='utf-8')
globs = {"__name__": "not_main", "__file__": sys.argv[1]}
exec(compile(src, sys.argv[1], 'exec'), globs)

uid = "12345"
# 5th reject
streak = globs["_update_reject_streak"](uid)
print(f"streak={streak}")

# Manually trigger the alarm logic (same as _handle_reject does)
if streak >= globs["INTAKE_REJECT_STREAK_THRESHOLD"]:
    if globs["_streak_debounce_check"](uid):
        notify_sh = tmp_root / ".claude" / "scripts" / "notify.sh"
        env = {**os.environ, "REPO_ROOT": str(tmp_root)}
        subprocess.run(
            [str(notify_sh), "critical", "intake-streak",
             "Reject-Streak", f"{streak} rejects in 48h — Brainstorm-Modus oder Council off?"],
            env=env, capture_output=True,
        )
        globs["_record_streak_alarm"](uid)

print("done")
PYEOF
if [ $? -eq 0 ]; then
  _pass "5th reject executed without error"
else
  _fail "5th reject raised exception"
fi

if [ -f "$NOTIFY_SENT" ] && grep -q '"topic":"intake-streak"' "$NOTIFY_SENT"; then
  _pass "Critical streak alarm sent on 5th reject"
else
  _fail "Critical streak alarm NOT sent on 5th reject"
fi

# ---------------------------------------------------------------------------
# Test 3: 'go' resets counter to 0
# ---------------------------------------------------------------------------
_section "Test 3: go resets counter"

python3 - "$BOT_PY" "$TMP" <<PYEOF
import sys, os, pathlib, json
tmp_root = pathlib.Path(sys.argv[2])
os.environ["REPO_ROOT"] = str(tmp_root)
os.environ["TELEGRAM_BOT_TOKEN"] = "mock-token"
os.environ["TELEGRAM_ALLOWED_USER_IDS"] = "12345"
os.environ["MOCK_INTAKE_COUNCIL_CMD"] = "echo pass"
os.environ["MOCK_INTAKE_VALIDATOR_CMD"] = "echo pass"

src = pathlib.Path(sys.argv[1]).read_text(encoding='utf-8')
globs = {"__name__": "not_main", "__file__": sys.argv[1]}
exec(compile(src, sys.argv[1], 'exec'), globs)

uid = "12345"
globs["_reset_reject_streak"](uid)
streak_file = tmp_root / ".claude" / "intake-council" / "state" / "reject-streak.json"
state = json.loads(streak_file.read_text())
count_48h = state[uid]["count_48h"]
assert count_48h == 0, f"Expected 0 after reset, got {count_48h}"
print(f"count_48h after reset={count_48h}")
PYEOF
if [ $? -eq 0 ]; then
  _pass "go reset count_48h to 0"
else
  _fail "go reset failed"
fi

# ---------------------------------------------------------------------------
# Test 4: Old rejects outside 48h window are pruned from count
# ---------------------------------------------------------------------------
_section "Test 4: entries older than 48h fall out of window"

python3 - "$BOT_PY" "$TMP" <<PYEOF
import sys, os, pathlib, json, time
tmp_root = pathlib.Path(sys.argv[2])
os.environ["REPO_ROOT"] = str(tmp_root)
os.environ["TELEGRAM_BOT_TOKEN"] = "mock-token"
os.environ["TELEGRAM_ALLOWED_USER_IDS"] = "12345"
os.environ["MOCK_INTAKE_COUNCIL_CMD"] = "echo pass"
os.environ["MOCK_INTAKE_VALIDATOR_CMD"] = "echo pass"

src = pathlib.Path(sys.argv[1]).read_text(encoding='utf-8')
globs = {"__name__": "not_main", "__file__": sys.argv[1]}
exec(compile(src, sys.argv[1], 'exec'), globs)

uid = "99999"
streak_file = tmp_root / ".claude" / "intake-council" / "state" / "reject-streak.json"

# Pre-populate state with 3 old entries (>48h) + 1 recent
old_ts = time.time() - (49 * 3600)
recent_ts = time.time() - 100
state = json.loads(streak_file.read_text()) if streak_file.exists() else {}
state[uid] = {
    "count_48h": 4,
    "first_in_window_ts": None,
    "history": [old_ts, old_ts, old_ts, recent_ts],
}
streak_file.write_text(json.dumps(state))

# Now add one more reject — the 3 old entries should be pruned
count = globs["_update_reject_streak"](uid)
print(f"count after pruning+new={count}")
# Should be 2: 1 recent (kept) + 1 new = 2
assert count == 2, f"Expected 2 (1 kept + 1 new), got {count}"
PYEOF
if [ $? -eq 0 ]; then
  _pass "Entries older than 48h pruned from sliding window"
else
  _fail "48h window pruning failed"
fi

# ---------------------------------------------------------------------------
# Test 5: Debounce — 2nd streak alarm in 24h is suppressed
# ---------------------------------------------------------------------------
_section "Test 5: debounce — 2nd alarm in 24h suppressed"
rm -f "$NOTIFY_SENT"

python3 - "$BOT_PY" "$TMP" <<PYEOF
import sys, os, pathlib, json, time, subprocess
tmp_root = pathlib.Path(sys.argv[2])
os.environ["REPO_ROOT"] = str(tmp_root)
os.environ["TELEGRAM_BOT_TOKEN"] = "mock-token"
os.environ["TELEGRAM_ALLOWED_USER_IDS"] = "12345"
os.environ["MOCK_INTAKE_COUNCIL_CMD"] = "echo pass"
os.environ["MOCK_INTAKE_VALIDATOR_CMD"] = "echo pass"

src = pathlib.Path(sys.argv[1]).read_text(encoding='utf-8')
globs = {"__name__": "not_main", "__file__": sys.argv[1]}
exec(compile(src, sys.argv[1], 'exec'), globs)

uid = "55555"
notify_sh = tmp_root / ".claude" / "scripts" / "notify.sh"
env = {**os.environ, "REPO_ROOT": str(tmp_root)}

def fire_alarm():
    if globs["_streak_debounce_check"](uid):
        subprocess.run(
            [str(notify_sh), "critical", "intake-streak", "Reject-Streak", "test"],
            env=env, capture_output=True,
        )
        globs["_record_streak_alarm"](uid)
        return True
    return False

# First alarm — should fire
fired1 = fire_alarm()
# Second alarm immediately — should be suppressed
fired2 = fire_alarm()

print(f"fired1={fired1} fired2={fired2}")
assert fired1 is True, "First alarm should have fired"
assert fired2 is False, "Second alarm should be debounced"
PYEOF
if [ $? -eq 0 ]; then
  _pass "Debounce: 2nd alarm in 24h suppressed"
else
  _fail "Debounce check failed"
fi

# Exactly 1 notify entry
notify_count=$(grep -c '"topic":"intake-streak"' "$NOTIFY_SENT" 2>/dev/null || echo 0)
if [ "$notify_count" -eq 1 ]; then
  _pass "Only 1 notification sent (debounce working)"
else
  _fail "Expected 1 notification, got $notify_count"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
