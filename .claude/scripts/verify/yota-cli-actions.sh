#!/usr/bin/env bash
# verify/yota-cli-actions.sh — Unit tests for T26 CLI actions (yota-go/reject/change)
#
# Tests:
#  T1  yota-go.sh <id> <token>  with mock pending-approval → moves to approved/
#  T2  yota-go.sh without pending → exit 2 with stderr
#  T3  yota-reject.sh <id> "no fit" → moves to rejected/
#  T4  yota-change.sh <id> "use SQLite" → atomic-mv + new pending-proposal
#  T5  Creator-binding: id with different user_id → exit 3 (silent ignore)
#
# All pass → exit 0. Any failure → exit 1.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

YOTA_GO="${SCRIPT_DIR}/../yota-go.sh"
YOTA_REJECT="${SCRIPT_DIR}/../yota-reject.sh"
YOTA_CHANGE="${SCRIPT_DIR}/../yota-change.sh"
INTAKE_ACTIONS_LIB="${SCRIPT_DIR}/../lib/intake-actions.sh"

PASS=0
FAIL=0
ERRORS=()

_TMPDIR="$(mktemp -d /tmp/verify-yota-cli-XXXXXX)"
trap 'rm -rf "$_TMPDIR"' EXIT

_pass() { printf '  PASS: %s\n' "$1"; (( PASS++ )) || true; }
_fail() { printf '  FAIL: %s\n' "$1"; ERRORS+=("$1"); (( FAIL++ )) || true; }

# ---------------------------------------------------------------------------
# Setup: fake repo layout
# ---------------------------------------------------------------------------
FAKE_REPO="$_TMPDIR/repo"
APPROVAL_DIR="$FAKE_REPO/.claude/stakeholder/pending-approval"
PROPOSAL_DIR="$FAKE_REPO/.claude/stakeholder/pending-proposal"
REJECTED_DIR="$FAKE_REPO/.claude/stakeholder/rejected"
OVERSEER_INBOX="$FAKE_REPO/.claude/overseer/inbox"

mkdir -p "$APPROVAL_DIR/approved" "$PROPOSAL_DIR" "$REJECTED_DIR" "$OVERSEER_INBOX"
mkdir -p "$FAKE_REPO/.claude/scripts/lib"

# Stub audit.sh
cat > "$FAKE_REPO/.claude/scripts/lib/audit.sh" <<'EOF'
audit_record() { :; }
EOF

# Stub intake-tokens.sh (verify always passes for mock token "abcd1234abcd1234")
cat > "$FAKE_REPO/.claude/scripts/lib/intake-tokens.sh" <<'EOF'
generate_hmac_token() { printf 'abcd1234abcd1234\n'; }
verify_hmac_token() {
  local id="$1" token="$2"
  [ "$token" = "abcd1234abcd1234" ]
}
generate_content_hash() { printf 'fakehash\n'; }
EOF

# Stub intake-validator-agent.sh (always pass)
mkdir -p "$FAKE_REPO/.claude/scripts"
cat > "$FAKE_REPO/.claude/scripts/lib/intake-validator-agent.sh" <<'EOF'
#!/usr/bin/env bash
printf 'verdict: pass\nreason: ok\n'
EOF

# Stub intake-council.sh (no-op)
cat > "$FAKE_REPO/.claude/scripts/intake-council.sh" <<'EOF'
#!/usr/bin/env bash
printf '[intake-council-stub] called with %s\n' "$*" >&2
EOF
chmod +x "$FAKE_REPO/.claude/scripts/intake-council.sh"

# Stub notify.sh
cat > "$FAKE_REPO/.claude/scripts/notify.sh" <<'EOF'
#!/usr/bin/env bash
:
EOF
chmod +x "$FAKE_REPO/.claude/scripts/notify.sh"

# ---------------------------------------------------------------------------
# Helper: write a mock pending-approval file
# ---------------------------------------------------------------------------
_mk_approval() {
  local id="$1" user_id="${2:-local-testuser}" round="${3:-1}"
  local file="${APPROVAL_DIR}/${id}.md"
  cat > "$file" <<EOF
---
id: ${id}
state: pending-approval
user_id: ${user_id}
hmac_token: abcd1234abcd1234
verdict: propose
round: ${round}
source: tier-1
trust_tier: 1
content_hash: fakehash
---

# Proposal: ${id}

Some proposal text.
EOF
  printf '%s' "$file"
}

# ---------------------------------------------------------------------------
# T1: yota-go.sh with valid token → approved
# ---------------------------------------------------------------------------
printf '\n=== T1: yota-go.sh <id> <token> → approved ===\n'
T1_ID="20260512-100000-test-go"
_mk_approval "$T1_ID" "local-testuser" >/dev/null

T1_OUT="$(REPO_ROOT="$FAKE_REPO" \
  PENDING_APPROVAL_DIR="$APPROVAL_DIR" \
  PENDING_PROPOSAL_DIR="$PROPOSAL_DIR" \
  REJECTED_DIR="$REJECTED_DIR" \
  OVERSEER_INBOX_DIR="$OVERSEER_INBOX" \
  USER=testuser \
  bash "$YOTA_GO" "$T1_ID" "abcd1234abcd1234" 2>&1)"
T1_RC=$?

if [ $T1_RC -eq 0 ]; then
  _pass "T1: yota-go.sh exit 0"
else
  _fail "T1: yota-go.sh exit $T1_RC (output: $T1_OUT)"
fi

if [ -f "${APPROVAL_DIR}/approved/${T1_ID}.md" ]; then
  _pass "T1: approval file moved to approved/"
else
  _fail "T1: approval file not in approved/ (output: $T1_OUT)"
fi

if [ ! -f "${APPROVAL_DIR}/${T1_ID}.md" ]; then
  _pass "T1: original approval file removed from pending-approval/"
else
  _fail "T1: original approval file still in pending-approval/"
fi

# ---------------------------------------------------------------------------
# T2: yota-go.sh without pending → exit 2 + stderr
# ---------------------------------------------------------------------------
printf '\n=== T2: yota-go.sh <nonexistent> → exit 2 ===\n'
T2_ERR="$(REPO_ROOT="$FAKE_REPO" \
  PENDING_APPROVAL_DIR="$APPROVAL_DIR" \
  PENDING_PROPOSAL_DIR="$PROPOSAL_DIR" \
  USER=testuser \
  bash "$YOTA_GO" "nonexistent-id-xyz" 2>&1 1>/dev/null)"
T2_RC=$?

if [ $T2_RC -eq 2 ]; then
  _pass "T2: exit 2 when no pending approval found"
else
  _fail "T2: expected exit 2, got $T2_RC"
fi

if printf '%s' "$T2_ERR" | grep -qi 'no pending\|not found'; then
  _pass "T2: stderr contains informative error message"
else
  _fail "T2: stderr missing informative error (got: $T2_ERR)"
fi

# ---------------------------------------------------------------------------
# T3: yota-reject.sh <id> "no fit" → moved to rejected/
# ---------------------------------------------------------------------------
printf '\n=== T3: yota-reject.sh <id> "no fit" → rejected ===\n'
T3_ID="20260512-100100-test-reject"
_mk_approval "$T3_ID" "local-testuser" >/dev/null

T3_OUT="$(REPO_ROOT="$FAKE_REPO" \
  PENDING_APPROVAL_DIR="$APPROVAL_DIR" \
  PENDING_PROPOSAL_DIR="$PROPOSAL_DIR" \
  REJECTED_DIR="$REJECTED_DIR" \
  USER=testuser \
  bash "$YOTA_REJECT" "$T3_ID" "no fit" 2>&1)"
T3_RC=$?

if [ $T3_RC -eq 0 ]; then
  _pass "T3: yota-reject.sh exit 0"
else
  _fail "T3: yota-reject.sh exit $T3_RC (output: $T3_OUT)"
fi

if [ -f "${REJECTED_DIR}/${T3_ID}.md" ]; then
  _pass "T3: approval file moved to rejected/"
else
  _fail "T3: file not in rejected/ (output: $T3_OUT)"
fi

if grep -q 'rejected_by' "${REJECTED_DIR}/${T3_ID}.md" 2>/dev/null; then
  _pass "T3: rejected_by metadata written"
else
  _fail "T3: rejected_by metadata missing"
fi

# ---------------------------------------------------------------------------
# T4: yota-change.sh <id> "use SQLite" → superseded + new pending-proposal
# ---------------------------------------------------------------------------
printf '\n=== T4: yota-change.sh <id> "use SQLite" → round+1 ===\n'
T4_ID="20260512-100200-test-change"
_mk_approval "$T4_ID" "local-testuser" "1" >/dev/null

T4_OUT="$(REPO_ROOT="$FAKE_REPO" \
  PENDING_APPROVAL_DIR="$APPROVAL_DIR" \
  PENDING_PROPOSAL_DIR="$PROPOSAL_DIR" \
  REJECTED_DIR="$REJECTED_DIR" \
  USER=testuser \
  bash "$YOTA_CHANGE" "$T4_ID" "use SQLite" 2>&1)"
T4_RC=$?

if [ $T4_RC -eq 0 ]; then
  _pass "T4: yota-change.sh exit 0"
else
  _fail "T4: yota-change.sh exit $T4_RC (output: $T4_OUT)"
fi

if [ -f "${APPROVAL_DIR}/${T4_ID}.superseded.md" ]; then
  _pass "T4: original approval moved to .superseded.md"
else
  _fail "T4: .superseded.md not found"
fi

if [ -f "${PROPOSAL_DIR}/${T4_ID}.md" ]; then
  _pass "T4: new pending-proposal created"
  if grep -q 'round: 2' "${PROPOSAL_DIR}/${T4_ID}.md"; then
    _pass "T4: round incremented to 2"
  else
    _fail "T4: round not incremented"
  fi
  if grep -q 'use SQLite' "${PROPOSAL_DIR}/${T4_ID}.md"; then
    _pass "T4: change text embedded in new proposal"
  else
    _fail "T4: change text missing from new proposal"
  fi
else
  _fail "T4: new pending-proposal not found at ${PROPOSAL_DIR}/${T4_ID}.md"
fi

# ---------------------------------------------------------------------------
# T5: Creator-binding — wrong user_id → exit 3 (silent ignore)
# ---------------------------------------------------------------------------
printf '\n=== T5: creator-binding with wrong user → exit 3 ===\n'
T5_ID="20260512-100300-test-binding"
# Create approval owned by "local-alice"
_mk_approval "$T5_ID" "local-alice" >/dev/null

# Call as "local-bob" (different user)
T5_ERR="$(REPO_ROOT="$FAKE_REPO" \
  PENDING_APPROVAL_DIR="$APPROVAL_DIR" \
  PENDING_PROPOSAL_DIR="$PROPOSAL_DIR" \
  REJECTED_DIR="$REJECTED_DIR" \
  USER=bob \
  bash "$YOTA_GO" "$T5_ID" "" 2>&1)"
T5_RC=$?

if [ $T5_RC -eq 3 ]; then
  _pass "T5: exit 3 on creator-binding mismatch"
else
  _fail "T5: expected exit 3, got $T5_RC (output: $T5_ERR)"
fi

# Approval file must remain untouched
if [ -f "${APPROVAL_DIR}/${T5_ID}.md" ]; then
  _pass "T5: approval file untouched after mismatch"
else
  _fail "T5: approval file was modified/removed on mismatch"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"
if [ "${#ERRORS[@]}" -gt 0 ]; then
  printf 'Failed tests:\n'
  for e in "${ERRORS[@]}"; do
    printf '  - %s\n' "$e"
  done
  exit 1
fi
exit 0
