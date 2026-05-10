#!/usr/bin/env bash
# verify/scan-security-drift.sh — Sandbox tests for scan-security-drift analyzer module.
#
# Usage: bash .claude/scripts/verify/scan-security-drift.sh
# Exit 0 = all pass, exit 1 = one or more failures.
#
# Isolation: all tests run in a mktemp sandbox with mock git repos.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
MODULE="$REPO_ROOT/.claude/analyzer/modules/scan-security-drift.sh"

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

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  if printf '%s' "$haystack" | grep -q "$needle"; then
    ok "$label (found: $needle)"
  else
    fail "$label (missing: '$needle' in output)"
  fi
}

# ---------------------------------------------------------------------------
# Sandbox setup helpers
# ---------------------------------------------------------------------------
TMPBASE="$(mktemp -d /tmp/verify-scan-security-drift.XXXXXX)"
_cleanup() {
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

  # Add a root commit so origin/main can be set up
  touch "$sandbox/.gitkeep"
  git -C "$sandbox" add .gitkeep
  git -C "$sandbox" commit -q --no-verify -m "init"

  # Fake origin/main = current HEAD (baseline — changes go on top)
  git -C "$sandbox" branch -M main 2>/dev/null || true
  # Add remote pointing to itself (the diff uses origin/main...HEAD)
  git -C "$sandbox" remote add origin "$sandbox" 2>/dev/null || true
  git -C "$sandbox" fetch -q origin 2>/dev/null || true

  # Create required dirs
  mkdir -p "$sandbox/.claude/scripts/lib"
  mkdir -p "$sandbox/.claude/overseer/inbox"
  mkdir -p "$sandbox/.claude/analyzer/state"
  mkdir -p "$sandbox/supabase/migrations"
  mkdir -p "$sandbox/supabase/functions"

  # Copy audit.sh if present
  [ -f "$REPO_ROOT/.claude/scripts/lib/audit.sh" ] && \
    cp "$REPO_ROOT/.claude/scripts/lib/audit.sh" \
       "$sandbox/.claude/scripts/lib/audit.sh"

  # Stub notify.sh
  mkdir -p "$sandbox/.claude/scripts"
  cat > "$sandbox/.claude/scripts/notify.sh" <<'STUB'
#!/usr/bin/env bash
_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ROOT="$(cd "$_DIR/../.." && pwd)"
SENT_DIR="$_ROOT/.claude/overseer/notifications"
mkdir -p "$SENT_DIR"
printf '{"severity":"%s","topic":"%s","title":"%s","body":"%s"}\n' \
  "${1:-}" "${2:-}" "${3:-}" "${4:-}" >> "$SENT_DIR/sent.jsonl"
STUB
  chmod +x "$sandbox/.claude/scripts/notify.sh"

  printf '%s' "$sandbox"
}

# Add a file to the sandbox as an uncommitted change visible in git diff
_add_migration() {
  local sandbox="$1" filename="$2" content="$3"
  local path="$sandbox/supabase/migrations/$filename"
  printf '%s\n' "$content" > "$path"
  git -C "$sandbox" add "supabase/migrations/$filename"
  git -C "$sandbox" commit -q --no-verify -m "add migration $filename"
}

_add_function() {
  local sandbox="$1" funcname="$2" content="$3"
  local dir="$sandbox/supabase/functions/$funcname"
  mkdir -p "$dir"
  printf '%s\n' "$content" > "$dir/index.ts"
  git -C "$sandbox" add "supabase/functions/$funcname/index.ts"
  git -C "$sandbox" commit -q --no-verify -m "add function $funcname"
}

# Run module in sandbox
_run_module() {
  local sandbox="$1"
  shift
  ANALYZER_STATE_FILE="$sandbox/.claude/analyzer/state/scan-security-drift.json" \
  OVERSEER_INBOX_DIR="$sandbox/.claude/overseer/inbox" \
  CLAUDE_PROJECT_DIR="$sandbox" \
  bash "$MODULE" "$@"
}

# ---------------------------------------------------------------------------
# Test 1: Migration without RLS → 1 item, needs_dispute: true
# ---------------------------------------------------------------------------
printf '\nTest 1: Migration without RLS → 1 item, needs_dispute: true\n'
SB1="$(_new_sandbox t1)"
_add_migration "$SB1" "20260101000000_create_foo.sql" \
  "CREATE TABLE foo (id uuid PRIMARY KEY, name text);"

_run_module "$SB1" 2>/dev/null

item_count1="$(find "$SB1/.claude/overseer/inbox" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "Test1: 1 item generated" "1" "$item_count1"

item_file1="$(find "$SB1/.claude/overseer/inbox" -maxdepth 1 -name "*.md" | head -1)"
if [ -n "$item_file1" ]; then
  content1="$(cat "$item_file1")"
  assert_contains "Test1: needs_dispute: true" "needs_dispute: true" "$content1"
  assert_contains "Test1: priority: 0" "priority: 0" "$content1"
  assert_contains "Test1: model: opus" "model: opus" "$content1"
  assert_contains "Test1: source: tier-3" "source: tier-3" "$content1"
else
  fail "Test1: no item file found"
fi

# ---------------------------------------------------------------------------
# Test 2: Migration with RLS → 0 items
# ---------------------------------------------------------------------------
printf '\nTest 2: Migration with RLS → 0 items\n'
SB2="$(_new_sandbox t2)"
_add_migration "$SB2" "20260101000000_create_bar.sql" \
  "CREATE TABLE bar (id uuid PRIMARY KEY);
ALTER TABLE bar ENABLE ROW LEVEL SECURITY;
CREATE POLICY bar_select ON bar FOR SELECT USING (true);"

_run_module "$SB2" 2>/dev/null

item_count2="$(find "$SB2/.claude/overseer/inbox" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "Test2: 0 items (RLS present)" "0" "$item_count2"

# ---------------------------------------------------------------------------
# Test 3: Edge Function without Auth → 1 item
# ---------------------------------------------------------------------------
printf '\nTest 3: Edge Function without Auth → 1 item\n'
SB3="$(_new_sandbox t3)"
_add_function "$SB3" "my-func" \
  "import { serve } from 'https://deno.land/std/http/server.ts'

const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

Deno.serve(async (req) => {
  return new Response(JSON.stringify({ ok: true }), { status: 200 })
})"

_run_module "$SB3" 2>/dev/null

item_count3="$(find "$SB3/.claude/overseer/inbox" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "Test3: 1 item (fn no auth)" "1" "$item_count3"

item_file3="$(find "$SB3/.claude/overseer/inbox" -maxdepth 1 -name "*.md" | head -1)"
if [ -n "$item_file3" ]; then
  content3="$(cat "$item_file3")"
  assert_contains "Test3: needs_dispute: true" "needs_dispute: true" "$content3"
else
  fail "Test3: no item file found"
fi

# ---------------------------------------------------------------------------
# Test 4: Edge Function with Auth → 0 items
# ---------------------------------------------------------------------------
printf '\nTest 4: Edge Function with Auth → 0 items\n'
SB4="$(_new_sandbox t4)"
_add_function "$SB4" "safe-func" \
  "const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

Deno.serve(async (req) => {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return new Response('Unauthorized', { status: 401 })
  }
  return new Response(JSON.stringify({ ok: true }), { status: 200 })
})"

_run_module "$SB4" 2>/dev/null

item_count4="$(find "$SB4/.claude/overseer/inbox" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "Test4: 0 items (auth present)" "0" "$item_count4"

# ---------------------------------------------------------------------------
# Test 5: Re-run → dedup, no duplicate
# ---------------------------------------------------------------------------
printf '\nTest 5: Re-run → dedup, no duplicate\n'
# Re-use SB1 (1 item already generated)
_run_module "$SB1" 2>/dev/null

item_count5="$(find "$SB1/.claude/overseer/inbox" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "Test5: Still 1 item (dedup)" "1" "$item_count5"

# ---------------------------------------------------------------------------
# Test 6: Cap 3 — mock 5 unsafe migrations → max 3 items
# ---------------------------------------------------------------------------
printf '\nTest 6: Cap 3 — 5 unsafe migrations → max 3 items\n'
SB6="$(_new_sandbox t6)"
for i in $(seq 1 5); do
  _add_migration "$SB6" "2026010${i}000000_table${i}.sql" \
    "CREATE TABLE unsafe_table_${i} (id uuid PRIMARY KEY, data text);"
done

_run_module "$SB6" 2>/dev/null

item_count6="$(find "$SB6/.claude/overseer/inbox" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "Test6: Max 3 items (cap)" "3" "$item_count6"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n--- scan-security-drift verify summary ---\n'
printf 'PASS: %d  FAIL: %d\n' "$_pass" "$_fail"

[ "$_fail" -gt 0 ] && exit 1
exit 0
