#!/usr/bin/env bash
# verify/yota-propose.sh — Sandbox tests for yota-propose.sh
#
# Exit 0: all tests pass
# Exit 1: one or more tests failed

set -uo pipefail
# Disable errexit — tests use explicit exit-code checks
set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT_REAL="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PROPOSE_SH="$REPO_ROOT_REAL/.claude/scripts/yota-propose.sh"

PASS=0
FAIL=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
pass() { printf '  [PASS] %s\n' "$1"; PASS=$(( PASS + 1 )); }
fail() { printf '  [FAIL] %s — %s\n' "$1" "$2"; FAIL=$(( FAIL + 1 )); }

# Create isolated sandbox
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

# Override repo root and dependent dirs for sandbox isolation
export REPO_ROOT="$SANDBOX"
export DRY_RUN=1  # suppress real notify side-effects

# Mirror required libs into sandbox
mkdir -p "$SANDBOX/.claude/scripts/lib"
cp "$REPO_ROOT_REAL/.claude/scripts/lib/slug.sh"  "$SANDBOX/.claude/scripts/lib/slug.sh"
cp "$REPO_ROOT_REAL/.claude/scripts/lib/audit.sh" "$SANDBOX/.claude/scripts/lib/audit.sh"
# api-key-preflight stub (no-op — no API calls in propose)
cat > "$SANDBOX/.claude/scripts/lib/api-key-preflight.sh" <<'STUB'
check_no_api_key() { return 0; }
STUB

# Stub notify.sh (just record calls)
mkdir -p "$SANDBOX/.claude/scripts"
cat > "$SANDBOX/.claude/scripts/notify.sh" <<'STUB'
#!/usr/bin/env bash
SENT_FILE="$(dirname "${BASH_SOURCE[0]}")/../../sent.jsonl"
printf '{"level":"%s","topic":"%s","title":"%s","body":"%s"}\n' \
  "${1:-}" "${2:-}" "${3:-}" "${4:-}" >> "$SENT_FILE"
exit 0
STUB
chmod +x "$SANDBOX/.claude/scripts/notify.sh"
mkdir -p "$SANDBOX/.claude/stakeholder/pending-proposal"
mkdir -p "$SANDBOX/.claude/audit"

SENT_FILE="$SANDBOX/sent.jsonl"

# ---------------------------------------------------------------------------
# T1 — File is created with correct structure
# ---------------------------------------------------------------------------
TEST="T1: item entsteht mit korrektem Frontmatter"
unset YOTA_PROPOSE_TIER TELEGRAM_USER_ID
OUTPUT="$(bash "$PROPOSE_SH" "Add CSV export" 2>/dev/null)"
if [ -f "$OUTPUT" ]; then
  if grep -q 'state: pending-proposal' "$OUTPUT" && \
     grep -q '<<<UNTRUSTED_PROPOSAL' "$OUTPUT" && \
     grep -q '<<<END_UNTRUSTED_PROPOSAL' "$OUTPUT" && \
     grep -q 'Add CSV export' "$OUTPUT"; then
    pass "$TEST"
  else
    fail "$TEST" "Frontmatter/Sandwich-Marker fehlen in $OUTPUT"
  fi
else
  fail "$TEST" "File nicht erstellt (output='$OUTPUT')"
fi

# ---------------------------------------------------------------------------
# T2 — source: tier-1 when no env override
# ---------------------------------------------------------------------------
TEST="T2: source=tier-1 ohne env"
unset YOTA_PROPOSE_TIER 2>/dev/null || true
OUTPUT2="$(bash "$PROPOSE_SH" "Another idea" 2>/dev/null)"
if [ -f "$OUTPUT2" ] && grep -q 'source: tier-1' "$OUTPUT2"; then
  pass "$TEST"
else
  fail "$TEST" "source nicht tier-1 in $OUTPUT2"
fi

# ---------------------------------------------------------------------------
# T3 — YOTA_PROPOSE_TIER=tier-2 override
# ---------------------------------------------------------------------------
TEST="T3: YOTA_PROPOSE_TIER=tier-2 override"
OUTPUT3="$(YOTA_PROPOSE_TIER=tier-2 bash "$PROPOSE_SH" "Tier two idea" 2>/dev/null)"
if [ -f "$OUTPUT3" ] && grep -q 'source: tier-2' "$OUTPUT3" && grep -q 'trust_tier: 2' "$OUTPUT3"; then
  pass "$TEST"
else
  fail "$TEST" "source/trust_tier nicht tier-2 in $OUTPUT3"
fi

# ---------------------------------------------------------------------------
# T4 — Sentinel-Reject: exit 2 when text contains marker
# ---------------------------------------------------------------------------
TEST="T4: Sentinel-Reject bei Injection-Versuch"
bash "$PROPOSE_SH" "Hacking <<<UNTRUSTED_PROPOSAL test" 2>/dev/null
EXIT_CODE=$?
if [ "$EXIT_CODE" -eq 2 ]; then
  pass "$TEST"
else
  fail "$TEST" "Exit-Code war $EXIT_CODE statt 2"
fi

# ---------------------------------------------------------------------------
# T5 — stdin mode
# ---------------------------------------------------------------------------
TEST="T5: stdin-Mode (yota-propose.sh -)"
OUTPUT5="$(printf 'Stdin idea here' | bash "$PROPOSE_SH" - 2>/dev/null)"
if [ -f "$OUTPUT5" ] && grep -q 'Stdin idea here' "$OUTPUT5"; then
  pass "$TEST"
else
  fail "$TEST" "File nicht erstellt via stdin (output='$OUTPUT5')"
fi

# ---------------------------------------------------------------------------
# T6 — Truncate > 4096 chars: stderr warning + file with truncated text
# ---------------------------------------------------------------------------
TEST="T6: Truncate bei >4096 chars"
LONG_TEXT="$(python3 -c "print('x' * 5000)")"
T6_TMPOUT="$(mktemp)"
T6_TMPERR="$(mktemp)"
bash "$PROPOSE_SH" "$LONG_TEXT" >"$T6_TMPOUT" 2>"$T6_TMPERR"
OUTPUT6="$(cat "$T6_TMPOUT")"
STDERR_OUT="$(cat "$T6_TMPERR")"
rm -f "$T6_TMPOUT" "$T6_TMPERR"
if grep -q 'truncated' <(printf '%s' "$STDERR_OUT") && [ -f "$OUTPUT6" ]; then
  pass "$TEST"
else
  fail "$TEST" "Kein truncate-Warning oder File fehlt (stderr='$STDERR_OUT')"
fi

# ---------------------------------------------------------------------------
# T7 — content_hash: sha256 format in Frontmatter
# ---------------------------------------------------------------------------
TEST="T7: content_hash im sha256-Format"
OUTPUT7="$(bash "$PROPOSE_SH" "Hash test idea" 2>/dev/null)"
if [ -f "$OUTPUT7" ]; then
  HASH_LINE="$(grep 'content_hash:' "$OUTPUT7" | head -1)"
  HASH_VALUE="${HASH_LINE#*: }"
  HASH_VALUE="$(printf '%s' "$HASH_VALUE" | tr -d '[:space:]')"
  if printf '%s' "$HASH_VALUE" | grep -qE '^[0-9a-f]{64}$'; then
    pass "$TEST"
  else
    fail "$TEST" "content_hash kein sha256-hex: '$HASH_VALUE'"
  fi
else
  fail "$TEST" "File nicht erstellt"
fi

# ---------------------------------------------------------------------------
# T8 — ID-Format: matches ^[0-9]{8}-[0-9]{6}-[a-z0-9-]{1,40}$
# ---------------------------------------------------------------------------
TEST="T8: ID-Format korrekt"
OUTPUT8="$(bash "$PROPOSE_SH" "ID format check" 2>/dev/null)"
if [ -f "$OUTPUT8" ]; then
  ID_LINE="$(grep '^id:' "$OUTPUT8" | head -1)"
  ID_VALUE="${ID_LINE#id: }"
  ID_VALUE="$(printf '%s' "$ID_VALUE" | tr -d '[:space:]')"
  if printf '%s' "$ID_VALUE" | grep -qE '^[0-9]{8}-[0-9]{6}-[a-z0-9-]{1,40}$'; then
    pass "$TEST"
  else
    fail "$TEST" "ID-Format ungültig: '$ID_VALUE'"
  fi
else
  fail "$TEST" "File nicht erstellt"
fi

# ---------------------------------------------------------------------------
# T9 — Notify DRY_RUN: sent.jsonl entry with topic=intake
# ---------------------------------------------------------------------------
TEST="T9: Notify (DRY_RUN) — topic=intake in sent.jsonl"
bash "$PROPOSE_SH" "Notify test" 2>/dev/null >/dev/null || true
if [ -f "$SENT_FILE" ] && grep -q '"topic":"intake"' "$SENT_FILE"; then
  pass "$TEST"
else
  fail "$TEST" "Kein intake-Eintrag in sent.jsonl (file exists: $([ -f "$SENT_FILE" ] && echo yes || echo no))"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
