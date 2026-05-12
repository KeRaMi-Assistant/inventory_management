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
# Intake-Council Tests (T09..T13)
# ---------------------------------------------------------------------------

# Setup additional intake dirs + copy yota-propose.sh + slug.sh + intake-tokens.sh
mkdir -p "$TMP_ROOT/.claude/stakeholder/pending-proposal"
mkdir -p "$TMP_ROOT/.claude/stakeholder/pending-approval"
mkdir -p "$TMP_ROOT/.claude/stakeholder/rejected"
mkdir -p "$TMP_ROOT/.claude/overseer/inbox"

cp "$REAL_REPO_ROOT/.claude/scripts/yota-propose.sh" "$TMP_ROOT/.claude/scripts/yota-propose.sh" 2>/dev/null || true
cp "$REAL_REPO_ROOT/.claude/scripts/lib/slug.sh" "$TMP_ROOT/.claude/scripts/lib/slug.sh" 2>/dev/null || true
cp "$REAL_REPO_ROOT/.claude/scripts/lib/intake-tokens.sh" "$TMP_ROOT/.claude/scripts/lib/intake-tokens.sh" 2>/dev/null || true
cp "$REAL_REPO_ROOT/.claude/scripts/lib/api-key-preflight.sh" "$TMP_ROOT/.claude/scripts/lib/api-key-preflight.sh" 2>/dev/null || true
cp "$REAL_REPO_ROOT/.claude/scripts/lib/cost-cap.sh" "$TMP_ROOT/.claude/scripts/lib/cost-cap.sh" 2>/dev/null || true

# Build a mock pending-approval file factory
_make_approval() {
  local id="$1" verdict="${2:-propose}" user="${3:-12345}" token="${4:-0123456789abcdef}"
  cat > "$TMP_ROOT/.claude/stakeholder/pending-approval/${id}.md" <<EOF
---
id: ${id}
source: tier-2
trust_tier: 2
user_id: ${user}
created_at: 2026-05-12T10:00:00Z
state: pending-approval
verdict: ${verdict}
round: 1
council_cost_usd: 0.40
hmac_token: ${token}
pushed_at: ""
requires_human_dispute: false
touches: []
created_from: intake-council
---

## Verdict-Summary

Council mag die Idee. ROI passt.

## Vorgeschlagenes Backlog-Item

slug: ${id##*-*-}
EOF
}

# --- Test I1: /yota propose spawns council ---
printf '\nTest I1: /yota propose spawns intake-council\n'
rm -f "$TMP_ROOT/.claude/stakeholder/pending-proposal/"*.md 2>/dev/null
rm -f "$MOCK_DIR/sent.jsonl"
rm -f "$TMP_ROOT/.claude/overseer/state/telegram-ratelimit.json"
# Marker file: council spawn writes here
SPAWN_MARKER="$TMP_ROOT/council-spawned.txt"
rm -f "$SPAWN_MARKER"

printf '[{"update_id": 200, "message": {"message_id": 200, "from": {"id": 12345, "first_name": "Test"}, "chat": {"id": 99}, "text": "/yota propose neue csv-export funktion"}}]' > "$MOCK_DIR/updates.json"

REPO_ROOT="$TMP_ROOT" \
CLAUDE_PROJECT_DIR="$TMP_ROOT" \
MOCK_TELEGRAM_API_DIR="$MOCK_DIR" \
TELEGRAM_BOT_TOKEN="mock-token" \
TELEGRAM_ALLOWED_USER_IDS="12345" \
MOCK_INTAKE_COUNCIL_CMD="echo \"\$INTAKE_PROPOSAL_PATH\" > $SPAWN_MARKER" \
MOCK_COST_TODAY_USD="1.23" \
  python3 "$BOT_PY" --once 2>/dev/null

# Allow detached subprocess to flush
sleep 1

PROPOSAL_COUNT="$(ls "$TMP_ROOT/.claude/stakeholder/pending-proposal/" 2>/dev/null | wc -l | tr -d ' ')"
if [ "$PROPOSAL_COUNT" -ge 1 ]; then
  _pass "pending-proposal file created"
else
  _fail "no pending-proposal file created"
fi

if [ -f "$SPAWN_MARKER" ] && grep -q 'pending-proposal' "$SPAWN_MARKER" 2>/dev/null; then
  _pass "intake-council spawn invoked"
else
  _fail "intake-council spawn NOT invoked"
fi

if python3 -c "
import json
lines = open('$MOCK_DIR/sent.jsonl').readlines()
ok = any('Proposal queued' in json.loads(l).get('text','') for l in lines)
import sys; sys.exit(0 if ok else 1)
" 2>/dev/null; then
  _pass "ACK 'Proposal queued' sent"
else
  _fail "no ACK sent"
fi

# --- Test I2: /yota pending lists files ---
printf '\nTest I2: /yota pending lists 3 approvals\n'
rm -f "$TMP_ROOT/.claude/stakeholder/pending-approval/"*.md
rm -f "$MOCK_DIR/sent.jsonl"
_make_approval "20260512-100000-csv-export" propose 12345
_make_approval "20260512-100100-dark-footer" reject 12345
_make_approval "20260512-100200-inbox-filter" propose-with-changes 12345

printf '[{"update_id": 201, "message": {"message_id": 201, "from": {"id": 12345, "first_name": "Test"}, "chat": {"id": 99}, "text": "/yota pending"}}]' > "$MOCK_DIR/updates.json"

REPO_ROOT="$TMP_ROOT" CLAUDE_PROJECT_DIR="$TMP_ROOT" MOCK_TELEGRAM_API_DIR="$MOCK_DIR" \
TELEGRAM_BOT_TOKEN="mock-token" TELEGRAM_ALLOWED_USER_IDS="12345" \
  python3 "$BOT_PY" --once 2>/dev/null

if python3 -c "
import json
lines = open('$MOCK_DIR/sent.jsonl').readlines()
text = lines[0] and json.loads(lines[0]).get('text','')
ok = 'csv-export' in text and 'dark-footer' in text and 'inbox-filter' in text
import sys; sys.exit(0 if ok else 1)
" 2>/dev/null; then
  _pass "/yota pending listed all 3 slugs"
else
  _fail "/yota pending did not list 3 slugs"
fi

# --- Test I3: go <id> <token> valid → validator runs ---
printf '\nTest I3: go <id> valid token → validator invoked\n'
rm -f "$MOCK_DIR/sent.jsonl"
rm -f "$TMP_ROOT/.claude/stakeholder/pending-approval/"*.md
_make_approval "20260512-100000-csv-export" propose 12345 0123456789abcdef
VALIDATOR_MARKER="$TMP_ROOT/validator-ran.txt"
rm -f "$VALIDATOR_MARKER"

printf '[{"update_id": 202, "message": {"message_id": 202, "from": {"id": 12345, "first_name": "Test"}, "chat": {"id": 99}, "text": "go 20260512-100000-csv-export 0123456789abcdef"}}]' > "$MOCK_DIR/updates.json"

REPO_ROOT="$TMP_ROOT" CLAUDE_PROJECT_DIR="$TMP_ROOT" MOCK_TELEGRAM_API_DIR="$MOCK_DIR" \
TELEGRAM_BOT_TOKEN="mock-token" TELEGRAM_ALLOWED_USER_IDS="12345" \
MOCK_INTAKE_VALIDATOR_CMD="echo \"\$INTAKE_APPROVAL_PATH\" > $VALIDATOR_MARKER; echo 'pass — no violations'" \
  python3 "$BOT_PY" --once 2>/dev/null

if [ -f "$VALIDATOR_MARKER" ]; then
  _pass "validator invoked"
else
  _fail "validator NOT invoked"
fi

if python3 -c "
import json
lines = open('$MOCK_DIR/sent.jsonl').readlines()
ok = any('approved' in json.loads(l).get('text','') for l in lines)
import sys; sys.exit(0 if ok else 1)
" 2>/dev/null; then
  _pass "approval ack sent"
else
  _fail "no approval ack"
fi

# Verify overseer/inbox item was written by Bash-side extraction
INBOX_FILE="$TMP_ROOT/.claude/overseer/inbox/01-stakeholder-csv-export.md"
if [ -f "$INBOX_FILE" ]; then
  _pass "overseer/inbox item written via Bash-side extraction"
  if grep -q '^slug:' "$INBOX_FILE" 2>/dev/null; then
    _pass "inbox item contains backlog-item YAML"
  else
    _fail "inbox item missing backlog-item content"
  fi
else
  _fail "overseer/inbox file NOT written: $INBOX_FILE"
fi

# --- Test I4: go from wrong user → silent ignore ---
printf '\nTest I4: go from wrong user → silent ignore\n'
rm -f "$MOCK_DIR/sent.jsonl"
rm -f "$TMP_ROOT/.claude/stakeholder/pending-approval/"*.md
_make_approval "20260512-100000-csv-export" propose 12345 0123456789abcdef
# Allow user 99999 as well (allowlist), but creator is 12345
printf '[{"update_id": 203, "message": {"message_id": 203, "from": {"id": 99999, "first_name": "Other"}, "chat": {"id": 99}, "text": "go 20260512-100000-csv-export 0123456789abcdef"}}]' > "$MOCK_DIR/updates.json"

REPO_ROOT="$TMP_ROOT" CLAUDE_PROJECT_DIR="$TMP_ROOT" MOCK_TELEGRAM_API_DIR="$MOCK_DIR" \
TELEGRAM_BOT_TOKEN="mock-token" TELEGRAM_ALLOWED_USER_IDS="12345,99999" \
  python3 "$BOT_PY" --once 2>/dev/null

SENT_COUNT="$([ -f "$MOCK_DIR/sent.jsonl" ] && wc -l < "$MOCK_DIR/sent.jsonl" | tr -d ' ' || echo 0)"
if [ "$SENT_COUNT" -eq 0 ]; then
  _pass "silent ignore (no reply) for wrong-user go"
else
  _fail "expected silent ignore, got $SENT_COUNT replies"
fi

# --- Test I5: go with wrong token → "Token ungültig" ---
printf '\nTest I5: go with wrong token → rejected\n'
rm -f "$MOCK_DIR/sent.jsonl"
printf '[{"update_id": 204, "message": {"message_id": 204, "from": {"id": 12345, "first_name": "Test"}, "chat": {"id": 99}, "text": "go 20260512-100000-csv-export ffffffffffffffff"}}]' > "$MOCK_DIR/updates.json"

REPO_ROOT="$TMP_ROOT" CLAUDE_PROJECT_DIR="$TMP_ROOT" MOCK_TELEGRAM_API_DIR="$MOCK_DIR" \
TELEGRAM_BOT_TOKEN="mock-token" TELEGRAM_ALLOWED_USER_IDS="12345" \
  python3 "$BOT_PY" --once 2>/dev/null

if python3 -c "
import json
lines = open('$MOCK_DIR/sent.jsonl').readlines()
ok = any('Token ungültig' in json.loads(l).get('text','') for l in lines)
import sys; sys.exit(0 if ok else 1)
" 2>/dev/null; then
  _pass "token mismatch reply sent"
else
  _fail "no token-mismatch reply"
fi

# --- Test I6: reject moves file to rejected/ ---
printf '\nTest I6: reject moves file → rejected/\n'
rm -f "$MOCK_DIR/sent.jsonl"
rm -f "$TMP_ROOT/.claude/stakeholder/pending-approval/"*.md
rm -f "$TMP_ROOT/.claude/stakeholder/rejected/"*.md
_make_approval "20260512-100000-csv-export" propose 12345

printf '[{"update_id": 205, "message": {"message_id": 205, "from": {"id": 12345, "first_name": "Test"}, "chat": {"id": 99}, "text": "reject 20260512-100000-csv-export no fit"}}]' > "$MOCK_DIR/updates.json"

REPO_ROOT="$TMP_ROOT" CLAUDE_PROJECT_DIR="$TMP_ROOT" MOCK_TELEGRAM_API_DIR="$MOCK_DIR" \
TELEGRAM_BOT_TOKEN="mock-token" TELEGRAM_ALLOWED_USER_IDS="12345" \
  python3 "$BOT_PY" --once 2>/dev/null

if [ -f "$TMP_ROOT/.claude/stakeholder/rejected/20260512-100000-csv-export.md" ] \
   && [ ! -f "$TMP_ROOT/.claude/stakeholder/pending-approval/20260512-100000-csv-export.md" ]; then
  _pass "file moved to rejected/"
else
  _fail "rejected/ move failed"
fi
if grep -q 'user_reason: no fit' "$TMP_ROOT/.claude/stakeholder/rejected/20260512-100000-csv-export.md" 2>/dev/null; then
  _pass "user_reason persisted"
else
  _fail "user_reason missing"
fi

# --- Test I7: change creates superseded + new pending-proposal round=2 ---
printf '\nTest I7: change → superseded + round=2 proposal\n'
rm -f "$MOCK_DIR/sent.jsonl"
rm -f "$TMP_ROOT/.claude/stakeholder/pending-approval/"*.md
rm -f "$TMP_ROOT/.claude/stakeholder/pending-proposal/"*.md
_make_approval "20260512-100000-csv-export" propose 12345

printf '[{"update_id": 206, "message": {"message_id": 206, "from": {"id": 12345, "first_name": "Test"}, "chat": {"id": 99}, "text": "change 20260512-100000-csv-export use sqlite instead"}}]' > "$MOCK_DIR/updates.json"

REPO_ROOT="$TMP_ROOT" CLAUDE_PROJECT_DIR="$TMP_ROOT" MOCK_TELEGRAM_API_DIR="$MOCK_DIR" \
TELEGRAM_BOT_TOKEN="mock-token" TELEGRAM_ALLOWED_USER_IDS="12345" \
MOCK_INTAKE_COUNCIL_CMD="true" \
  python3 "$BOT_PY" --once 2>/dev/null

if [ -f "$TMP_ROOT/.claude/stakeholder/pending-approval/20260512-100000-csv-export.superseded.md" ]; then
  _pass "superseded file created"
else
  _fail "superseded file missing"
fi
if [ -f "$TMP_ROOT/.claude/stakeholder/pending-proposal/20260512-100000-csv-export.md" ] \
   && grep -q '^round: 2' "$TMP_ROOT/.claude/stakeholder/pending-proposal/20260512-100000-csv-export.md"; then
  _pass "new pending-proposal with round=2"
else
  _fail "round-2 proposal missing"
fi

# --- Test I8: MAX_INTAKE_ROUNDS — 4th change blocked ---
printf '\nTest I8: round=3 → change blocked\n'
rm -f "$MOCK_DIR/sent.jsonl"
rm -f "$TMP_ROOT/.claude/stakeholder/pending-approval/"*.md
cat > "$TMP_ROOT/.claude/stakeholder/pending-approval/20260512-100000-csv-export.md" <<'EOF'
---
id: 20260512-100000-csv-export
source: tier-2
trust_tier: 2
user_id: 12345
created_at: 2026-05-12T10:00:00Z
state: pending-approval
verdict: propose
round: 3
council_cost_usd: 0.40
hmac_token: 0123456789abcdef
pushed_at: ""
requires_human_dispute: false
touches: []
created_from: intake-council
---
EOF

printf '[{"update_id": 207, "message": {"message_id": 207, "from": {"id": 12345, "first_name": "Test"}, "chat": {"id": 99}, "text": "change 20260512-100000-csv-export blocked text"}}]' > "$MOCK_DIR/updates.json"

REPO_ROOT="$TMP_ROOT" CLAUDE_PROJECT_DIR="$TMP_ROOT" MOCK_TELEGRAM_API_DIR="$MOCK_DIR" \
TELEGRAM_BOT_TOKEN="mock-token" TELEGRAM_ALLOWED_USER_IDS="12345" \
  python3 "$BOT_PY" --once 2>/dev/null

if python3 -c "
import json
lines = open('$MOCK_DIR/sent.jsonl').readlines()
ok = any('Max 3 Runden' in json.loads(l).get('text','') for l in lines)
import sys; sys.exit(0 if ok else 1)
" 2>/dev/null; then
  _pass "round-limit blocked 4th change"
else
  _fail "round-limit NOT enforced"
fi

# --- Test I9: Verdict-Push-Watcher pushes + sets pushed_at ---
printf '\nTest I9: watcher pushes verdict + sets pushed_at\n'
rm -f "$MOCK_DIR/sent.jsonl"
rm -f "$TMP_ROOT/.claude/stakeholder/pending-approval/"*.md
_make_approval "20260512-100000-csv-export" propose 12345

REPO_ROOT="$TMP_ROOT" CLAUDE_PROJECT_DIR="$TMP_ROOT" MOCK_TELEGRAM_API_DIR="$MOCK_DIR" \
TELEGRAM_BOT_TOKEN="mock-token" TELEGRAM_ALLOWED_USER_IDS="12345" \
MOCK_COST_TODAY_USD="2.50" \
  python3 "$BOT_PY" --watch-once 2>/dev/null

if grep -q 'pushed_at: 20' "$TMP_ROOT/.claude/stakeholder/pending-approval/20260512-100000-csv-export.md"; then
  _pass "pushed_at set after push"
else
  _fail "pushed_at NOT set"
fi
if [ -f "$TMP_ROOT/.claude/overseer/notifications/sent.jsonl" ] && \
   grep -q 'intake-verdict' "$TMP_ROOT/.claude/overseer/notifications/sent.jsonl"; then
  _pass "notify.sh invoked with intake-verdict topic"
else
  _fail "notify.sh not invoked"
fi

# --- Test I10: Watcher-Idempotency ---
printf '\nTest I10: watcher idempotency (no double-push)\n'
NOTIF_COUNT_BEFORE="$(wc -l < "$TMP_ROOT/.claude/overseer/notifications/sent.jsonl" 2>/dev/null | tr -d ' ' || echo 0)"
REPO_ROOT="$TMP_ROOT" CLAUDE_PROJECT_DIR="$TMP_ROOT" \
  python3 "$BOT_PY" --watch-once 2>/dev/null
NOTIF_COUNT_AFTER="$(wc -l < "$TMP_ROOT/.claude/overseer/notifications/sent.jsonl" 2>/dev/null | tr -d ' ' || echo 0)"
if [ "$NOTIF_COUNT_BEFORE" = "$NOTIF_COUNT_AFTER" ]; then
  _pass "second tick: no new notification"
else
  _fail "second tick pushed again (before=$NOTIF_COUNT_BEFORE after=$NOTIF_COUNT_AFTER)"
fi

# --- Test I11: Mini-format contains emoji + slug + 1-sentence ---
printf '\nTest I11: mini-format contents\n'
NOTIF_FILE="$TMP_ROOT/.claude/overseer/notifications/sent.jsonl"
# Stub writes raw body (newlines escape JSON, so grep the file directly)
if grep -q '✅' "$NOTIF_FILE" 2>/dev/null \
   && grep -q 'csv-export' "$NOTIF_FILE" 2>/dev/null; then
  _pass "mini-format contains emoji + slug"
else
  _fail "mini-format missing emoji/slug"
fi

# --- Test I12: go-anyway requires reason for reject-verdict ---
printf '\nTest I12: go-anyway requires reason\n'
rm -f "$MOCK_DIR/sent.jsonl"
rm -f "$TMP_ROOT/.claude/stakeholder/pending-approval/"*.md
_make_approval "20260512-100000-csv-export" reject 12345 0123456789abcdef

# Short reason (<= 10 chars) → blocked
printf '[{"update_id": 208, "message": {"message_id": 208, "from": {"id": 12345, "first_name": "Test"}, "chat": {"id": 99}, "text": "go-anyway 20260512-100000-csv-export 0123456789abcdef short"}}]' > "$MOCK_DIR/updates.json"
REPO_ROOT="$TMP_ROOT" CLAUDE_PROJECT_DIR="$TMP_ROOT" MOCK_TELEGRAM_API_DIR="$MOCK_DIR" \
TELEGRAM_BOT_TOKEN="mock-token" TELEGRAM_ALLOWED_USER_IDS="12345" \
  python3 "$BOT_PY" --once 2>/dev/null

if python3 -c "
import json
lines = open('$MOCK_DIR/sent.jsonl').readlines()
ok = any('Begründung' in json.loads(l).get('text','') for l in lines)
import sys; sys.exit(0 if ok else 1)
" 2>/dev/null; then
  _pass "short reason rejected"
else
  _fail "short reason not enforced"
fi

# --- Test I13: ID-Disambiguation slug-prefix unique → auto-target ---
printf '\nTest I13: slug-prefix disambig (csv → csv-export)\n'
rm -f "$MOCK_DIR/sent.jsonl"
rm -f "$TMP_ROOT/.claude/stakeholder/pending-approval/"*.md
_make_approval "20260512-100000-csv-export" propose 12345 0123456789abcdef
_make_approval "20260512-100100-dark-footer" propose 12345 fedcba9876543210
_make_approval "20260512-100200-inbox-filter" propose 12345 1111222233334444

printf '[{"update_id": 209, "message": {"message_id": 209, "from": {"id": 12345, "first_name": "Test"}, "chat": {"id": 99}, "text": "go csv 0123456789abcdef"}}]' > "$MOCK_DIR/updates.json"

REPO_ROOT="$TMP_ROOT" CLAUDE_PROJECT_DIR="$TMP_ROOT" MOCK_TELEGRAM_API_DIR="$MOCK_DIR" \
TELEGRAM_BOT_TOKEN="mock-token" TELEGRAM_ALLOWED_USER_IDS="12345" \
MOCK_INTAKE_VALIDATOR_CMD="echo pass" \
  python3 "$BOT_PY" --once 2>/dev/null

if python3 -c "
import json
lines = open('$MOCK_DIR/sent.jsonl').readlines()
ok = any('approved' in json.loads(l).get('text','') and 'csv-export' in json.loads(l).get('text','') for l in lines)
import sys; sys.exit(0 if ok else 1)
" 2>/dev/null; then
  _pass "slug-prefix 'csv' matched 'csv-export'"
else
  _fail "slug-prefix match failed: $(cat $MOCK_DIR/sent.jsonl)"
fi

# --- Test I14: /yota pending empty → "Nichts offen" ---
printf '\nTest I14: /yota pending empty\n'
rm -f "$TMP_ROOT/.claude/stakeholder/pending-approval/"*.md 2>/dev/null
rm -f "$MOCK_DIR/sent.jsonl"
printf '[{"update_id": 210, "message": {"message_id": 210, "from": {"id": 12345, "first_name": "Test"}, "chat": {"id": 99}, "text": "/yota pending"}}]' > "$MOCK_DIR/updates.json"

REPO_ROOT="$TMP_ROOT" CLAUDE_PROJECT_DIR="$TMP_ROOT" MOCK_TELEGRAM_API_DIR="$MOCK_DIR" \
TELEGRAM_BOT_TOKEN="mock-token" TELEGRAM_ALLOWED_USER_IDS="12345" \
  python3 "$BOT_PY" --once 2>/dev/null

if python3 -c "
import json
lines = open('$MOCK_DIR/sent.jsonl').readlines()
ok = any('Nichts offen' in json.loads(l).get('text','') for l in lines)
import sys; sys.exit(0 if ok else 1)
" 2>/dev/null; then
  _pass "empty pending → 'Nichts offen'"
else
  _fail "empty pending did not reply correctly"
fi

# --- Test I15: /yota propose rate-limit (6th blocked) ---
printf '\nTest I15: /yota propose rate-limit\n'
rm -f "$TMP_ROOT/.claude/overseer/state/telegram-ratelimit.json"
rm -f "$TMP_ROOT/.claude/stakeholder/pending-proposal/"*.md
rm -f "$MOCK_DIR/sent.jsonl"

for I in 300 301 302 303 304 305; do
  printf "[{\"update_id\": $I, \"message\": {\"message_id\": $I, \"from\": {\"id\": 12345, \"first_name\": \"Test\"}, \"chat\": {\"id\": 99}, \"text\": \"/yota propose idee $I\"}}]" > "$MOCK_DIR/updates.json"
  REPO_ROOT="$TMP_ROOT" CLAUDE_PROJECT_DIR="$TMP_ROOT" MOCK_TELEGRAM_API_DIR="$MOCK_DIR" \
  TELEGRAM_BOT_TOKEN="mock-token" TELEGRAM_ALLOWED_USER_IDS="12345" \
  MOCK_INTAKE_COUNCIL_CMD="true" \
    python3 "$BOT_PY" --once 2>/dev/null
done

if python3 -c "
import json
lines = open('$MOCK_DIR/sent.jsonl').readlines()
hits = sum(1 for l in lines if 'Rate-Limit' in json.loads(l).get('text','') or 'rate-limited' in json.loads(l).get('text','').lower())
import sys; sys.exit(0 if hits >= 1 else 1)
" 2>/dev/null; then
  _pass "6th /yota propose blocked by rate-limit"
else
  _fail "rate-limit not enforced"
fi

# --- Test I16: Quiet-Hours notify.sh forwarding (NOTIFY_FORCE_HOUR=23) ---
printf '\nTest I16: quiet-hours forwarding\n'
rm -f "$TMP_ROOT/.claude/overseer/notifications/sent.jsonl"
rm -f "$TMP_ROOT/.claude/stakeholder/pending-approval/"*.md
_make_approval "20260512-100000-csv-export" propose 12345

REPO_ROOT="$TMP_ROOT" CLAUDE_PROJECT_DIR="$TMP_ROOT" \
MOCK_HOUR="23" \
  python3 "$BOT_PY" --watch-once 2>/dev/null

if [ -f "$TMP_ROOT/.claude/overseer/notifications/sent.jsonl" ] && \
   grep -q '"severity":"info"' "$TMP_ROOT/.claude/overseer/notifications/sent.jsonl"; then
  _pass "quiet-hours info-push routed through notify.sh"
else
  _fail "quiet-hours push not routed"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
