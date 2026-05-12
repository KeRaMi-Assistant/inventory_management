#!/usr/bin/env bash
# verify/yota.sh — Tests für Yota (Snapshot, Agent, Watch, Plist).
#
# Exit 0 wenn alle 8 Checks PASS, sonst 1.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

SNAP="$REPO_ROOT/.claude/scripts/yota-snapshot.sh"
WATCH="$REPO_ROOT/.claude/scripts/yota-watch.sh"
AGENT="$REPO_ROOT/.claude/agents/yota.md"
PLIST="$REPO_ROOT/.claude/yota-watch-launchagent.plist.template"

_pass() { printf '\033[32mPASS\033[0m %s\n' "$1"; }
_fail() { printf '\033[31mFAIL\033[0m %s — %s\n' "$1" "$2"; FAILURES=$((FAILURES+1)); }

FAILURES=0
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

# Sandbox-State
mkdir -p "$SANDBOX/overseer/state/workers" \
         "$SANDBOX/overseer/inbox" "$SANDBOX/overseer/done" "$SANDBOX/overseer/failed" \
         "$SANDBOX/stakeholder/inbox" \
         "$SANDBOX/backlog/inbox" \
         "$SANDBOX/disputes/d1" \
         "$SANDBOX/audit/briefings"

# Mock health.json
cat > "$SANDBOX/overseer/health.json" <<'EOF'
{"ts":"2026-05-12T00:00:00Z","panic":false,"checks":{}}
EOF

# Mock worker pid (use $$ which is alive)
cat > "$SANDBOX/overseer/state/workers/$$.pid" <<EOF
{"pid":$$,"slug":"mock-worker","started":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","item_path":"$SANDBOX/overseer/inbox/01-mock.md"}
EOF

# Mock items
touch "$SANDBOX/stakeholder/inbox/01-stk.md"
touch "$SANDBOX/overseer/inbox/02-backlog-a.md"
touch "$SANDBOX/overseer/inbox/03-backlog-b.md"
touch "$SANDBOX/overseer/done/01-done-x.md"
touch "$SANDBOX/disputes/d1/verdict.md"
touch "$SANDBOX/audit/briefings/2026-05-12.md"

# Mock cost ledger
TODAY="$(date -u +%Y-%m-%d)"
cat > "$SANDBOX/overseer/cost-ledger.jsonl" <<EOF
{"ts":"${TODAY}T08:00:00Z","agent":"worker","usd":1.50}
{"ts":"${TODAY}T09:00:00Z","agent":"analyzer","usd":0.75}
EOF

run_snap_sandbox() {
  OVERSEER_DIR="$SANDBOX/overseer" \
  STAKEHOLDER_DIR="$SANDBOX/stakeholder" \
  BACKLOG_DIR="$SANDBOX/backlog" \
  DISPUTES_DIR="$SANDBOX/disputes" \
  AUDIT_DIR="$SANDBOX/audit" \
  BRIEFING_DIR="$SANDBOX/audit/briefings" \
  bash "$SNAP" "$@"
}

# Check 1: yota-snapshot.sh produces valid JSON
out="$(run_snap_sandbox 2>/dev/null)"
if printf '%s' "$out" | python3 -c 'import json,sys; json.loads(sys.stdin.read())' 2>/dev/null; then
  _pass "1. yota-snapshot.sh emits valid JSON"
else
  _fail "1. yota-snapshot.sh emits valid JSON" "JSON parse error"
fi

# Check 2: Sandbox-Mock-State → correct counts
JSON_TMP="$SANDBOX/snap.json"
printf '%s' "$out" > "$JSON_TMP"
counts_ok="$(YOTA_JSON_FILE="$JSON_TMP" python3 <<'PYEOF'
import json, os
with open(os.environ['YOTA_JSON_FILE']) as f:
    s = json.load(f)
errs = []
if s['workers']['active'] != 1: errs.append(f"workers.active={s['workers']['active']} expected 1")
if s['inbox']['stakeholder'] != 1: errs.append(f"inbox.stakeholder={s['inbox']['stakeholder']} expected 1")
if s['inbox']['backlog'] != 2: errs.append(f"inbox.backlog={s['inbox']['backlog']} expected 2")
if s['inbox']['done_today'] != 1: errs.append(f"done_today={s['inbox']['done_today']} expected 1")
if abs(s['cost']['today_usd'] - 2.25) > 0.01: errs.append(f"cost.today={s['cost']['today_usd']} expected 2.25")
if s['disputes']['decided_today'] != 1: errs.append(f"disputes.decided={s['disputes']['decided_today']} expected 1")
print('OK' if not errs else '|'.join(errs))
PYEOF
)"
if [ "$counts_ok" = "OK" ]; then
  _pass "2. Sandbox-state → correct counts"
else
  _fail "2. Sandbox-state → correct counts" "$counts_ok"
fi

# Check 3: --human mode produces Markdown sections
hout="$(run_snap_sandbox --human 2>/dev/null)"
if printf '%s' "$hout" | grep -q '\*\*Status:\*\*' \
   && printf '%s' "$hout" | grep -q '\*\*Inbox:\*\*' \
   && printf '%s' "$hout" | grep -q '\*\*Heute:\*\*'; then
  _pass "3. --human mode emits Markdown sections"
else
  _fail "3. --human mode emits Markdown sections" "missing sections; got: $(printf '%s' "$hout" | head -3 | tr '\n' '|')"
fi

# Check 4: Agent frontmatter
if [ -f "$AGENT" ]; then
  if grep -qE '^model:[[:space:]]*sonnet' "$AGENT" \
     && grep -qE '^tools:[[:space:]]*Read,[[:space:]]*Glob,[[:space:]]*Grep,[[:space:]]*Bash' "$AGENT" \
     && ! grep -qE '^tools:.*\b(Edit|Write)\b' "$AGENT"; then
    _pass "4. Agent frontmatter: model=sonnet, tools=Read,Glob,Grep,Bash (no Edit/Write)"
  else
    _fail "4. Agent frontmatter" "wrong model/tools"
  fi
else
  _fail "4. Agent frontmatter" "$AGENT missing"
fi

# Check 5: Few-Shot examples (≥3)
fs_count="$(grep -cE '^### Beispiel ' "$AGENT" 2>/dev/null || echo 0)"
if [ "$fs_count" -ge 3 ]; then
  _pass "5. Few-Shot-Examples present ($fs_count)"
else
  _fail "5. Few-Shot-Examples present" "found $fs_count, need ≥3"
fi

# Check 6: yota-watch.sh --once + NOTIFY_DRY_RUN
WATCH_OUT="$(NOTIFY_DRY_RUN=1 bash "$WATCH" --dry-run 2>&1 || true)"
if printf '%s' "$WATCH_OUT" | grep -qE '^DRY-RUN: '; then
  _pass "6. yota-watch --dry-run emits summary"
else
  _fail "6. yota-watch --dry-run" "no DRY-RUN line; got: $(printf '%s' "$WATCH_OUT" | head -2)"
fi

# Check 7: Plist valid (plutil -lint requires a real plist, we render then lint)
RENDERED="$SANDBOX/yota-watch.plist"
sed -e "s|__REPO_ROOT__|$REPO_ROOT|g" -e "s|__HOME__|$HOME|g" "$PLIST" > "$RENDERED"
if plutil -lint "$RENDERED" >/dev/null 2>&1; then
  _pass "7. Plist template renders to valid plist (plutil -lint)"
else
  _fail "7. Plist plutil -lint" "$(plutil -lint "$RENDERED" 2>&1 | head -2)"
fi

# Check 8: snapshot.sh executes in <5s
T0="$(date +%s)"
run_snap_sandbox >/dev/null 2>&1
T1="$(date +%s)"
ELAPSED=$((T1 - T0))
if [ "$ELAPSED" -lt 5 ]; then
  _pass "8. yota-snapshot.sh fast (<5s, took ${ELAPSED}s)"
else
  _fail "8. yota-snapshot.sh fast" "took ${ELAPSED}s"
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  printf '\033[32mAll 8/8 checks PASS\033[0m\n'
  exit 0
else
  printf '\033[31m%d FAILURES\033[0m\n' "$FAILURES"
  exit 1
fi
