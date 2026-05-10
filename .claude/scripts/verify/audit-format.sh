#!/usr/bin/env bash
# verify/audit-format.sh — Sandbox tests for lib/audit.sh and audit-record.sh.
#
# Tests:
#   1. 3 sequential audit_record calls → 3 entries, correct hash chain
#   2. audit-verify.sh → exit 0
#   3. Tampering test: modify entry 2's subject → audit-verify.sh exit 1
#   4. 0444 permission after append
#   5. flock test: 10 parallel audit_record calls → 10 entries, chain valid
#   6. Multiline reason → JSON-encoded, audit-verify.sh exit 0
#
# Exit 0 = all pass, 1 = at least one failure.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"
BIN_DIR="${SCRIPT_DIR}/.."

PASS=0
FAIL=0
ERRORS=()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
_pass() {
  printf '  PASS: %s\n' "$1"
  PASS=$((PASS + 1))
}

_fail() {
  printf '  FAIL: %s\n' "$1"
  FAIL=$((FAIL + 1))
  ERRORS+=("$1")
}

_assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    _pass "$label"
  else
    _fail "$label (expected='$expected', got='$actual')"
  fi
}

# Make file writable (undo 0444 + chflags uchg)
_make_writable() {
  local f="$1"
  [ -f "$f" ] || return 0
  chflags nouchg "$f" 2>/dev/null || true
  chmod 0644 "$f" 2>/dev/null || true
}

# Remove file safely (undo immutable flags first)
_safe_rm() {
  local f="$1"
  [ -f "$f" ] || return 0
  _make_writable "$f"
  rm -f "$f"
}

# ---------------------------------------------------------------------------
# Setup: temp dir as mock project
# ---------------------------------------------------------------------------
TMPDIR_BASE="$(mktemp -d)"
cleanup() {
  # Remove uchg flags before cleanup to avoid rm failures on macOS
  if [ -d "$TMPDIR_BASE" ]; then
    find "$TMPDIR_BASE" -type f -exec chflags nouchg {} \; 2>/dev/null || true
    find "$TMPDIR_BASE" -type f -exec chmod 0644 {} \; 2>/dev/null || true
    rm -rf "$TMPDIR_BASE"
  fi
}
trap cleanup EXIT

MOCK_PROJECT="${TMPDIR_BASE}/mock_project"
mkdir -p "${MOCK_PROJECT}/.claude/audit"
export CLAUDE_PROJECT_DIR="$MOCK_PROJECT"

TODAY="$(date -u +%Y-%m-%d)"
AUDIT_FILE="${MOCK_PROJECT}/.claude/audit/${TODAY}.md"

# We need a git repo for rev-parse (used in audit.sh)
git -C "$MOCK_PROJECT" init -q 2>/dev/null || true
git -C "$MOCK_PROJECT" commit --allow-empty -m "init" -q 2>/dev/null || true

# Source the library
# shellcheck source=../lib/audit.sh
source "${LIB_DIR}/audit.sh"

# ---------------------------------------------------------------------------
printf '\n=== Test 1: 3 sequential audit_record calls ===\n'
{
  _safe_rm "$AUDIT_FILE"

  audit_record "test-actor" "test-action" "subject-1" "reason one"
  audit_record "test-actor" "test-action" "subject-2" "reason two"
  audit_record "test-actor" "test-action" "subject-3" "reason three"

  # Count entries
  entry_count="$(python3 -c "
import re
with open('$AUDIT_FILE') as f:
    content = f.read()
entries = re.findall(r'---\n.*?---\n', content, re.DOTALL)
print(len(entries))
")"
  _assert_eq "3 entries in file" "3" "$entry_count"

  # Verify hash chain via python3
  chain_result="$(python3 - "$AUDIT_FILE" <<'PYEOF'
import sys, re, hashlib

def sha256(s):
    return hashlib.sha256(s.encode('utf-8')).hexdigest()

path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()

raw_matches = list(re.finditer(r'---\n.*?---\n', content, re.DOTALL))
bodies = [m.group(0) for m in raw_matches]

def parse_fields(block):
    fields = {}
    for line in block.split('\n'):
        line = line.rstrip()
        if ': ' in line:
            k, _, v = line.partition(': ')
            fields[k.strip()] = v.strip()
    return fields

accumulated = ""
errors = []
for i, block in enumerate(bodies):
    fields = parse_fields(block)
    if i == 0:
        expected_prev = "0" * 64
    else:
        expected_prev = sha256(accumulated)
    if fields.get('prev_hash') != expected_prev:
        errors.append(f"Entry {i+1} prev_hash mismatch")
    accumulated += block + '\n'

print("OK" if not errors else "FAIL:" + ";".join(errors))
PYEOF
)"
  _assert_eq "hash chain valid (3 entries)" "OK" "$chain_result"
}

printf '\n=== Test 2: audit-verify.sh exit 0 on valid chain ===\n'
{
  bash "${BIN_DIR}/audit-verify.sh" "$AUDIT_FILE"
  _assert_eq "audit-verify.sh exit 0" "0" "$?"
}

printf '\n=== Test 3: Tampering test → audit-verify.sh exit 1 ===\n'
{
  # Make writable to tamper
  _make_writable "$AUDIT_FILE"

  # Replace "subject-2" with "TAMPERED" in the second entry block
  python3 -c "
with open('$AUDIT_FILE', 'r') as f:
    content = f.read()
# Replace only first occurrence of 'subject-2' in the subject field
# (careful: don't replace in reason text)
content = content.replace('subject: subject-2', 'subject: TAMPERED', 1)
with open('$AUDIT_FILE', 'w') as f:
    f.write(content)
"

  bash "${BIN_DIR}/audit-verify.sh" "$AUDIT_FILE" >/dev/null 2>&1
  verify_exit=$?
  if [ "$verify_exit" -eq 1 ]; then
    _pass "audit-verify.sh exit 1 on tampered entry"
  else
    _fail "audit-verify.sh should exit 1 on tampered entry (got $verify_exit)"
  fi

  # Restore: remove tampered file and re-create clean version
  _safe_rm "$AUDIT_FILE"
  audit_record "test-actor" "test-action" "subject-1" "reason one"
  audit_record "test-actor" "test-action" "subject-2" "reason two"
  audit_record "test-actor" "test-action" "subject-3" "reason three"
}

printf '\n=== Test 4: 0444 permission after append ===\n'
{
  perms="$(stat -f "%OLp" "$AUDIT_FILE" 2>/dev/null || stat -c "%a" "$AUDIT_FILE" 2>/dev/null)"
  _assert_eq "file permissions are 0444" "444" "$perms"
}

printf '\n=== Test 5: flock test — 10 parallel audit_record calls ===\n'
{
  # Reset
  _safe_rm "$AUDIT_FILE"

  # Spawn 10 parallel subshells each calling audit_record
  pids=()
  for i in $(seq 1 10); do
    (
      source "${LIB_DIR}/audit.sh"
      audit_record "parallel-actor" "parallel-action" "subject-${i}" "parallel reason ${i}"
    ) &
    pids+=($!)
  done

  # Wait for all
  for pid in "${pids[@]}"; do
    wait "$pid" 2>/dev/null || true
  done

  # Count entries
  entry_count="$(python3 -c "
import re
with open('$AUDIT_FILE') as f:
    content = f.read()
entries = re.findall(r'---\n.*?---\n', content, re.DOTALL)
print(len(entries))
" 2>/dev/null || echo "0")"

  _assert_eq "10 entries after parallel writes" "10" "$entry_count"

  # Verify chain
  bash "${BIN_DIR}/audit-verify.sh" "$AUDIT_FILE"
  _assert_eq "chain valid after parallel writes" "0" "$?"
}

printf '\n=== Test 6: Multiline reason → JSON-encoded, chain valid ===\n'
{
  # Reset
  _safe_rm "$AUDIT_FILE"

  multiline_reason="$(printf 'line1\nline2\nline3')"
  audit_record "test-actor" "test-action" "multiline-subject" "$multiline_reason"

  # Check reason is JSON-encoded (should start with a double-quote)
  reason_raw="$(python3 -c "
import re
with open('$AUDIT_FILE') as f:
    content = f.read()
m = re.search(r'reason: (.*)', content)
if m:
    print(m.group(1).strip()[:1])
")"
  _assert_eq "reason is JSON-encoded (starts with quote)" '"' "$reason_raw"

  # Verify chain
  bash "${BIN_DIR}/audit-verify.sh" "$AUDIT_FILE"
  _assert_eq "chain valid with multiline reason" "0" "$?"
}

printf '\n=== Test 7: Syslog mirror — entry_hash present in stub-syslog ===\n'
{
  _safe_rm "$AUDIT_FILE"

  # Inject stub `logger` into PATH so audit_record's `logger -t claude-audit ...`
  # writes to a tmpfile we can later inspect.
  STUB_DIR="$(mktemp -d)"
  STUB_SYSLOG="${STUB_DIR}/syslog.txt"
  : > "$STUB_SYSLOG"
  cat > "${STUB_DIR}/logger" <<EOF
#!/usr/bin/env bash
# Stub logger — append everything (skip -t TAG) to STUB_SYSLOG.
shift_count=0
while [ \$# -gt 0 ]; do
  case "\$1" in
    -t) shift 2 ;;
    --) shift; break ;;
    -*) shift ;;
     *) break ;;
  esac
done
printf '%s\n' "\$*" >> "${STUB_SYSLOG}"
EOF
  chmod +x "${STUB_DIR}/logger"
  PATH="${STUB_DIR}:${PATH}"
  export PATH

  audit_record "syslog-actor" "syslog-action" "syslog-subject" "syslog reason"

  # Extract entry_hash from local audit file
  local_hash="$(python3 -c "
import re
with open('$AUDIT_FILE') as f: c=f.read()
m=re.search(r'entry_hash:\s*([0-9a-f]{64})',c)
print(m.group(1) if m else '')
")"

  if [ -n "$local_hash" ] && grep -qF "entry_hash=$local_hash" "$STUB_SYSLOG"; then
    _pass "syslog mirror contains entry_hash"
  else
    _fail "syslog mirror missing entry_hash (hash=$local_hash, syslog=$(cat $STUB_SYSLOG))"
  fi

  # audit-verify with CLAUDE_AUDIT_SYSLOG_FILE → exit 0
  CLAUDE_AUDIT_SYSLOG_FILE="$STUB_SYSLOG" bash "${BIN_DIR}/audit-verify.sh" "$AUDIT_FILE" >/dev/null 2>&1
  _assert_eq "audit-verify with syslog stub exits 0" "0" "$?"

  # Tamper: remove syslog line → audit-verify should detect
  : > "$STUB_SYSLOG"
  CLAUDE_AUDIT_SYSLOG_FILE="$STUB_SYSLOG" bash "${BIN_DIR}/audit-verify.sh" "$AUDIT_FILE" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 1 ]; then
    _pass "audit-verify detects tampering when syslog mirror missing"
  else
    _fail "audit-verify did NOT detect missing syslog (rc=$rc)"
  fi

  rm -rf "$STUB_DIR"
}

printf '\n=== Test 8: Rate-limit (DoS protection) ===\n'
{
  _safe_rm "$AUDIT_FILE"
  # Reset rate-limit state from previous tests
  rm -f "${MOCK_PROJECT}/.claude/audit/.audit.ratelimit" \
        "${MOCK_PROJECT}/.claude/audit/.audit.ratelimit.lock"

  # Cap at 5 / minute
  CLAUDE_AUDIT_MAX_PER_MINUTE=5
  export CLAUDE_AUDIT_MAX_PER_MINUTE

  ok_count=0
  drop_count=0
  for i in $(seq 1 8); do
    if audit_record "rl-actor" "rl-action" "rl-subject-$i" "rl reason $i" 2>/dev/null; then
      ok_count=$((ok_count+1))
    else
      drop_count=$((drop_count+1))
    fi
  done

  unset CLAUDE_AUDIT_MAX_PER_MINUTE

  if [ "$ok_count" -eq 5 ] && [ "$drop_count" -eq 3 ]; then
    _pass "rate-limit: 5 accepted, 3 dropped"
  else
    _fail "rate-limit: expected 5/3, got $ok_count/$drop_count"
  fi
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Summary ===\n'
printf 'PASS: %d  FAIL: %d\n' "$PASS" "$FAIL"

if [ ${#ERRORS[@]} -gt 0 ]; then
  printf '\nFailed tests:\n'
  for e in "${ERRORS[@]}"; do
    printf '  - %s\n' "$e"
  done
  exit 1
fi

exit 0
