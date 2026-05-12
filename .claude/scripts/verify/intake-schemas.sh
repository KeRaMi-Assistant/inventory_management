#!/usr/bin/env bash
# verify/intake-schemas.sh — verify all 4 intake JSON-schemas with valid + invalid fixtures
# Exit 0 = all pass, 1 = failures

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/intake-schema-validate.sh"

PASS=0
FAIL=0
TMPDIR_FIXTURES="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_FIXTURES"' EXIT

_assert_valid() {
  local type="$1" file="$2" label="$3"
  if validate_intake_file "$type" "$file" >/dev/null 2>&1; then
    echo "  PASS [valid]   $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL [valid]   $label — expected VALID but got INVALID"
    validate_intake_file "$type" "$file" 2>&1 | sed 's/^/    /'
    FAIL=$((FAIL + 1))
  fi
}

_assert_invalid() {
  local type="$1" file="$2" label="$3"
  if ! validate_intake_file "$type" "$file" >/dev/null 2>&1; then
    echo "  PASS [invalid] $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL [invalid] $label — expected INVALID but got VALID"
    FAIL=$((FAIL + 1))
  fi
}

# ─── pending-proposal ────────────────────────────────────────────────────────
echo "=== pending-proposal ==="

cat > "$TMPDIR_FIXTURES/pp-valid1.md" << 'EOF'
---
id: 20260512-143000-add-dark-mode
source: tier-1
trust_tier: 1
user_id: tg_123456
created_at: 2026-05-12T14:30:00Z
state: pending-proposal
round: 1
content_hash: 1b4f0e9851971998e732078544c96b36c3d01cedf7caa332359d6f1d83567014
---

<<<UNTRUSTED_STAKEHOLDER_INPUT tier=1>>>
Add dark mode to the app.
<<<END_UNTRUSTED_STAKEHOLDER_INPUT>>>
EOF

cat > "$TMPDIR_FIXTURES/pp-valid2.md" << 'EOF'
---
id: 20260512-090000-fix-crash-on-login
source: tier-2
trust_tier: 2
user_id: local_dev
created_at: 2026-05-12T09:00:00Z
state: pending-proposal
round: 3
content_hash: 60303ae22b998861bce3b28f33eec1be758a213c86c93c076dbe9f558c11c752
---

<<<UNTRUSTED_STAKEHOLDER_INPUT tier=2>>>
Fix crash on login screen.
<<<END_UNTRUSTED_STAKEHOLDER_INPUT>>>
EOF

# Invalid: missing content_hash
cat > "$TMPDIR_FIXTURES/pp-invalid1.md" << 'EOF'
---
id: 20260512-143000-add-dark-mode
source: tier-1
trust_tier: 1
user_id: tg_123456
created_at: 2026-05-12T14:30:00Z
state: pending-proposal
round: 1
---

body here
EOF

# Invalid: round out of range + wrong state
cat > "$TMPDIR_FIXTURES/pp-invalid2.md" << 'EOF'
---
id: 20260512-143000-add-dark-mode
source: tier-1
trust_tier: 1
user_id: tg_123456
created_at: 2026-05-12T14:30:00Z
state: pending-approval
round: 5
content_hash: 1b4f0e9851971998e732078544c96b36c3d01cedf7caa332359d6f1d83567014
---

body here
EOF

_assert_valid "pending-proposal" "$TMPDIR_FIXTURES/pp-valid1.md" "full valid proposal round=1"
_assert_valid "pending-proposal" "$TMPDIR_FIXTURES/pp-valid2.md" "valid proposal tier-2 round=3"
_assert_invalid "pending-proposal" "$TMPDIR_FIXTURES/pp-invalid1.md" "missing content_hash"
_assert_invalid "pending-proposal" "$TMPDIR_FIXTURES/pp-invalid2.md" "wrong state + round=5"

# ─── pending-approval ────────────────────────────────────────────────────────
echo ""
echo "=== pending-approval ==="

cat > "$TMPDIR_FIXTURES/pa-valid1.md" << 'EOF'
---
id: 20260512-143000-add-dark-mode
source: tier-1
trust_tier: 1
user_id: tg_123456
created_at: 2026-05-12T14:30:00Z
council_finished_at: 2026-05-12T14:32:00Z
state: pending-approval
verdict: propose
round: 1
council_cost_usd: 0.52
hmac_token: abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890
pushed_at: 2026-05-12T14:32:05Z
requires_human_dispute: false
touches: [lib/app_theme.dart, lib/screens/settings_screen.dart]
created_from: intake-council
---

## Verdict-Summary
Council recommends adding dark mode.
EOF

cat > "$TMPDIR_FIXTURES/pa-valid2.md" << 'EOF'
---
id: 20260512-090000-fix-crash-on-login
source: tier-2
trust_tier: 2
user_id: local_dev
created_at: 2026-05-12T09:00:00Z
council_finished_at: 2026-05-12T09:05:00Z
state: pending-approval
verdict: propose-with-changes
round: 2
council_cost_usd: 0.71
hmac_token: fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210
pushed_at: null
requires_human_dispute: true
touches: []
created_from: intake-council
---

## Verdict-Summary
Council recommends with changes.
EOF

# Invalid: wrong created_from
cat > "$TMPDIR_FIXTURES/pa-invalid1.md" << 'EOF'
---
id: 20260512-143000-add-dark-mode
source: tier-1
trust_tier: 1
user_id: tg_123456
created_at: 2026-05-12T14:30:00Z
council_finished_at: 2026-05-12T14:32:00Z
state: pending-approval
verdict: propose
round: 1
council_cost_usd: 0.52
hmac_token: abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890
pushed_at: 2026-05-12T14:32:05Z
requires_human_dispute: false
touches: []
created_from: stakeholder-validator
---

body
EOF

# Invalid: bad verdict value
cat > "$TMPDIR_FIXTURES/pa-invalid2.md" << 'EOF'
---
id: 20260512-143000-add-dark-mode
source: tier-1
trust_tier: 1
user_id: tg_123456
created_at: 2026-05-12T14:30:00Z
council_finished_at: 2026-05-12T14:32:00Z
state: pending-approval
verdict: approve
round: 1
council_cost_usd: 0.52
hmac_token: abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890
pushed_at: null
requires_human_dispute: false
touches: []
created_from: intake-council
---

body
EOF

_assert_valid "pending-approval" "$TMPDIR_FIXTURES/pa-valid1.md" "full valid approval with touches"
_assert_valid "pending-approval" "$TMPDIR_FIXTURES/pa-valid2.md" "valid approval pushed_at=null requires_dispute=true"
_assert_invalid "pending-approval" "$TMPDIR_FIXTURES/pa-invalid1.md" "wrong created_from"
_assert_invalid "pending-approval" "$TMPDIR_FIXTURES/pa-invalid2.md" "invalid verdict=approve"

# ─── rejected ────────────────────────────────────────────────────────────────
echo ""
echo "=== rejected ==="

cat > "$TMPDIR_FIXTURES/rej-valid1.md" << 'EOF'
---
id: 20260512-143000-add-dark-mode
state: rejected
rejected_by: user
rejected_at: 2026-05-12T15:00:00Z
user_reason: Not needed right now
council_verdict_was: propose
---

[Full snapshot of pending-approval follows...]
EOF

cat > "$TMPDIR_FIXTURES/rej-valid2.md" << 'EOF'
---
id: 20260512-090000-fix-crash-on-login
state: rejected
rejected_by: user
rejected_at: 2026-05-12T10:00:00Z
council_verdict_was: reject
---

[Full snapshot follows...]
EOF

# Invalid: missing council_verdict_was
cat > "$TMPDIR_FIXTURES/rej-invalid1.md" << 'EOF'
---
id: 20260512-143000-add-dark-mode
state: rejected
rejected_by: user
rejected_at: 2026-05-12T15:00:00Z
---

body
EOF

# Invalid: bad rejected_by value + invalid council_verdict_was
cat > "$TMPDIR_FIXTURES/rej-invalid2.md" << 'EOF'
---
id: 20260512-143000-add-dark-mode
state: rejected
rejected_by: council
rejected_at: 2026-05-12T15:00:00Z
council_verdict_was: accepted
---

body
EOF

_assert_valid "rejected" "$TMPDIR_FIXTURES/rej-valid1.md" "valid rejection with user_reason"
_assert_valid "rejected" "$TMPDIR_FIXTURES/rej-valid2.md" "valid rejection no user_reason"
_assert_invalid "rejected" "$TMPDIR_FIXTURES/rej-invalid1.md" "missing council_verdict_was"
_assert_invalid "rejected" "$TMPDIR_FIXTURES/rej-invalid2.md" "bad rejected_by + invalid council_verdict_was"

# ─── superseded ──────────────────────────────────────────────────────────────
echo ""
echo "=== superseded ==="

cat > "$TMPDIR_FIXTURES/sup-valid1.md" << 'EOF'
---
id: 20260512-143000-add-dark-mode
source: tier-1
trust_tier: 1
user_id: tg_123456
created_at: 2026-05-12T14:30:00Z
council_finished_at: 2026-05-12T14:32:00Z
state: pending-approval
verdict: propose-with-changes
round: 1
council_cost_usd: 0.52
hmac_token: abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890
pushed_at: null
requires_human_dispute: false
touches: [lib/app_theme.dart]
created_from: intake-council
superseded_at: 2026-05-12T14:45:00Z
superseded_by_round: 2
---

[Superseded snapshot]
EOF

cat > "$TMPDIR_FIXTURES/sup-valid2.md" << 'EOF'
---
id: 20260512-090000-fix-crash-on-login
source: tier-2
trust_tier: 2
user_id: local_dev
created_at: 2026-05-12T09:00:00Z
council_finished_at: 2026-05-12T09:05:00Z
state: pending-approval
verdict: reject
round: 2
council_cost_usd: 0.81
hmac_token: 1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
pushed_at: 2026-05-12T09:06:00Z
requires_human_dispute: true
touches: [.claude/agents/intake-council.md]
created_from: intake-council
superseded_at: 2026-05-12T09:30:00Z
superseded_by_round: 3
---

[Superseded snapshot]
EOF

# Invalid: missing superseded_at
cat > "$TMPDIR_FIXTURES/sup-invalid1.md" << 'EOF'
---
id: 20260512-143000-add-dark-mode
source: tier-1
trust_tier: 1
user_id: tg_123456
created_at: 2026-05-12T14:30:00Z
council_finished_at: 2026-05-12T14:32:00Z
state: pending-approval
verdict: propose
round: 1
council_cost_usd: 0.52
hmac_token: abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890
pushed_at: null
requires_human_dispute: false
touches: []
created_from: intake-council
superseded_by_round: 2
---

body
EOF

# Invalid: superseded_by_round=1 (must be ≥2)
cat > "$TMPDIR_FIXTURES/sup-invalid2.md" << 'EOF'
---
id: 20260512-143000-add-dark-mode
source: tier-1
trust_tier: 1
user_id: tg_123456
created_at: 2026-05-12T14:30:00Z
council_finished_at: 2026-05-12T14:32:00Z
state: pending-approval
verdict: propose
round: 1
council_cost_usd: 0.52
hmac_token: abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890
pushed_at: null
requires_human_dispute: false
touches: []
created_from: intake-council
superseded_at: 2026-05-12T14:45:00Z
superseded_by_round: 1
---

body
EOF

_assert_valid "superseded" "$TMPDIR_FIXTURES/sup-valid1.md" "valid superseded round 1->2"
_assert_valid "superseded" "$TMPDIR_FIXTURES/sup-valid2.md" "valid superseded round 2->3 with touches"
_assert_invalid "superseded" "$TMPDIR_FIXTURES/sup-invalid1.md" "missing superseded_at"
_assert_invalid "superseded" "$TMPDIR_FIXTURES/sup-invalid2.md" "superseded_by_round=1 (below minimum)"

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════"
echo "Results: $PASS passed, $FAIL failed"
echo "══════════════════════════════════════"

[[ $FAIL -eq 0 ]]
