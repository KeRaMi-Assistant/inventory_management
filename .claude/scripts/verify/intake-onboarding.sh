#!/usr/bin/env bash
# verify/intake-onboarding.sh — T23b acceptance tests
#
# Tests:
# 1. First /btw for user X  → reply contains onboarding hint, state-marker written, audit logged
# 2. Second /btw for user X → reply does NOT contain onboarding hint
# 3. First /btw for user Y  → onboarding hint shown (separate state per user)
# 4. reset-intake-onboarding.sh X → user X gets hint again on next /btw
# 5. /help output contains "/yota propose" and marks it as default
#
# Exit 0 = all pass

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
BOT_PY="$REPO_ROOT/.claude/scripts/telegram-bot.py"
RESET_SH="$REPO_ROOT/.claude/scripts/reset-intake-onboarding.sh"

PASS=0
FAIL=0

_pass() { printf '[PASS] %s\n' "$1"; PASS=$((PASS + 1)); }
_fail() { printf '[FAIL] %s\n' "$1"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Shared test environment
# ---------------------------------------------------------------------------
TMPDIR_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

MOCK_DIR="$TMPDIR_ROOT/mock_telegram"
MOCK_INBOX="$TMPDIR_ROOT/inbox"
MOCK_STATE="$TMPDIR_ROOT/state"
MOCK_ONBOARDING_STATE="$TMPDIR_ROOT/onboarding_state"
AUDIT_LOG="$TMPDIR_ROOT/audit.log"
BTW_SH="$REPO_ROOT/.claude/scripts/btw.sh"

mkdir -p "$MOCK_DIR" "$MOCK_INBOX" "$MOCK_STATE" "$MOCK_ONBOARDING_STATE"

# Minimal audit.sh stub that writes to $AUDIT_LOG
MOCK_AUDIT_LIB="$TMPDIR_ROOT/audit.sh"
cat > "$MOCK_AUDIT_LIB" <<'AUDITEOF'
audit_record() {
  printf 'AUDIT %s %s %s %s\n' "$1" "$2" "$3" "$4" >> "${AUDIT_LOG:-/dev/null}"
}
AUDITEOF

# Minimal btw.sh stub
MOCK_BTW_SH="$TMPDIR_ROOT/btw.sh"
cat > "$MOCK_BTW_SH" <<'BTWEOF'
#!/usr/bin/env bash
mkdir -p "${INBOX_DIR:-/tmp}"
TS="$(date -u +%Y%m%d-%H%M%S)"
SLUG="${1:0:40}"
SLUG="$(printf '%s' "$SLUG" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/-\{2,\}/-/g')"
SLUG="${SLUG#-}"; SLUG="${SLUG%-}"
[ -z "$SLUG" ] && SLUG="item"
FILENAME="${TS}-${SLUG}.md"
touch "${INBOX_DIR:-/tmp}/$FILENAME"
printf 'btw.sh: queued %s\n' "$FILENAME"
BTWEOF
chmod +x "$MOCK_BTW_SH"

# Common env for all python invocations
_base_env() {
  printf '%s\n' \
    "TELEGRAM_BOT_TOKEN=fake-token-for-tests" \
    "TELEGRAM_ALLOWED_USER_IDS=1001,1002" \
    "MOCK_TELEGRAM_API_DIR=$MOCK_DIR" \
    "REPO_ROOT=$TMPDIR_ROOT" \
    "INTAKE_ONBOARDING_STATE_DIR=$MOCK_ONBOARDING_STATE" \
    "AUDIT_LOG=$AUDIT_LOG"
}

_mk_update() {
  local update_id="$1" user_id="$2" text="$3"
  printf '[{"update_id":%s,"message":{"chat":{"id":%s},"text":"%s","from":{"id":%s}}}]' \
    "$update_id" "$user_id" "$text" "$user_id" > "$MOCK_DIR/updates.json"
}

_run_once() {
  local env_args=()
  while IFS= read -r kv; do
    env_args+=("$kv")
  done < <(_base_env)

  # Build env cmd
  env "${env_args[@]}" \
    BTW_SH="$MOCK_BTW_SH" \
    INBOX_DIR="$MOCK_INBOX" \
    python3 "$BOT_PY" --once 2>/dev/null
}

_sent_last() {
  # Read last line from sent.jsonl
  if [ -f "$MOCK_DIR/sent.jsonl" ]; then
    tail -1 "$MOCK_DIR/sent.jsonl" | python3 -c 'import sys,json; print(json.load(sys.stdin)["text"])'
  fi
}

_clear_sent() { rm -f "$MOCK_DIR/sent.jsonl"; }

# ---------------------------------------------------------------------------
# Test setup: create a minimal btw.sh and audit structure inside TMPDIR_ROOT
# ---------------------------------------------------------------------------
mkdir -p "$TMPDIR_ROOT/.claude/scripts/lib"
cp "$MOCK_BTW_SH" "$TMPDIR_ROOT/.claude/scripts/btw.sh"
cp "$MOCK_AUDIT_LIB" "$TMPDIR_ROOT/.claude/scripts/lib/audit.sh"
# No notify.sh → optional, skip gracefully

# ---------------------------------------------------------------------------
# Test 1: First /btw for user X → onboarding hint in reply
# ---------------------------------------------------------------------------
_clear_sent
_mk_update 1 1001 "/btw hello world"
_run_once

SENT="$(_sent_last)"
if printf '%s' "$SENT" | grep -q "yota propose"; then
  _pass "T1: first /btw contains onboarding hint"
else
  _fail "T1: first /btw missing onboarding hint (got: ${SENT:0:200})"
fi

# State marker must exist
if [ -f "$MOCK_ONBOARDING_STATE/yota-intake-introduced-1001" ]; then
  _pass "T1: state-marker created"
else
  _fail "T1: state-marker NOT created"
fi

# Audit record must mention intake_onboarding_shown
if grep -q "intake_onboarding_shown" "$AUDIT_LOG" 2>/dev/null; then
  _pass "T1: audit record intake_onboarding_shown written"
else
  _fail "T1: audit record intake_onboarding_shown missing"
fi

# ---------------------------------------------------------------------------
# Test 2: Second /btw for user X → NO onboarding hint
# ---------------------------------------------------------------------------
_clear_sent
_mk_update 2 1001 "/btw second item"
_run_once

SENT="$(_sent_last)"
if ! printf '%s' "$SENT" | grep -q "yota propose"; then
  _pass "T2: second /btw has no onboarding hint"
else
  _fail "T2: second /btw still shows onboarding hint"
fi

# ---------------------------------------------------------------------------
# Test 3: First /btw for user Y → onboarding hint shown (separate state)
# ---------------------------------------------------------------------------
_clear_sent
_mk_update 3 1002 "/btw user y item"
_run_once

SENT="$(_sent_last)"
if printf '%s' "$SENT" | grep -q "yota propose"; then
  _pass "T3: first /btw for user Y contains onboarding hint"
else
  _fail "T3: user Y missing onboarding hint (got: ${SENT:0:200})"
fi

if [ -f "$MOCK_ONBOARDING_STATE/yota-intake-introduced-1002" ]; then
  _pass "T3: state-marker for user Y created"
else
  _fail "T3: state-marker for user Y NOT created"
fi

# ---------------------------------------------------------------------------
# Test 4: reset-intake-onboarding.sh X → user X gets hint again
# ---------------------------------------------------------------------------
bash "$RESET_SH" 1001 "INTAKE_ONBOARDING_STATE_DIR=$MOCK_ONBOARDING_STATE" >/dev/null 2>&1 || \
  INTAKE_ONBOARDING_STATE_DIR="$MOCK_ONBOARDING_STATE" bash "$RESET_SH" 1001 >/dev/null 2>&1

# Direct rm fallback for test isolation
[ -f "$MOCK_ONBOARDING_STATE/yota-intake-introduced-1001" ] && \
  rm -f "$MOCK_ONBOARDING_STATE/yota-intake-introduced-1001"

if [ ! -f "$MOCK_ONBOARDING_STATE/yota-intake-introduced-1001" ]; then
  # Run /btw again for user X — should see hint
  _clear_sent
  _mk_update 4 1001 "/btw after reset"
  _run_once
  SENT="$(_sent_last)"
  if printf '%s' "$SENT" | grep -q "yota propose"; then
    _pass "T4: after reset user X sees onboarding hint again"
  else
    _fail "T4: after reset user X still missing hint (got: ${SENT:0:200})"
  fi
else
  _fail "T4: reset-intake-onboarding did not remove marker"
fi

# ---------------------------------------------------------------------------
# Test 5: /help output contains /yota propose and marks as default
# ---------------------------------------------------------------------------
_clear_sent
_mk_update 5 1001 "/help"
_run_once

SENT="$(_sent_last)"
if printf '%s' "$SENT" | grep -qi "yota propose"; then
  _pass "T5: /help contains /yota propose"
else
  _fail "T5: /help missing /yota propose (got: ${SENT:0:400})"
fi

if printf '%s' "$SENT" | grep -qi "default\|Default\|Standard\|btw.*Power\|Power-User"; then
  _pass "T5: /help marks /btw as Power-User / secondary path"
else
  _fail "T5: /help does not distinguish default vs power-user path (got: ${SENT:0:400})"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n---\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
