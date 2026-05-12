#!/usr/bin/env bash
# verify/telegram-bridge.sh — Acceptance tests for telegram-bot.py (P2-2b)
# Uses MOCK_TELEGRAM_API_DIR to avoid real HTTP.
# Exit 0 = all pass, Exit 1 = one or more failures.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
BOT_PY="$REAL_REPO_ROOT/.claude/scripts/telegram-bot.py"

# ---------------------------------------------------------------------------
# Sandbox setup
# ---------------------------------------------------------------------------
TMP_ROOT="$(mktemp -d)"
MOCK_DIR="$(mktemp -d)"

cleanup() {
  # Remove immutable audit files before cleanup
  if command -v chflags >/dev/null 2>&1; then
    chflags -R nouchg "$TMP_ROOT" 2>/dev/null || true
  fi
  chmod -R u+w "$TMP_ROOT" 2>/dev/null || true
  rm -rf "$TMP_ROOT" "$MOCK_DIR"
}
trap cleanup EXIT

# Create sandbox dirs
mkdir -p "$TMP_ROOT/.claude/stakeholder/inbox"
mkdir -p "$TMP_ROOT/.claude/stakeholder/digest"
mkdir -p "$TMP_ROOT/.claude/overseer/state"
mkdir -p "$TMP_ROOT/.claude/overseer/notifications"
mkdir -p "$TMP_ROOT/.claude/audit"
mkdir -p "$TMP_ROOT/.claude/scripts/lib"

# Copy real btw.sh + audit.sh into sandbox
cp "$REAL_REPO_ROOT/.claude/scripts/btw.sh" "$TMP_ROOT/.claude/scripts/btw.sh"
cp "$REAL_REPO_ROOT/.claude/scripts/lib/audit.sh" "$TMP_ROOT/.claude/scripts/lib/audit.sh"

# Stub notify.sh
cat > "$TMP_ROOT/.claude/scripts/notify.sh" <<'STUB'
#!/usr/bin/env bash
mkdir -p "${REPO_ROOT:-/tmp}/.claude/overseer/notifications"
printf '{"severity":"%s","topic":"%s","title":"%s","body":"%s"}\n' \
  "${1:-}" "${2:-}" "${3:-}" "${4:-}" \
  >> "${REPO_ROOT:-/tmp}/.claude/overseer/notifications/sent.jsonl"
STUB
chmod +x "$TMP_ROOT/.claude/scripts/notify.sh"

# Common env for bot invocations
run_bot_once() {
  local updates_json="$1"
  # Write mock updates
  printf '%s' "$updates_json" > "$MOCK_DIR/updates.json"
  # Clear sent messages log
  rm -f "$MOCK_DIR/sent.jsonl"
  REPO_ROOT="$TMP_ROOT" \
  CLAUDE_PROJECT_DIR="$TMP_ROOT" \
  MOCK_TELEGRAM_API_DIR="$MOCK_DIR" \
  TELEGRAM_BOT_TOKEN="mock-token" \
  TELEGRAM_ALLOWED_USER_IDS="${ALLOWED_IDS:-12345}" \
    python3 "$BOT_PY" --once 2>/dev/null
}

# ---------------------------------------------------------------------------
PASS=0
FAIL=0

_pass() { printf '  PASS: %s\n' "$1"; PASS=$((PASS+1)); }
_fail() { printf '  FAIL: %s\n' "$1"; FAIL=$((FAIL+1)); }

printf '\n=== telegram-bridge.sh verification ===\n\n'

# ---------------------------------------------------------------------------
# Test 1: Allowed user → item created with source: tier-2
# ---------------------------------------------------------------------------
printf 'Test 1: allowed user /btw → item in inbox with source: tier-2\n'
ALLOWED_IDS="12345"
# Clear inbox
rm -f "$TMP_ROOT/.claude/stakeholder/inbox/"*.md

run_bot_once '[{"update_id": 1, "message": {"message_id": 1, "from": {"id": 12345, "first_name": "Test"}, "chat": {"id": 99}, "text": "/btw test telegram item"}}]'

FOUND_FILE="$(ls "$TMP_ROOT/.claude/stakeholder/inbox/" 2>/dev/null | grep -E 'test-telegram-item' | head -1)"
if [ -n "$FOUND_FILE" ]; then
  _pass "inbox file created: $FOUND_FILE"
  # Check source: tier-2
  FILE="$TMP_ROOT/.claude/stakeholder/inbox/$FOUND_FILE"
  if grep -q 'source: tier-2' "$FILE" && grep -q 'trust_tier: 2' "$FILE"; then
    _pass "frontmatter source:tier-2 trust_tier:2"
  else
    _fail "frontmatter missing tier-2 data. Content: $(head -5 "$FILE")"
  fi
else
  _fail "no inbox file created for allowed user"
  _fail "frontmatter check skipped"
fi

# Check reply "queued:"
if [ -f "$MOCK_DIR/sent.jsonl" ] && grep -q '"text": "queued:' "$MOCK_DIR/sent.jsonl" 2>/dev/null; then
  _pass "reply contains 'queued:'"
else
  # Check without strict JSON formatting
  if [ -f "$MOCK_DIR/sent.jsonl" ] && python3 -c "
import json, sys
lines = open('$MOCK_DIR/sent.jsonl').readlines()
ok = any('queued:' in json.loads(l).get('text','') for l in lines if l.strip())
sys.exit(0 if ok else 1)
" 2>/dev/null; then
    _pass "reply contains 'queued:'"
  else
    _fail "no 'queued:' reply sent"
  fi
fi

# ---------------------------------------------------------------------------
# Test 2: Disallowed user → no file, audit entry
# ---------------------------------------------------------------------------
printf '\nTest 2: disallowed user → no item, audit entry\n'
ALLOWED_IDS="12345"
INBOX_BEFORE="$(ls "$TMP_ROOT/.claude/stakeholder/inbox/" 2>/dev/null | wc -l | tr -d ' ')"

run_bot_once '[{"update_id": 2, "message": {"message_id": 2, "from": {"id": 99999, "first_name": "Hacker"}, "chat": {"id": 77}, "text": "/btw hacker input"}}]'

INBOX_AFTER="$(ls "$TMP_ROOT/.claude/stakeholder/inbox/" 2>/dev/null | wc -l | tr -d ' ')"
if [ "$INBOX_BEFORE" -eq "$INBOX_AFTER" ]; then
  _pass "no new file created for disallowed user"
else
  _fail "inbox file created for disallowed user (before=$INBOX_BEFORE after=$INBOX_AFTER)"
fi

# Check audit
TODAY="$(date -u +%Y-%m-%d)"
AUDIT_FILE="$TMP_ROOT/.claude/audit/${TODAY}.md"
if [ -f "$AUDIT_FILE" ] && (chflags -R nouchg "$AUDIT_FILE" 2>/dev/null; chmod u+r "$AUDIT_FILE" 2>/dev/null; grep -q 'tier2_disallowed' "$AUDIT_FILE" 2>/dev/null); then
  _pass "audit entry tier2_disallowed found"
else
  _fail "no audit entry for tier2_disallowed"
fi

# ---------------------------------------------------------------------------
# Test 3: Rate-limit (6th item blocked)
# ---------------------------------------------------------------------------
printf '\nTest 3: rate-limit — 6th item blocked\n'
ALLOWED_IDS="12345"
# Clear rate-limit state
rm -f "$TMP_ROOT/.claude/overseer/state/telegram-ratelimit.json"
# Clear inbox
rm -f "$TMP_ROOT/.claude/stakeholder/inbox/"*.md

# Send 6 updates (update_id 10-15, all from user 12345)
for I in $(seq 10 15); do
  run_bot_once "[{\"update_id\": $I, \"message\": {\"message_id\": $I, \"from\": {\"id\": 12345, \"first_name\": \"Test\"}, \"chat\": {\"id\": 99}, \"text\": \"/btw rate test item $I\"}}]"
done

INBOX_COUNT="$(ls "$TMP_ROOT/.claude/stakeholder/inbox/" 2>/dev/null | wc -l | tr -d ' ')"
if [ "$INBOX_COUNT" -eq 5 ]; then
  _pass "exactly 5 items created (6th blocked)"
else
  _fail "expected 5 items, got $INBOX_COUNT"
fi

# Check for rate-limited reply
if [ -f "$MOCK_DIR/sent.jsonl" ]; then
  RATE_REPLY="$(python3 -c "
import json, sys
lines = open('$MOCK_DIR/sent.jsonl').readlines()
hits = [l for l in lines if 'rate-limited' in json.loads(l).get('text','')]
print(len(hits))
" 2>/dev/null || echo 0)"
  if [ "$RATE_REPLY" -ge 1 ]; then
    _pass "rate-limited reply sent for 6th item"
  else
    _fail "no rate-limited reply found"
  fi
else
  _fail "sent.jsonl not found"
fi

# ---------------------------------------------------------------------------
# Test 4: Non-/btw command → "Only /btw <text> supported"
# ---------------------------------------------------------------------------
printf '\nTest 4: /start → reply "Only /btw <text> supported"\n'
ALLOWED_IDS="12345"
rm -f "$MOCK_DIR/sent.jsonl"
INBOX_BEFORE="$(ls "$TMP_ROOT/.claude/stakeholder/inbox/" 2>/dev/null | wc -l | tr -d ' ')"

run_bot_once '[{"update_id": 20, "message": {"message_id": 20, "from": {"id": 12345, "first_name": "Test"}, "chat": {"id": 99}, "text": "/start"}}]'

INBOX_AFTER="$(ls "$TMP_ROOT/.claude/stakeholder/inbox/" 2>/dev/null | wc -l | tr -d ' ')"
if [ "$INBOX_BEFORE" -eq "$INBOX_AFTER" ]; then
  _pass "no new file for non-/btw command"
else
  _fail "inbox file created for /start command"
fi

if [ -f "$MOCK_DIR/sent.jsonl" ] && python3 -c "
import json, sys
lines = open('$MOCK_DIR/sent.jsonl').readlines()
ok = any('Only /btw' in json.loads(l).get('text','') for l in lines if l.strip())
sys.exit(0 if ok else 1)
" 2>/dev/null; then
  _pass "reply 'Only /btw <text> supported' sent"
else
  _fail "no 'Only /btw <text> supported' reply"
fi

# ---------------------------------------------------------------------------
# Test 5: Empty /btw → "Usage:" reply, no item
# ---------------------------------------------------------------------------
printf '\nTest 5: empty /btw → usage reply, no item\n'
ALLOWED_IDS="12345"
rm -f "$MOCK_DIR/sent.jsonl"
# Reset rate-limit to avoid pollution from test 3
rm -f "$TMP_ROOT/.claude/overseer/state/telegram-ratelimit.json"
INBOX_BEFORE="$(ls "$TMP_ROOT/.claude/stakeholder/inbox/" 2>/dev/null | wc -l | tr -d ' ')"

run_bot_once '[{"update_id": 30, "message": {"message_id": 30, "from": {"id": 12345, "first_name": "Test"}, "chat": {"id": 99}, "text": "/btw"}}]'

INBOX_AFTER="$(ls "$TMP_ROOT/.claude/stakeholder/inbox/" 2>/dev/null | wc -l | tr -d ' ')"
if [ "$INBOX_BEFORE" -eq "$INBOX_AFTER" ]; then
  _pass "no new file for empty /btw"
else
  _fail "inbox file created for empty /btw"
fi

if [ -f "$MOCK_DIR/sent.jsonl" ] && python3 -c "
import json, sys
lines = open('$MOCK_DIR/sent.jsonl').readlines()
ok = any('sage' in json.loads(l).get('text','').lower() for l in lines if l.strip())
sys.exit(0 if ok else 1)
" 2>/dev/null; then
  _pass "usage reply sent for empty /btw"
else
  _fail "no usage reply for empty /btw"
fi

# ---------------------------------------------------------------------------
# Test 6: HMAC token — initial bootstrap (no briefing file → no token required)
# ---------------------------------------------------------------------------
printf '\nTest 6: HMAC initial (no briefing) → token-check skipped\n'
ALLOWED_IDS="12345"
rm -f "$TMP_ROOT/.claude/stakeholder/digest/"*.md
rm -f "$TMP_ROOT/.claude/overseer/state/telegram-ratelimit.json"
rm -f "$TMP_ROOT/.claude/stakeholder/inbox/"*.md

# Create an HMAC secret file
HMAC_SECRET_FILE_PATH="$TMP_ROOT/.claude/telegram-hmac-secret"
printf 'supersecret123' > "$HMAC_SECRET_FILE_PATH"

REPO_ROOT="$TMP_ROOT" \
CLAUDE_PROJECT_DIR="$TMP_ROOT" \
MOCK_TELEGRAM_API_DIR="$MOCK_DIR" \
TELEGRAM_BOT_TOKEN="mock-token" \
TELEGRAM_ALLOWED_USER_IDS="12345" \
TELEGRAM_HMAC_SECRET_FILE="$HMAC_SECRET_FILE_PATH" \
  python3 "$BOT_PY" --once \
  <<< '' 2>/dev/null

# Write a mock update for this test (no token since no briefing)
printf '[{"update_id": 40, "message": {"message_id": 40, "from": {"id": 12345, "first_name": "Test"}, "chat": {"id": 99}, "text": "/btw notoken item"}}]' > "$MOCK_DIR/updates.json"
rm -f "$MOCK_DIR/sent.jsonl"

REPO_ROOT="$TMP_ROOT" \
CLAUDE_PROJECT_DIR="$TMP_ROOT" \
MOCK_TELEGRAM_API_DIR="$MOCK_DIR" \
TELEGRAM_BOT_TOKEN="mock-token" \
TELEGRAM_ALLOWED_USER_IDS="12345" \
TELEGRAM_HMAC_SECRET_FILE="$HMAC_SECRET_FILE_PATH" \
  python3 "$BOT_PY" --once 2>/dev/null

FOUND_FILE="$(ls "$TMP_ROOT/.claude/stakeholder/inbox/" 2>/dev/null | grep -E 'notoken' | head -1)"
if [ -n "$FOUND_FILE" ]; then
  _pass "item created without token when no briefing exists"
else
  _fail "item NOT created — token-check should be skipped when no briefing exists"
fi

# ---------------------------------------------------------------------------
# Test 7: HMAC token (briefing active) — invalid token rejected, valid accepted
# ---------------------------------------------------------------------------
printf '\nTest 7: HMAC with active briefing — invalid rejected, valid accepted\n'
ALLOWED_IDS="12345"
HMAC_SECRET_FILE_PATH="$TMP_ROOT/.claude/telegram-hmac-secret"
printf 'supersecret123' > "$HMAC_SECRET_FILE_PATH"

# Create a mock briefing file
BRIEFING_ID="20260509-120000-weekly-digest"
touch "$TMP_ROOT/.claude/stakeholder/digest/${BRIEFING_ID}.md"
rm -f "$TMP_ROOT/.claude/overseer/state/telegram-ratelimit.json"
rm -f "$TMP_ROOT/.claude/stakeholder/inbox/"*.md

# Compute the expected token
EXPECTED_TOKEN="$(python3 -c "
import hmac, hashlib
secret = b'supersecret123'
briefing_id = '${BRIEFING_ID}'
token = hmac.new(secret, briefing_id.encode(), hashlib.sha256).hexdigest()
print(token)
")"

# 7a: invalid token
printf '[{"update_id": 50, "message": {"message_id": 50, "from": {"id": 12345, "first_name": "Test"}, "chat": {"id": 99}, "text": "/btw BADTOKEN text-after-bad-token"}}]' > "$MOCK_DIR/updates.json"
rm -f "$MOCK_DIR/sent.jsonl"

REPO_ROOT="$TMP_ROOT" \
CLAUDE_PROJECT_DIR="$TMP_ROOT" \
MOCK_TELEGRAM_API_DIR="$MOCK_DIR" \
TELEGRAM_BOT_TOKEN="mock-token" \
TELEGRAM_ALLOWED_USER_IDS="12345" \
TELEGRAM_HMAC_SECRET_FILE="$HMAC_SECRET_FILE_PATH" \
  python3 "$BOT_PY" --once 2>/dev/null

INBOX_COUNT_AFTER_INVALID="$(ls "$TMP_ROOT/.claude/stakeholder/inbox/" 2>/dev/null | wc -l | tr -d ' ')"
if [ "$INBOX_COUNT_AFTER_INVALID" -eq 0 ]; then
  _pass "invalid token rejected (no item created)"
else
  _fail "item created despite invalid HMAC token"
fi

# 7b: valid token
printf "[{\"update_id\": 51, \"message\": {\"message_id\": 51, \"from\": {\"id\": 12345, \"first_name\": \"Test\"}, \"chat\": {\"id\": 99}, \"text\": \"/btw ${EXPECTED_TOKEN} valid hmac item\"}}]" > "$MOCK_DIR/updates.json"
rm -f "$MOCK_DIR/sent.jsonl"
rm -f "$TMP_ROOT/.claude/overseer/state/telegram-ratelimit.json"

REPO_ROOT="$TMP_ROOT" \
CLAUDE_PROJECT_DIR="$TMP_ROOT" \
MOCK_TELEGRAM_API_DIR="$MOCK_DIR" \
TELEGRAM_BOT_TOKEN="mock-token" \
TELEGRAM_ALLOWED_USER_IDS="12345" \
TELEGRAM_HMAC_SECRET_FILE="$HMAC_SECRET_FILE_PATH" \
  python3 "$BOT_PY" --once 2>/dev/null

FOUND_VALID="$(ls "$TMP_ROOT/.claude/stakeholder/inbox/" 2>/dev/null | grep -E 'valid-hmac' | head -1)"
if [ -n "$FOUND_VALID" ]; then
  _pass "valid HMAC token accepted, item created: $FOUND_VALID"
else
  _fail "item NOT created for valid HMAC token (files: $(ls "$TMP_ROOT/.claude/stakeholder/inbox/" 2>/dev/null | head -5))"
fi

# ---------------------------------------------------------------------------
# Test 8: /yota (no arg) → snapshot via mock yota-snapshot.sh
# ---------------------------------------------------------------------------
printf '\nTest 8: /yota (no arg) → snapshot reply with "Status:"\n'
ALLOWED_IDS="12345"
rm -f "$MOCK_DIR/sent.jsonl"
# Clear briefings → no HMAC required (irrelevant for /yota anyway)
rm -f "$TMP_ROOT/.claude/stakeholder/digest/"*.md
rm -f "$TMP_ROOT/.claude/overseer/state/telegram-yota-ratelimit.json"
rm -f "$TMP_ROOT/.claude/overseer/state/telegram-yota-inflight.json"

# Mock snapshot output
MOCK_SNAPSHOT_CMD='printf "**Status:** active — 1/2 worker.\n**Alerts:** keine.\n"'

printf '[{"update_id": 60, "message": {"message_id": 60, "from": {"id": 12345, "first_name": "Test"}, "chat": {"id": 99}, "text": "/yota"}}]' > "$MOCK_DIR/updates.json"

REPO_ROOT="$TMP_ROOT" \
CLAUDE_PROJECT_DIR="$TMP_ROOT" \
MOCK_TELEGRAM_API_DIR="$MOCK_DIR" \
TELEGRAM_BOT_TOKEN="mock-token" \
TELEGRAM_ALLOWED_USER_IDS="12345" \
MOCK_YOTA_SNAPSHOT_CMD="$MOCK_SNAPSHOT_CMD" \
  python3 "$BOT_PY" --once 2>/dev/null

if [ -f "$MOCK_DIR/sent.jsonl" ] && python3 -c "
import json
lines = open('$MOCK_DIR/sent.jsonl').readlines()
ok = any('Status:' in json.loads(l).get('text','') for l in lines if l.strip())
import sys; sys.exit(0 if ok else 1)
" 2>/dev/null; then
  _pass "/yota returned snapshot containing 'Status:'"
else
  _fail "/yota did not return snapshot (sent: $(cat "$MOCK_DIR/sent.jsonl" 2>/dev/null))"
fi

# ---------------------------------------------------------------------------
# Test 9: /yota <frage> → mock LLM call
# ---------------------------------------------------------------------------
printf '\nTest 9: /yota <frage> → mock LLM-call returns mock answer\n'
ALLOWED_IDS="12345"
rm -f "$MOCK_DIR/sent.jsonl"
rm -f "$TMP_ROOT/.claude/overseer/state/telegram-yota-ratelimit.json"
rm -f "$TMP_ROOT/.claude/overseer/state/telegram-yota-inflight.json"

MOCK_LLM_CMD='printf "MOCK-YOTA-ANSWER für: %s" "$YOTA_QUESTION"'

printf '[{"update_id": 61, "message": {"message_id": 61, "from": {"id": 12345, "first_name": "Test"}, "chat": {"id": 99}, "text": "/yota was läuft?"}}]' > "$MOCK_DIR/updates.json"

REPO_ROOT="$TMP_ROOT" \
CLAUDE_PROJECT_DIR="$TMP_ROOT" \
MOCK_TELEGRAM_API_DIR="$MOCK_DIR" \
TELEGRAM_BOT_TOKEN="mock-token" \
TELEGRAM_ALLOWED_USER_IDS="12345" \
MOCK_YOTA_LLM_CMD="$MOCK_LLM_CMD" \
  python3 "$BOT_PY" --once 2>/dev/null

if [ -f "$MOCK_DIR/sent.jsonl" ] && python3 -c "
import json
lines = open('$MOCK_DIR/sent.jsonl').readlines()
ok = any('MOCK-YOTA-ANSWER' in json.loads(l).get('text','') for l in lines if l.strip())
import sys; sys.exit(0 if ok else 1)
" 2>/dev/null; then
  _pass "/yota <frage> returned LLM-answer"
else
  _fail "/yota <frage> did not return mock LLM answer"
fi

# ---------------------------------------------------------------------------
# Test 10: md_to_html() converter unit-test
# ---------------------------------------------------------------------------
printf '\nTest 10: md_to_html() unit-test\n'
if python3 -c "
import sys
sys.path.insert(0, '$REAL_REPO_ROOT/.claude/scripts')
import importlib.util
spec = importlib.util.spec_from_file_location('tb', '$BOT_PY')
tb = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tb)
got = tb.md_to_html('**Status:** *active*')
assert got == '<b>Status:</b> <i>active</i>', f'got: {got!r}'
got2 = tb.md_to_html('hello <there> & \`code\`')
assert '&lt;there&gt;' in got2 and '<code>code</code>' in got2, f'got2: {got2!r}'
" 2>&1; then
  _pass "md_to_html basic conversions"
else
  _fail "md_to_html unit-test failed"
fi

# ---------------------------------------------------------------------------
# Test 11: /yota rate-limit — 11th LLM-call blocked
# ---------------------------------------------------------------------------
printf '\nTest 11: /yota rate-limit — 11th blocked\n'
ALLOWED_IDS="12345"
rm -f "$MOCK_DIR/sent.jsonl"
rm -f "$TMP_ROOT/.claude/overseer/state/telegram-yota-ratelimit.json"
rm -f "$TMP_ROOT/.claude/overseer/state/telegram-yota-inflight.json"

MOCK_LLM_CMD='printf "ok %s" "$YOTA_QUESTION"'
RL_HITS=0
for I in $(seq 100 110); do
  printf "[{\"update_id\": $I, \"message\": {\"message_id\": $I, \"from\": {\"id\": 12345, \"first_name\": \"Test\"}, \"chat\": {\"id\": 99}, \"text\": \"/yota frage $I\"}}]" > "$MOCK_DIR/updates.json"
  REPO_ROOT="$TMP_ROOT" \
  CLAUDE_PROJECT_DIR="$TMP_ROOT" \
  MOCK_TELEGRAM_API_DIR="$MOCK_DIR" \
  TELEGRAM_BOT_TOKEN="mock-token" \
  TELEGRAM_ALLOWED_USER_IDS="12345" \
  MOCK_YOTA_LLM_CMD="$MOCK_LLM_CMD" \
    python3 "$BOT_PY" --once 2>/dev/null
done

RL_HITS="$(python3 -c "
import json
lines = open('$MOCK_DIR/sent.jsonl').readlines()
print(sum(1 for l in lines if 'rate-limited' in json.loads(l).get('text','')))
" 2>/dev/null || echo 0)"
if [ "$RL_HITS" -ge 1 ]; then
  _pass "/yota 11th call rate-limited (hits=$RL_HITS)"
else
  _fail "/yota 11th call NOT rate-limited (hits=$RL_HITS)"
fi

# ---------------------------------------------------------------------------
# Test 12: /yota concurrency-block — second call while first in-flight
# ---------------------------------------------------------------------------
printf '\nTest 12: /yota concurrency-block (in-flight lock)\n'
ALLOWED_IDS="12345"
rm -f "$MOCK_DIR/sent.jsonl"
rm -f "$TMP_ROOT/.claude/overseer/state/telegram-yota-ratelimit.json"

# Pre-seed inflight lock to simulate ongoing call
mkdir -p "$TMP_ROOT/.claude/overseer/state"
python3 -c "
import json, time, pathlib
f = pathlib.Path('$TMP_ROOT/.claude/overseer/state/telegram-yota-inflight.json')
f.write_text(json.dumps({'12345': {'started': time.time()}}))
"

MOCK_LLM_CMD='printf "should-not-run"'
printf '[{"update_id": 70, "message": {"message_id": 70, "from": {"id": 12345, "first_name": "Test"}, "chat": {"id": 99}, "text": "/yota zweite frage"}}]' > "$MOCK_DIR/updates.json"

REPO_ROOT="$TMP_ROOT" \
CLAUDE_PROJECT_DIR="$TMP_ROOT" \
MOCK_TELEGRAM_API_DIR="$MOCK_DIR" \
TELEGRAM_BOT_TOKEN="mock-token" \
TELEGRAM_ALLOWED_USER_IDS="12345" \
MOCK_YOTA_LLM_CMD="$MOCK_LLM_CMD" \
  python3 "$BOT_PY" --once 2>/dev/null

if [ -f "$MOCK_DIR/sent.jsonl" ] && python3 -c "
import json
lines = open('$MOCK_DIR/sent.jsonl').readlines()
ok = any('Moment' in json.loads(l).get('text','') for l in lines if l.strip())
import sys; sys.exit(0 if ok else 1)
" 2>/dev/null; then
  _pass "concurrency-block reply sent"
else
  _fail "no concurrency-block reply"
fi
rm -f "$TMP_ROOT/.claude/overseer/state/telegram-yota-inflight.json"

# ---------------------------------------------------------------------------
# Test 13: /help → command list
# ---------------------------------------------------------------------------
printf '\nTest 13: /help → command list\n'
rm -f "$MOCK_DIR/sent.jsonl"
printf '[{"update_id": 80, "message": {"message_id": 80, "from": {"id": 12345, "first_name": "Test"}, "chat": {"id": 99}, "text": "/help"}}]' > "$MOCK_DIR/updates.json"

REPO_ROOT="$TMP_ROOT" \
CLAUDE_PROJECT_DIR="$TMP_ROOT" \
MOCK_TELEGRAM_API_DIR="$MOCK_DIR" \
TELEGRAM_BOT_TOKEN="mock-token" \
TELEGRAM_ALLOWED_USER_IDS="12345" \
  python3 "$BOT_PY" --once 2>/dev/null

if python3 -c "
import json
lines = open('$MOCK_DIR/sent.jsonl').readlines()
ok = any('/yota' in json.loads(l).get('text','') and '/btw' in json.loads(l).get('text','') for l in lines if l.strip())
import sys; sys.exit(0 if ok else 1)
" 2>/dev/null; then
  _pass "/help lists /yota + /btw"
else
  _fail "/help did not list commands"
fi

# ---------------------------------------------------------------------------
# Test 14: /status alias → same as /yota
# ---------------------------------------------------------------------------
printf '\nTest 14: /status alias\n'
rm -f "$MOCK_DIR/sent.jsonl"
rm -f "$TMP_ROOT/.claude/overseer/state/telegram-yota-ratelimit.json"
rm -f "$TMP_ROOT/.claude/overseer/state/telegram-yota-inflight.json"
MOCK_SNAPSHOT_CMD='printf "**Status:** idle\n"'
printf '[{"update_id": 81, "message": {"message_id": 81, "from": {"id": 12345, "first_name": "Test"}, "chat": {"id": 99}, "text": "/status"}}]' > "$MOCK_DIR/updates.json"

REPO_ROOT="$TMP_ROOT" \
CLAUDE_PROJECT_DIR="$TMP_ROOT" \
MOCK_TELEGRAM_API_DIR="$MOCK_DIR" \
TELEGRAM_BOT_TOKEN="mock-token" \
TELEGRAM_ALLOWED_USER_IDS="12345" \
MOCK_YOTA_SNAPSHOT_CMD="$MOCK_SNAPSHOT_CMD" \
  python3 "$BOT_PY" --once 2>/dev/null

if python3 -c "
import json
lines = open('$MOCK_DIR/sent.jsonl').readlines()
ok = any('Status:' in json.loads(l).get('text','') for l in lines if l.strip())
import sys; sys.exit(0 if ok else 1)
" 2>/dev/null; then
  _pass "/status alias returned snapshot"
else
  _fail "/status alias did not behave like /yota"
fi

# ---------------------------------------------------------------------------
# Test 15: Long message split (>4096 chars → 2 sendMessage calls)
# ---------------------------------------------------------------------------
printf '\nTest 15: long message split\n'
rm -f "$MOCK_DIR/sent.jsonl"
rm -f "$TMP_ROOT/.claude/overseer/state/telegram-yota-ratelimit.json"
rm -f "$TMP_ROOT/.claude/overseer/state/telegram-yota-inflight.json"

# Build a 5000-char body (no newlines so split falls back to hard-cut)
MOCK_LLM_CMD='python3 -c "print(\"A\"*5000)"'
printf '[{"update_id": 90, "message": {"message_id": 90, "from": {"id": 12345, "first_name": "Test"}, "chat": {"id": 99}, "text": "/yota big"}}]' > "$MOCK_DIR/updates.json"

REPO_ROOT="$TMP_ROOT" \
CLAUDE_PROJECT_DIR="$TMP_ROOT" \
MOCK_TELEGRAM_API_DIR="$MOCK_DIR" \
TELEGRAM_BOT_TOKEN="mock-token" \
TELEGRAM_ALLOWED_USER_IDS="12345" \
MOCK_YOTA_LLM_CMD="$MOCK_LLM_CMD" \
  python3 "$BOT_PY" --once 2>/dev/null

SENT_COUNT="$(wc -l < "$MOCK_DIR/sent.jsonl" 2>/dev/null | tr -d ' ')"
if [ "${SENT_COUNT:-0}" -ge 2 ]; then
  _pass "long message split into $SENT_COUNT chunks"
else
  _fail "expected ≥2 chunks for long message, got $SENT_COUNT"
fi

# ---------------------------------------------------------------------------
# Test 16: plist validity (plutil -lint)
# ---------------------------------------------------------------------------
printf '\nTest 16: plist validity\n'
PLIST_TARGET="$TMP_ROOT/com.inventory.telegram-bot.plist"
LAUNCH_AGENTS_DIR="$TMP_ROOT" \
  bash "$REAL_REPO_ROOT/.claude/scripts/install-telegram-bot.sh" >/dev/null 2>&1 || true
# Installer requires env vars; emulate them
TELEGRAM_BOT_TOKEN="x" TELEGRAM_ALLOWED_USER_IDS="1" \
  LAUNCH_AGENTS_DIR="$TMP_ROOT" \
  bash "$REAL_REPO_ROOT/.claude/scripts/install-telegram-bot.sh" >/dev/null 2>&1

if [ -f "$PLIST_TARGET" ] && plutil -lint "$PLIST_TARGET" >/dev/null 2>&1; then
  _pass "plist plutil -lint passes"
else
  _fail "plist plutil -lint failed or plist missing"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
