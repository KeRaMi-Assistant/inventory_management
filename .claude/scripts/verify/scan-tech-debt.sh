#!/usr/bin/env bash
# verify/scan-tech-debt.sh — Sandbox tests for scan-tech-debt analyzer module.
#
# Usage: bash .claude/scripts/verify/scan-tech-debt.sh
# Exit 0 = all pass, exit 1 = one or more failures.
#
# Isolation: all tests run in a mktemp sandbox with a fresh git repo.
# GIT_COMMITTER_DATE / GIT_AUTHOR_DATE used to back-date commits.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
MODULE="$REPO_ROOT/.claude/analyzer/modules/scan-tech-debt.sh"

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

assert_file_exists() {
  if [ -f "$1" ]; then
    ok "File exists: $1"
  else
    fail "File missing: $1"
  fi
}

assert_file_not_exists() {
  if [ ! -f "$1" ]; then
    ok "File absent (expected): $1"
  else
    fail "File should not exist: $1"
  fi
}

# ---------------------------------------------------------------------------
# Sandbox setup helpers
# ---------------------------------------------------------------------------
TMPBASE="$(mktemp -d /tmp/verify-scan-tech-debt.XXXXXX)"
_cleanup() {
  # audit.sh sets 0444 + uchg on audit files — lift that before rm
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

  # Init git repo
  git -C "$sandbox" init -q
  git -C "$sandbox" config user.email "test@test.com"
  git -C "$sandbox" config user.name "Test"

  # Mirror required scripts into sandbox
  mkdir -p "$sandbox/.claude/scripts/lib"
  mkdir -p "$sandbox/.claude/scripts/verify"
  mkdir -p "$sandbox/.claude/overseer/inbox"
  mkdir -p "$sandbox/.claude/analyzer/state"
  mkdir -p "$sandbox/.claude/audit"
  mkdir -p "$sandbox/lib"

  # Copy audit.sh (for audit_record calls inside module)
  [ -f "$REPO_ROOT/.claude/scripts/lib/audit.sh" ] && \
    cp "$REPO_ROOT/.claude/scripts/lib/audit.sh" \
       "$sandbox/.claude/scripts/lib/audit.sh"

  # Provide a stub notify.sh that respects NOTIFY_DRY_RUN
  mkdir -p "$sandbox/.claude/scripts"
  cat > "$sandbox/.claude/scripts/notify.sh" <<'STUB'
#!/usr/bin/env bash
# Stub: always logs to sent.jsonl (NOTIFY_DRY_RUN behaviour simulated)
# Path: .claude/scripts/notify.sh → ../.. is project root → .claude/overseer/notifications
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

# Commit a file with a specific date offset (negative = days in the past)
_commit_file_dated() {
  local sandbox="$1"
  local relpath="$2"   # relative to sandbox
  local content="$3"
  local days_ago="$4"

  mkdir -p "$sandbox/$(dirname "$relpath")"
  printf '%s\n' "$content" > "$sandbox/$relpath"

  # Compute past date
  local past_date
  if date -v "-${days_ago}d" +%Y-%m-%dT%H:%M:%S 2>/dev/null; then
    past_date="$(date -v "-${days_ago}d" +%Y-%m-%dT%H:%M:%S) +0000"
  else
    past_date="$(date -u -d "-${days_ago} days" +%Y-%m-%dT%H:%M:%S) +0000"
  fi

  GIT_AUTHOR_DATE="$past_date" GIT_COMMITTER_DATE="$past_date" \
    git -C "$sandbox" add "$relpath" 2>/dev/null
  GIT_AUTHOR_DATE="$past_date" GIT_COMMITTER_DATE="$past_date" \
    git -C "$sandbox" commit -q --no-verify \
    --author="Test <test@test.com>" \
    -m "add $relpath" 2>/dev/null
}

# Run module inside a sandbox (overrides REPO_ROOT-equivalent paths via env vars)
_run_module() {
  local sandbox="$1"
  shift
  ANALYZER_STATE_FILE="$sandbox/.claude/analyzer/state/scan-tech-debt.json" \
  OVERSEER_INBOX_DIR="$sandbox/.claude/overseer/inbox" \
  CLAUDE_PROJECT_DIR="$sandbox" \
  bash "$MODULE" "$@"
}

# ---------------------------------------------------------------------------
# Test 1: Old TODO → 1 item generated
# ---------------------------------------------------------------------------
printf '\nTest 1: Old TODO (>30 days) → 1 item generated\n'
SB="$(_new_sandbox t1)"
_commit_file_dated "$SB" "lib/foo.dart" \
  $'// TODO old comment\nvoid main() {}\n' 40

_run_module "$SB" 2>/dev/null

item_count="$(find "$SB/.claude/overseer/inbox" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "1 item generated" "1" "$item_count"

# ---------------------------------------------------------------------------
# Test 2: Re-run → no duplicate
# ---------------------------------------------------------------------------
printf '\nTest 2: Re-run → no duplicate\n'
# Run again on same sandbox
_run_module "$SB" 2>/dev/null

item_count2="$(find "$SB/.claude/overseer/inbox" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "Still 1 item (dedup)" "1" "$item_count2"

# ---------------------------------------------------------------------------
# Test 3: 4th attempt → subject paused 7 days + notification
# ---------------------------------------------------------------------------
printf '\nTest 3: 4th attempt → 7-day pause + notification\n'
SB3="$(_new_sandbox t3)"
_commit_file_dated "$SB3" "lib/bar.dart" \
  $'// FIXME repeated failure\nvoid bar() {}\n' 50

# Pre-seed state.json with 3 prior attempts (all within last 30 days)
hash_input="$SB3/lib/bar.dart""scan-tech-debt"
full_hash="$(printf '%s' "$hash_input" | shasum -a 256 | awk '{print $1}')"

now_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
mkdir -p "$SB3/.claude/analyzer/state"
python3 - "$SB3/.claude/analyzer/state/scan-tech-debt.json" \
  "$full_hash" "$SB3/lib/bar.dart" "$now_iso" <<'PYEOF'
import sys, json, datetime

sf, h, fpath, now = sys.argv[1:]
three_attempts = [now, now, now]
state = {
    "last_run": now,
    "subjects": {
        h: {
            "file": fpath,
            "first_seen": now,
            "last_attempts": three_attempts,
            "paused_until": None
        }
    }
}
with open(sf, 'w') as f:
    json.dump(state, f, indent=2)
PYEOF

mkdir -p "$SB3/.claude/overseer/notifications"

NOTIFY_DRY_RUN=1 _run_module "$SB3" 2>/dev/null

# Should NOT create new item (subject should be paused instead)
item_count3="$(find "$SB3/.claude/overseer/inbox" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "No new item (paused)" "0" "$item_count3"

# paused_until should be set in state
paused_until="$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    d=json.load(f)
subjects=d.get('subjects',{})
for v in subjects.values():
    print(v.get('paused_until') or '')
" "$SB3/.claude/analyzer/state/scan-tech-debt.json" 2>/dev/null || echo '')"

if [ -n "$paused_until" ] && [ "$paused_until" != "None" ] && [ "$paused_until" != "null" ]; then
  ok "paused_until set in state: $paused_until"
else
  fail "paused_until not set in state (got: '$paused_until')"
fi

# Notification sent (NOTIFY_DRY_RUN=1 → sent.jsonl)
notif_count="$(wc -l < "$SB3/.claude/overseer/notifications/sent.jsonl" 2>/dev/null | tr -d ' ' || echo 0)"
if [ "$notif_count" -ge 1 ]; then
  ok "Notification sent (sent.jsonl has $notif_count entry/entries)"
else
  fail "No notification found in sent.jsonl"
fi

# ---------------------------------------------------------------------------
# Test 4: Inbox cap > 50 → SKIP
# ---------------------------------------------------------------------------
printf '\nTest 4: Inbox cap (>50 files) → skip\n'
SB4="$(_new_sandbox t4)"
_commit_file_dated "$SB4" "lib/baz.dart" \
  $'// XXX skip me\nvoid baz() {}\n' 60

# Create 51 dummy inbox files
for i in $(seq 1 51); do
  touch "$SB4/.claude/overseer/inbox/dummy-${i}.md"
done

output="$(_run_module "$SB4" 2>&1 || true)"
item_count4="$(find "$SB4/.claude/overseer/inbox" -maxdepth 1 -name "02-analyzer-*.md" 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "No analyzer item created (inbox cap)" "0" "$item_count4"

if printf '%s' "$output" | grep -qi "skip\|SKIP\|cap"; then
  ok "Output mentions skip/cap"
else
  fail "Output missing skip/cap message (got: $output)"
fi

# ---------------------------------------------------------------------------
# Test 5: Item frontmatter has required fields
# ---------------------------------------------------------------------------
printf '\nTest 5: Item frontmatter has source:tier-3, touches, budget_usd\n'
SB5="$(_new_sandbox t5)"
_commit_file_dated "$SB5" "lib/widget.dart" \
  $'// HACK temporary workaround\nclass W {}\n' 35

_run_module "$SB5" 2>/dev/null

item_file5="$(find "$SB5/.claude/overseer/inbox" -maxdepth 1 -name "02-analyzer-*.md" 2>/dev/null | head -1)"
if [ -z "$item_file5" ]; then
  fail "No item file found (test 5 setup)"
else
  ok "Item file exists: $(basename "$item_file5")"
  content="$(cat "$item_file5")"

  if printf '%s' "$content" | grep -q "source: tier-3"; then
    ok "source: tier-3 present"
  else
    fail "source: tier-3 missing"
  fi

  if printf '%s' "$content" | grep -q "touches:"; then
    ok "touches: field present"
  else
    fail "touches: field missing"
  fi

  if printf '%s' "$content" | grep -q "budget_usd:"; then
    ok "budget_usd: field present"
  else
    fail "budget_usd: field missing"
  fi

  if printf '%s' "$content" | grep -q "trust_tier: 3"; then
    ok "trust_tier: 3 present"
  else
    fail "trust_tier: 3 missing"
  fi
fi

# ---------------------------------------------------------------------------
# Test 6: --dry-run → no file written, stdout shows planned items
# ---------------------------------------------------------------------------
printf '\nTest 6: --dry-run → no file written, stdout shows plan\n'
SB6="$(_new_sandbox t6)"
_commit_file_dated "$SB6" "lib/dry.dart" \
  $'// TODO dry run test\nvoid dry() {}\n' 45

stdout_out="$(_run_module "$SB6" --dry-run 2>/dev/null)"
item_count6="$(find "$SB6/.claude/overseer/inbox" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "No item written in dry-run" "0" "$item_count6"

if printf '%s' "$stdout_out" | grep -qi "dry-run\|dry_run\|Would generate"; then
  ok "stdout mentions dry-run plan"
else
  fail "stdout missing dry-run message (got: $stdout_out)"
fi

# ---------------------------------------------------------------------------
# Test 7: Cap 5 items — 10 TODOs → max 5 items, oldest first
# ---------------------------------------------------------------------------
printf '\nTest 7: Cap 5 items — 10 old TODOs → max 5 items generated\n'
SB7="$(_new_sandbox t7)"

# Create 10 files with TODO, committed at different ages (oldest = 100 days)
for i in $(seq 1 10); do
  age=$(( 30 + i * 5 ))   # ages: 35,40,45,...,80 days
  _commit_file_dated "$SB7" "lib/file${i}.dart" \
    "// TODO item number ${i}
void fn${i}() {}" "$age"
done

_run_module "$SB7" 2>/dev/null

item_count7="$(find "$SB7/.claude/overseer/inbox" -maxdepth 1 -name "02-analyzer-*.md" 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "Max 5 items (cap)" "5" "$item_count7"

# Oldest items should be present: files 10,9,8,7,6 (ages 80,75,70,65,60 days)
oldest_file="$(find "$SB7/.claude/overseer/inbox" -name "*.md" -exec grep -l "file10\|file9\|file8" {} \; | wc -l | tr -d ' ')"
if [ "$oldest_file" -ge 1 ]; then
  ok "Oldest TODO items are included in generated items"
else
  fail "Oldest TODO items not found in generated items"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n--- scan-tech-debt verify summary ---\n'
printf 'PASS: %d  FAIL: %d\n' "$_pass" "$_fail"

[ "$_fail" -gt 0 ] && exit 1
exit 0
