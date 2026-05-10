#!/usr/bin/env bash
# verify/scan-dead-code.sh — Sandbox tests for scan-dead-code analyzer module.
#
# Usage: bash .claude/scripts/verify/scan-dead-code.sh
# Exit 0 = all pass, exit 1 = one or more failures.
#
# Isolation: all tests run in a mktemp sandbox.
# dart is mocked via a PATH-prepended stub script.
# The stub reads $DART_MOCK_JSON (env var) or returns empty output.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
MODULE="$REPO_ROOT/.claude/analyzer/modules/scan-dead-code.sh"

if [ ! -f "$MODULE" ]; then
  printf 'ERROR: Module not found: %s\n' "$MODULE" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Test framework
# ---------------------------------------------------------------------------
_pass=0
_fail=0

ok() {
  printf '  \033[32m[PASS]\033[0m %s\n' "$1"
  _pass=$(( _pass + 1 ))
}

fail() {
  printf '  \033[31m[FAIL]\033[0m %s\n' "$1" >&2
  _fail=$(( _fail + 1 ))
}

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    ok "$label (expected=$expected)"
  else
    fail "$label (expected='$expected', actual='$actual')"
  fi
}

# ---------------------------------------------------------------------------
# Sandbox setup
# ---------------------------------------------------------------------------
TMPBASE="$(mktemp -d /tmp/verify-scan-dead-code.XXXXXX)"
_cleanup() {
  find "$TMPBASE" -name "*.md" -type f 2>/dev/null \
    | xargs chflags nouchg 2>/dev/null || true
  find "$TMPBASE" -name "*.md" -type f 2>/dev/null \
    | xargs chmod 644 2>/dev/null || true
  rm -rf "$TMPBASE" 2>/dev/null || true
}
trap '_cleanup' EXIT INT TERM

_new_sandbox() {
  local name="$1"
  local sandbox="$TMPBASE/$name"
  mkdir -p "$sandbox"

  git -C "$sandbox" init -q
  git -C "$sandbox" config user.email "test@test.com"
  git -C "$sandbox" config user.name "Test"

  mkdir -p "$sandbox/.claude/scripts/lib"
  mkdir -p "$sandbox/.claude/overseer/inbox"
  mkdir -p "$sandbox/.claude/analyzer/state"
  mkdir -p "$sandbox/.claude/audit"
  mkdir -p "$sandbox/lib"
  mkdir -p "$sandbox/.bin"

  [ -f "$REPO_ROOT/.claude/scripts/lib/audit.sh" ] && \
    cp "$REPO_ROOT/.claude/scripts/lib/audit.sh" \
       "$sandbox/.claude/scripts/lib/audit.sh"

  mkdir -p "$sandbox/.claude/scripts"
  cat > "$sandbox/.claude/scripts/notify.sh" <<'STUB'
#!/usr/bin/env bash
_STUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_STUB_REPO_ROOT="$(cd "$_STUB_SCRIPT_DIR/../.." && pwd)"
SENT_DIR="$_STUB_REPO_ROOT/.claude/overseer/notifications"
mkdir -p "$SENT_DIR"
printf '{"severity":"%s","topic":"%s","title":"%s","body":"%s"}\n' \
  "${1:-}" "${2:-}" "${3:-}" "${4:-}" >> "$SENT_DIR/sent.jsonl"
STUB
  chmod +x "$sandbox/.claude/scripts/notify.sh"

  printf '%s' "$sandbox"
}

# Create a dart stub in $sandbox/.bin that returns $DART_MOCK_JSON or exits 127.
# DART_MOCK_OUTPUT controls what the stub returns.
_install_dart_stub() {
  local sandbox="$1"
  cat > "$sandbox/.bin/dart" <<'STUB'
#!/usr/bin/env bash
# dart mock stub
if [ "${DART_MISSING:-0}" = "1" ]; then
  exit 127
fi
output="${DART_MOCK_JSON:-}"
if [ -z "$output" ]; then
  # no findings
  printf '{"version":1,"diagnostics":[]}\n'
  exit 0
fi
printf '%s\n' "$output"
# dart analyze exits 1 when there are findings
exit 1
STUB
  chmod +x "$sandbox/.bin/dart"
}

# Run the module with PATH prepending the stub bin and overriding env vars.
_run_module() {
  local sandbox="$1"
  shift
  PATH="$sandbox/.bin:$PATH" \
  DART_CMD="dart" \
  ANALYZER_STATE_FILE="$sandbox/.claude/analyzer/state/scan-dead-code.json" \
  OVERSEER_INBOX_DIR="$sandbox/.claude/overseer/inbox" \
  CLAUDE_PROJECT_DIR="$sandbox" \
  bash "$MODULE" "$@"
}

# ---------------------------------------------------------------------------
# Helper: build a dart analyze JSON response with N diagnostics for a file.
# _make_dart_json <file_path> <lint_code> <count>
# ---------------------------------------------------------------------------
_make_dart_json() {
  local fpath="$1" code="$2" count="$3"
  python3 - "$fpath" "$code" "$count" <<'PYEOF'
import sys, json
fpath, code, count = sys.argv[1], sys.argv[2], int(sys.argv[3])
diags = []
for i in range(count):
    diags.append({
        "code": code,
        "severity": "INFO",
        "type": "HINT",
        "message": f"Unused import at line {i+1}.",
        "file": fpath,
        "location": {
            "file": fpath,
            "range": {
                "start": {"offset": i*10, "line": i+1, "column": 1},
                "end": {"offset": i*10+5, "line": i+1, "column": 6}
            }
        }
    })
print(json.dumps({"version": 1, "diagnostics": diags}))
PYEOF
}

# ---------------------------------------------------------------------------
# Test 1: dart missing → exit 0, no item
# ---------------------------------------------------------------------------
printf '\nTest 1: dart missing → exit 0, no item\n'
SB1="$(_new_sandbox t1)"
# No stub installed → dart not found in PATH override (use a clean PATH)
PATH="/usr/bin:/bin" \
DART_CMD="dart" \
ANALYZER_STATE_FILE="$SB1/.claude/analyzer/state/scan-dead-code.json" \
OVERSEER_INBOX_DIR="$SB1/.claude/overseer/inbox" \
CLAUDE_PROJECT_DIR="$SB1" \
bash "$MODULE" 2>/dev/null
exit_code=$?

item_count="$(find "$SB1/.claude/overseer/inbox" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "exit code 0 (dart missing)" "0" "$exit_code"
assert_eq "No item generated (dart missing)" "0" "$item_count"

# ---------------------------------------------------------------------------
# Test 2: dart returns 0 findings → no item
# ---------------------------------------------------------------------------
printf '\nTest 2: dart returns 0 findings → no item\n'
SB2="$(_new_sandbox t2)"
_install_dart_stub "$SB2"

# DART_MOCK_JSON empty → stub returns empty diagnostics
DART_MOCK_JSON='{"version":1,"diagnostics":[]}' \
_run_module "$SB2" 2>/dev/null

item_count2="$(find "$SB2/.claude/overseer/inbox" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "No item (0 findings)" "0" "$item_count2"

# ---------------------------------------------------------------------------
# Test 3: 3 unused_import in one file → 1 item generated
# ---------------------------------------------------------------------------
printf '\nTest 3: 3 unused_import in one file → 1 item generated\n'
SB3="$(_new_sandbox t3)"
_install_dart_stub "$SB3"

MOCK_FILE="$SB3/lib/foo.dart"
touch "$MOCK_FILE"

DART_MOCK_JSON="$(_make_dart_json "$MOCK_FILE" "unused_import" 3)" \
_run_module "$SB3" 2>/dev/null

item_count3="$(find "$SB3/.claude/overseer/inbox" -maxdepth 1 -name "02-analyzer-scan-dead-code-*.md" 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "1 item generated (3 unused_import)" "1" "$item_count3"

# Check item content
item3="$(find "$SB3/.claude/overseer/inbox" -maxdepth 1 -name "02-analyzer-scan-dead-code-*.md" 2>/dev/null | head -1)"
if [ -n "$item3" ]; then
  if grep -q "model: haiku" "$item3"; then
    ok "model: haiku in item"
  else
    fail "model: haiku missing in item"
  fi
  if grep -q "priority: 2" "$item3"; then
    ok "priority: 2 in item"
  else
    fail "priority: 2 missing in item"
  fi
  if grep -q "budget_usd: 1.0" "$item3"; then
    ok "budget_usd: 1.0 in item"
  else
    fail "budget_usd: 1.0 missing in item"
  fi
  if grep -q "unused_import" "$item3"; then
    ok "lint code listed in item body"
  else
    fail "lint code missing in item body"
  fi
fi

# ---------------------------------------------------------------------------
# Test 4: 5 files with >=2 findings → cap 5 items
# ---------------------------------------------------------------------------
printf '\nTest 4: 5 files with findings → max 5 items (cap)\n'
SB4="$(_new_sandbox t4)"
_install_dart_stub "$SB4"

# Build JSON with diagnostics spread over 5 files (2 each = 10 total)
MOCK_JSON="$(python3 - "$SB4" <<'PYEOF'
import sys, json
sandbox = sys.argv[1]
diags = []
for i in range(5):
    fpath = f"{sandbox}/lib/file{i}.dart"
    for j in range(2):
        diags.append({
            "code": "unused_import",
            "severity": "INFO",
            "type": "HINT",
            "message": f"Unused import.",
            "file": fpath,
            "location": {
                "file": fpath,
                "range": {
                    "start": {"offset": j*10, "line": j+1, "column": 1},
                    "end": {"offset": j*10+5, "line": j+1, "column": 6}
                }
            }
        })
print(json.dumps({"version": 1, "diagnostics": diags}))
PYEOF
)"

DART_MOCK_JSON="$MOCK_JSON" \
_run_module "$SB4" 2>/dev/null

item_count4="$(find "$SB4/.claude/overseer/inbox" -maxdepth 1 -name "02-analyzer-scan-dead-code-*.md" 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "5 items generated (5 files, cap=5)" "5" "$item_count4"

# ---------------------------------------------------------------------------
# Test 5: Re-run → dedup, no duplicate items
# ---------------------------------------------------------------------------
printf '\nTest 5: Re-run → dedup, no duplicate\n'
# Re-use SB3 (1 item already written, state saved)
DART_MOCK_JSON="$(_make_dart_json "$MOCK_FILE" "unused_import" 3)" \
_run_module "$SB3" 2>/dev/null

item_count5="$(find "$SB3/.claude/overseer/inbox" -maxdepth 1 -name "02-analyzer-scan-dead-code-*.md" 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "Still 1 item after re-run (dedup)" "1" "$item_count5"

# ---------------------------------------------------------------------------
# Test 6: 4th attempt → 7d pause
# ---------------------------------------------------------------------------
printf '\nTest 6: 4th attempt → 7d pause, no new item\n'
SB6="$(_new_sandbox t6)"
_install_dart_stub "$SB6"

PAUSE_FILE="$SB6/lib/pause_me.dart"
touch "$PAUSE_FILE"

# Pre-seed state with 3 prior attempts
hash_input="scan-dead-code${PAUSE_FILE}"
full_hash="$(printf '%s' "$hash_input" | shasum -a 256 | awk '{print $1}')"
now_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

mkdir -p "$SB6/.claude/analyzer/state"
python3 - "$SB6/.claude/analyzer/state/scan-dead-code.json" \
  "$full_hash" "$PAUSE_FILE" "$now_iso" <<'PYEOF'
import sys, json
sf, h, fpath, now = sys.argv[1:]
state = {
    "last_run": now,
    "subjects": {
        h: {
            "file": fpath,
            "first_seen": now,
            "last_attempts": [now, now, now],
            "paused_until": None
        }
    }
}
with open(sf, 'w') as f:
    json.dump(state, f, indent=2)
PYEOF

mkdir -p "$SB6/.claude/overseer/notifications"

DART_MOCK_JSON="$(_make_dart_json "$PAUSE_FILE" "unused_import" 3)" \
NOTIFY_DRY_RUN=1 \
_run_module "$SB6" 2>/dev/null

item_count6="$(find "$SB6/.claude/overseer/inbox" -maxdepth 1 -name "02-analyzer-scan-dead-code-*.md" 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "No new item on 4th attempt (paused)" "0" "$item_count6"

# Check paused_until is set
paused_until="$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    d=json.load(f)
for v in d.get('subjects',{}).values():
    print(v.get('paused_until') or '')
" "$SB6/.claude/analyzer/state/scan-dead-code.json" 2>/dev/null || echo '')"

if [ -n "$paused_until" ] && [ "$paused_until" != "None" ] && [ "$paused_until" != "null" ]; then
  ok "paused_until set: $paused_until"
else
  fail "paused_until not set (got: '$paused_until')"
fi

# ---------------------------------------------------------------------------
# Test 7: Inbox cap > 50 → SKIP
# ---------------------------------------------------------------------------
printf '\nTest 7: Inbox cap > 50 → SKIP\n'
SB7="$(_new_sandbox t7)"
_install_dart_stub "$SB7"

MOCK_FILE7="$SB7/lib/capped.dart"
touch "$MOCK_FILE7"

# Create 51 dummy inbox files
for i in $(seq 1 51); do
  touch "$SB7/.claude/overseer/inbox/dummy-${i}.md"
done

output7="$(DART_MOCK_JSON="$(_make_dart_json "$MOCK_FILE7" "unused_import" 3)" \
  _run_module "$SB7" 2>&1 || true)"

item_count7="$(find "$SB7/.claude/overseer/inbox" -maxdepth 1 -name "02-analyzer-scan-dead-code-*.md" 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "No analyzer item (inbox capped)" "0" "$item_count7"

if printf '%s' "$output7" | grep -qi "skip\|SKIP\|cap"; then
  ok "Output mentions skip/cap"
else
  fail "Output missing skip/cap message (got: $output7)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n--- scan-dead-code verify summary ---\n'
printf 'PASS: %d  FAIL: %d\n' "$_pass" "$_fail"

[ "$_fail" -gt 0 ] && exit 1
exit 0
