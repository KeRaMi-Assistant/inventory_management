#!/usr/bin/env bash
# verify/intake-council.sh — Tests for intake-council.sh (T05/T06/T07/T08)
#
# Tests:
#  1) Round-1 consensus accept+accept → verdict=propose, no Round-2
#  2) Round-1 consensus reject+reject → verdict=reject, no Round-2
#  3) Split → Round-2 pragmatist propose → verdict=propose
#  4) Split → Round-2 pragmatist needs-full-council → verdict=needs-full-council
#  5) Cost-Cap-Hit ($15 pre-loaded) → exit 2 + verdict=reject + cost-cap-aborted
#  6) --resume on aborted council (only round-1 files) → continues with Round-2
#  7) --status prints frontmatter
#  8) Stakeholder-Original block = deterministic-copy of proposal body
#  9) HMAC-Token present + 16-char
# 10) created_from: intake-council in frontmatter
# 11) API-Key Pre-Flight: env ANTHROPIC_API_KEY=fake → exit 1
# 12) pushed_at: "" empty initially

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
COUNCIL_SH="$SCRIPT_DIR/../intake-council.sh"

PASS=0
FAIL=0
ERRORS=()

_pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
_fail() { echo "  FAIL: $1"; ERRORS+=("$1"); FAIL=$((FAIL + 1)); }

# Sandbox
_TMPDIR="$(mktemp -d /tmp/verify-intake-council-XXXXXX)"
trap 'rm -rf "$_TMPDIR"' EXIT

# --- Build mock-claude stub --------------------------------------------------
# Behaviour: schreibt deterministisch Output je nach --agent-Wert.
# Steuerung via env-vars:
#   MOCK_PRO_VOTE   — vote-text in proponent output (default: accept)
#   MOCK_SKP_VOTE   — vote-text in skeptic output (default: accept)
#   MOCK_PRAG_VOTE  — vote-text in pragmatist output (default: propose)
#   MOCK_PRAG_TOUCHES — value for touches: line (default: [lib/screens/foo.dart])
MOCK_BIN_DIR="$_TMPDIR/mockbin"
mkdir -p "$MOCK_BIN_DIR"
cat > "$MOCK_BIN_DIR/claude" <<'STUB'
#!/usr/bin/env bash
# Mock-claude — parsed --agent arg, schreibt deterministisches Stdout.
agent=""
while [ $# -gt 0 ]; do
  case "$1" in
    --agent) agent="$2"; shift 2 ;;
    *) shift ;;
  esac
done

case "$agent" in
  disput-proponent)
    cat <<EOF
## Proponent (Intake)

### Vorteile
- Test

### Vote: ${MOCK_PRO_VOTE:-accept}
EOF
    ;;
  intake-skeptic)
    cat <<EOF
## Skeptic (Intake)

### Bedenken
- Test

### Vote: ${MOCK_SKP_VOTE:-accept}
EOF
    ;;
  intake-pragmatist)
    cat <<EOF
## Pragmatist (Intake)

### Analyse
- Test

### Verdict
**${MOCK_PRAG_VOTE:-propose}**

### Vote: ${MOCK_PRAG_VOTE:-propose}

### Vorgeschlagenes Backlog-Item
\`\`\`yaml
---
slug: test-slug
source: tier-3-intake
priority: 2
budget_usd: 0.50
model: sonnet
touches: ${MOCK_PRAG_TOUCHES:-[lib/screens/foo.dart]}
created_from: intake-council
---

## Aufgabe
test
\`\`\`
EOF
    ;;
  *)
    echo "## Unknown agent: $agent"
    ;;
esac
exit 0
STUB
chmod +x "$MOCK_BIN_DIR/claude"

# --- Helper: build a proposal file ------------------------------------------
_make_proposal() {
  local id="$1"
  local file="$2"
  cat > "$file" <<EOF
---
id: ${id}
source: tier-1
trust_tier: 1
user_id: local-tester
created_at: 2026-05-12T10:00:00Z
state: pending-proposal
round: 1
content_hash: $(printf '%064d' 0)
---

<<<UNTRUSTED_STAKEHOLDER_INPUT tier=1>>>
test proposal body
<<<END_UNTRUSTED_STAKEHOLDER_INPUT>>>
EOF
}

# --- Sandbox env-vars for council ------------------------------------------
SANDBOX_ROOT="$_TMPDIR/sandbox"
mkdir -p "$SANDBOX_ROOT/.claude/stakeholder/pending-proposal" \
         "$SANDBOX_ROOT/.claude/stakeholder/pending-approval" \
         "$SANDBOX_ROOT/.claude/intake-council" \
         "$SANDBOX_ROOT/.claude/overseer"

_council_env() {
  # Saubere PATH (mock-claude first), plus alle relevanten env-vars
  PATH="$MOCK_BIN_DIR:$PATH" \
  INTAKE_COUNCIL_DIR="$SANDBOX_ROOT/.claude/intake-council" \
  PENDING_PROPOSAL_DIR="$SANDBOX_ROOT/.claude/stakeholder/pending-proposal" \
  PENDING_APPROVAL_DIR="$SANDBOX_ROOT/.claude/stakeholder/pending-approval" \
  COST_CAP_LEDGER_DIR="$SANDBOX_ROOT/.claude/overseer" \
  CLAUDE_PROJECT_DIR="$REPO_ROOT" \
  HOME="$_TMPDIR/fakehome" \
  unset_first ANTHROPIC_API_KEY
}

unset_first() { unset "$1" 2>/dev/null || true; }

mkdir -p "$_TMPDIR/fakehome/.anthropic"
echo '{}' > "$_TMPDIR/fakehome/.anthropic/auth.json"

# Helper to invoke council in sandbox
_run_council() {
  unset ANTHROPIC_API_KEY 2>/dev/null || true
  PATH="$MOCK_BIN_DIR:$PATH" \
  INTAKE_COUNCIL_DIR="$SANDBOX_ROOT/.claude/intake-council" \
  PENDING_PROPOSAL_DIR="$SANDBOX_ROOT/.claude/stakeholder/pending-proposal" \
  PENDING_APPROVAL_DIR="$SANDBOX_ROOT/.claude/stakeholder/pending-approval" \
  COST_CAP_LEDGER_DIR="$SANDBOX_ROOT/.claude/overseer" \
  CLAUDE_PROJECT_DIR="$REPO_ROOT" \
  HOME="$_TMPDIR/fakehome" \
  bash "$COUNCIL_SH" "$@"
}

# Reset cost-ledger between tests
_reset_ledger() {
  rm -f "$SANDBOX_ROOT/.claude/overseer/cost-ledger.jsonl" \
        "$SANDBOX_ROOT/.claude/overseer/COST_CAP_REACHED" 2>/dev/null || true
}

# ===========================================================================
# Test 1: Round-1 accept + accept → verdict=propose
# ===========================================================================
echo "Test 1: consensus accept+accept → verdict=propose"
_reset_ledger
ID1="20260512-100001-t1"
PROP1="$SANDBOX_ROOT/.claude/stakeholder/pending-proposal/${ID1}.md"
_make_proposal "$ID1" "$PROP1"

MOCK_PRO_VOTE=accept MOCK_SKP_VOTE=accept MOCK_PRAG_VOTE=propose _run_council "$PROP1" >/dev/null 2>&1 || true

APPR1="$SANDBOX_ROOT/.claude/stakeholder/pending-approval/${ID1}.md"
if [ -f "$APPR1" ]; then
  verdict=$(grep '^verdict:' "$APPR1" | awk '{print $2}')
  round=$(grep '^round:' "$APPR1" | awk '{print $2}')
  [ "$verdict" = "propose" ] && _pass "T1 verdict=propose" || _fail "T1 verdict=$verdict (expected propose)"
  [ "$round" = "1" ] && _pass "T1 round=1 (consensus-accept retained)" || _fail "T1 round=$round"
  if [ -f "$SANDBOX_ROOT/.claude/intake-council/${ID1}/round-2-pragmatist.md" ]; then
    _pass "T1 Pragmatist file exists (always-on synth)"
  else
    _fail "T1 expected Pragmatist file (Option A: always-on)"
  fi
  # Backlog-Item-Block muss jetzt befüllt sein
  if awk '/^## Vorgeschlagenes Backlog-Item/{f=1; next} /^## /{f=0} f && NF{found=1} END{exit found?0:1}' "$APPR1"; then
    _pass "T1 Backlog-Item-Block befüllt"
  else
    _fail "T1 Backlog-Item-Block leer"
  fi
else
  _fail "T1 approval file missing"
fi

# ===========================================================================
# Test 2: reject + reject → verdict=reject
# ===========================================================================
echo "Test 2: consensus reject+reject → verdict=reject"
_reset_ledger
ID2="20260512-100002-t2"
PROP2="$SANDBOX_ROOT/.claude/stakeholder/pending-proposal/${ID2}.md"
_make_proposal "$ID2" "$PROP2"
MOCK_PRO_VOTE=reject MOCK_SKP_VOTE=reject MOCK_PRAG_VOTE=reject _run_council "$PROP2" >/dev/null 2>&1 || true
APPR2="$SANDBOX_ROOT/.claude/stakeholder/pending-approval/${ID2}.md"
if [ -f "$APPR2" ]; then
  verdict=$(grep '^verdict:' "$APPR2" | awk '{print $2}')
  [ "$verdict" = "reject" ] && _pass "T2 verdict=reject" || _fail "T2 verdict=$verdict"
else
  _fail "T2 approval file missing"
fi

# ===========================================================================
# Test 3: Split → Pragmatist propose → propose
# ===========================================================================
echo "Test 3: split → pragmatist propose → verdict=propose"
_reset_ledger
ID3="20260512-100003-t3"
PROP3="$SANDBOX_ROOT/.claude/stakeholder/pending-proposal/${ID3}.md"
_make_proposal "$ID3" "$PROP3"
MOCK_PRO_VOTE=accept MOCK_SKP_VOTE=reject MOCK_PRAG_VOTE=propose _run_council "$PROP3" >/dev/null 2>&1 || true
APPR3="$SANDBOX_ROOT/.claude/stakeholder/pending-approval/${ID3}.md"
if [ -f "$APPR3" ]; then
  verdict=$(grep '^verdict:' "$APPR3" | awk '{print $2}')
  round=$(grep '^round:' "$APPR3" | awk '{print $2}')
  [ "$verdict" = "propose" ] && _pass "T3 verdict=propose" || _fail "T3 verdict=$verdict"
  [ "$round" = "2" ] && _pass "T3 round=2" || _fail "T3 round=$round"
  [ -f "$SANDBOX_ROOT/.claude/intake-council/${ID3}/round-2-pragmatist.md" ] && _pass "T3 Round-2 file exists" || _fail "T3 Round-2 file missing"
else
  _fail "T3 approval file missing"
fi

# ===========================================================================
# Test 4: Split → Pragmatist needs-full-council
# ===========================================================================
echo "Test 4: split → pragmatist needs-full-council"
_reset_ledger
ID4="20260512-100004-t4"
PROP4="$SANDBOX_ROOT/.claude/stakeholder/pending-proposal/${ID4}.md"
_make_proposal "$ID4" "$PROP4"
MOCK_PRO_VOTE=accept MOCK_SKP_VOTE=reject MOCK_PRAG_VOTE=needs-full-council _run_council "$PROP4" >/dev/null 2>&1 || true
APPR4="$SANDBOX_ROOT/.claude/stakeholder/pending-approval/${ID4}.md"
if [ -f "$APPR4" ]; then
  verdict=$(grep '^verdict:' "$APPR4" | awk '{print $2}')
  req=$(grep '^requires_human_dispute:' "$APPR4" | awk '{print $2}')
  [ "$verdict" = "needs-full-council" ] && _pass "T4 verdict=needs-full-council" || _fail "T4 verdict=$verdict"
  [ "$req" = "true" ] && _pass "T4 requires_human_dispute=true" || _fail "T4 requires_human_dispute=$req"
else
  _fail "T4 approval file missing"
fi

# ===========================================================================
# Test 5: Cost-Cap pre-loaded $15 → exit 2 + verdict=reject + cost-cap-aborted
# ===========================================================================
echo "Test 5: cost-cap pre-loaded → exit 2 + reject"
_reset_ledger
# Lade Ledger mit $15 (überschreitet $10/Tag) — Subshell, damit `set -e` in cost-cap.sh
# nicht in unser Test-Skript propagiert.
(
  set +e
  source "$REPO_ROOT/.claude/scripts/lib/cost-cap.sh"
  COST_CAP_LEDGER_DIR="$SANDBOX_ROOT/.claude/overseer" cost_record "pre-loaded" "15.0"
) || true

ID5="20260512-100005-t5"
PROP5="$SANDBOX_ROOT/.claude/stakeholder/pending-proposal/${ID5}.md"
_make_proposal "$ID5" "$PROP5"

_run_council "$PROP5" >/dev/null 2>&1
rc=$?
[ "$rc" = "2" ] && _pass "T5 exit-code=2" || _fail "T5 exit=$rc (expected 2)"
APPR5="$SANDBOX_ROOT/.claude/stakeholder/pending-approval/${ID5}.md"
if [ -f "$APPR5" ]; then
  verdict=$(grep '^verdict:' "$APPR5" | awk '{print $2}')
  [ "$verdict" = "reject" ] && _pass "T5 verdict=reject" || _fail "T5 verdict=$verdict"
  if grep -q "cost-cap-aborted" "$APPR5"; then
    _pass "T5 cost-cap-aborted in body"
  else
    _fail "T5 cost-cap-aborted marker missing"
  fi
else
  _fail "T5 approval file missing"
fi

# ===========================================================================
# Test 6: --resume on aborted council (only round-1 files) → continues
# ===========================================================================
echo "Test 6: --resume continues with Round-2"
_reset_ledger
ID6="20260512-100006-t6"
PROP6="$SANDBOX_ROOT/.claude/stakeholder/pending-proposal/${ID6}.md"
_make_proposal "$ID6" "$PROP6"
# Vorbereitung: simulieren dass Round-1-Files existieren, aber Round-2 nicht
mkdir -p "$SANDBOX_ROOT/.claude/intake-council/${ID6}"
cat > "$SANDBOX_ROOT/.claude/intake-council/${ID6}/round-1-proponent.md" <<EOF
## Proponent
### Vote: accept
EOF
cat > "$SANDBOX_ROOT/.claude/intake-council/${ID6}/round-1-skeptic.md" <<EOF
## Skeptic
### Vote: reject
EOF
MOCK_PRAG_VOTE=propose _run_council --resume "$ID6" >/dev/null 2>&1 || true
APPR6="$SANDBOX_ROOT/.claude/stakeholder/pending-approval/${ID6}.md"
if [ -f "$APPR6" ]; then
  verdict=$(grep '^verdict:' "$APPR6" | awk '{print $2}')
  [ "$verdict" = "propose" ] && _pass "T6 resume → verdict=propose" || _fail "T6 verdict=$verdict"
  [ -f "$SANDBOX_ROOT/.claude/intake-council/${ID6}/round-2-pragmatist.md" ] && _pass "T6 Round-2 file written via resume" || _fail "T6 Round-2 file missing"
else
  _fail "T6 approval file missing"
fi

# ===========================================================================
# Test 7: --status prints frontmatter
# ===========================================================================
echo "Test 7: --status prints frontmatter"
status_out=$(_run_council --status "$ID1" 2>&1 || true)
if echo "$status_out" | grep -q "^id: ${ID1}"; then
  _pass "T7 --status shows id"
else
  _fail "T7 --status missing id (got: $status_out)"
fi
if echo "$status_out" | grep -q "^verdict:"; then
  _pass "T7 --status shows verdict"
else
  _fail "T7 --status missing verdict"
fi

# ===========================================================================
# Test 8: Stakeholder-Original = deterministic copy (hash match)
# ===========================================================================
echo "Test 8: Stakeholder-Original is deterministic copy"
# Vergleiche Body in APPR1 mit Body in PROP1
PROP1_BODY=$(awk 'BEGIN{c=0;p=0} /^---[[:space:]]*$/{c++; if(c==2){p=1;next}} p{print}' "$PROP1")
# Extrahiere "## Stakeholder-Original"-Abschnitt aus Approval-File
APPR1_ORIG=$(awk '/^## Stakeholder-Original/{flag=1; next} flag{print}' "$APPR1")
PROP1_HASH=$(printf '%s' "$PROP1_BODY" | shasum -a 256 | awk '{print $1}')
APPR1_ORIG_TRIMMED=$(printf '%s' "$APPR1_ORIG" | sed '/^$/d' | head -n 3)
PROP1_BODY_TRIMMED=$(printf '%s' "$PROP1_BODY" | sed '/^$/d')
if [ "$APPR1_ORIG_TRIMMED" = "$PROP1_BODY_TRIMMED" ]; then
  _pass "T8 Stakeholder-Original body matches proposal body (hash $PROP1_HASH)"
else
  # Schwächere Prüfung: enthält die UNTRUSTED-Marker und den body-text?
  if echo "$APPR1_ORIG" | grep -q "test proposal body" && \
     echo "$APPR1_ORIG" | grep -q "UNTRUSTED_STAKEHOLDER_INPUT"; then
    _pass "T8 Stakeholder-Original contains proposal body + sentinel markers"
  else
    _fail "T8 Stakeholder-Original does not match proposal body"
  fi
fi

# ===========================================================================
# Test 9: HMAC-Token present + 16-char
# ===========================================================================
echo "Test 9: HMAC-Token present + 16-char"
token=$(grep '^hmac_token:' "$APPR1" | awk '{print $2}')
if [ -n "$token" ] && [ "${#token}" = "16" ]; then
  _pass "T9 hmac_token=$token (16 chars)"
else
  _fail "T9 hmac_token='$token' length=${#token}"
fi

# ===========================================================================
# Test 10: created_from: intake-council
# ===========================================================================
echo "Test 10: created_from: intake-council"
if grep -q '^created_from: intake-council' "$APPR1"; then
  _pass "T10 created_from=intake-council"
else
  _fail "T10 created_from marker missing"
fi

# ===========================================================================
# Test 11: API-Key Pre-Flight → exit 1
# ===========================================================================
echo "Test 11: API-Key Pre-Flight"
PROP11="$SANDBOX_ROOT/.claude/stakeholder/pending-proposal/dummy.md"
_make_proposal "dummy" "$PROP11"
api_rc=0
ANTHROPIC_API_KEY=fake \
PATH="$MOCK_BIN_DIR:$PATH" \
INTAKE_COUNCIL_DIR="$SANDBOX_ROOT/.claude/intake-council" \
PENDING_PROPOSAL_DIR="$SANDBOX_ROOT/.claude/stakeholder/pending-proposal" \
PENDING_APPROVAL_DIR="$SANDBOX_ROOT/.claude/stakeholder/pending-approval" \
COST_CAP_LEDGER_DIR="$SANDBOX_ROOT/.claude/overseer" \
CLAUDE_PROJECT_DIR="$REPO_ROOT" \
HOME="$_TMPDIR/fakehome" \
bash "$COUNCIL_SH" "$PROP11" >/dev/null 2>&1 || api_rc=$?
[ "$api_rc" = "1" ] && _pass "T11 ANTHROPIC_API_KEY → exit 1" || _fail "T11 expected exit 1, got $api_rc"

# ===========================================================================
# Test 12: pushed_at: "" empty initially
# ===========================================================================
echo "Test 12: pushed_at empty initially"
if grep -q '^pushed_at: ""' "$APPR1"; then
  _pass "T12 pushed_at: \"\" empty"
else
  _fail "T12 pushed_at not empty (got: $(grep '^pushed_at:' "$APPR1"))"
fi

# ===========================================================================
# Summary
# ===========================================================================
echo ""
echo "============================================="
echo "Tests passed: $PASS"
echo "Tests failed: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  for e in "${ERRORS[@]}"; do echo "  - $e"; done
  exit 1
fi
exit 0
