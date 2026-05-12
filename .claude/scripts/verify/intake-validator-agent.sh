#!/usr/bin/env bash
# verify/intake-validator-agent.sh
# Format-Verify für .claude/agents/intake-validator.md
# Exit 0 = alle Checks pass, Exit 1 = Findings

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
AGENT_FILE="$REPO_ROOT/.claude/agents/intake-validator.md"

PASS=0
FAIL=0

_check() {
  local desc="$1"
  local result="$2"  # "ok" or "fail"
  if [ "$result" = "ok" ]; then
    printf '  [OK]  %s\n' "$desc"
    PASS=$((PASS + 1))
  else
    printf '  [FAIL] %s\n' "$desc"
    FAIL=$((FAIL + 1))
  fi
}

GREP=/usr/bin/grep

_grep_ok() {
  local desc="$1"
  local pattern="$2"
  local file="${3:-$AGENT_FILE}"
  # Use -E without -i to avoid macOS grep -iE + bracket-expr incompatibility.
  # Patterns should use (A|a) alternation for case-insensitivity where needed.
  if $GREP -qE "$pattern" "$file" 2>/dev/null; then
    _check "$desc" "ok"
  else
    _check "$desc" "fail"
  fi
}

_count_ge() {
  local desc="$1"
  local pattern="$2"
  local min="$3"
  local file="${4:-$AGENT_FILE}"
  local count
  count="$($GREP -cE "$pattern" "$file" 2>/dev/null || true)"
  if [ "$count" -ge "$min" ]; then
    _check "$desc (found $count, need $min)" "ok"
  else
    _check "$desc (found $count, need $min)" "fail"
  fi
}

printf '\n=== intake-validator-agent.sh format verify ===\n\n'

# --- File exists ---
if [ ! -f "$AGENT_FILE" ]; then
  printf '[FAIL] Agent file not found: %s\n' "$AGENT_FILE"
  exit 1
fi
_check "Agent file exists" "ok"

# --- Frontmatter ---
_grep_ok "Frontmatter: name: intake-validator" "^name: intake-validator"
_grep_ok "Frontmatter: model: sonnet" "^model: sonnet"
_grep_ok "Frontmatter: tools includes Read" "tools:.*Read"
_grep_ok "Frontmatter: tools includes Grep" "tools:.*Grep"
_grep_ok "Frontmatter: tools includes Glob" "tools:.*Glob"
_grep_ok "Frontmatter: tools includes Write" "tools:.*Write"
_grep_ok "Frontmatter: description mentions intake-council" "description:.*intake-council"
_grep_ok "Frontmatter: description mentions Self-Mod" "description:.*(Self-Mod|self-mod)"
_grep_ok "Frontmatter: description mentions quarantine" "description:.*quarantine"

# --- Five categories documented (5 split into 5a + 5b) ---
_grep_ok "Kategorie 1 section present" "Kategorie 1.*(Destruktiv|destruktiv)"
_grep_ok "Kategorie 2 section present" "Kategorie 2.*(Self-Mod|self-mod)"
_grep_ok "Kategorie 3 section present" "Kategorie 3.*(Gef|gef)"
_grep_ok "Kategorie 4 section present" "Kategorie 4.*(Injection|injection)"
_grep_ok "Kategorie 5 section present" "Kategorie 5"
# 5a: OUTER Frontmatter schema documented separately
_grep_ok "Kat-5a: OUTER Frontmatter block documented" "Kategorie 5a"
_grep_ok "Kat-5a: source tier-1/2/3 constraint documented" "tier-1.*tier-2.*tier-3|tier-[123]"
_grep_ok "Kat-5a: hmac_token constraint documented" "hmac_token"
_grep_ok "Kat-5a: verdict enum documented in 5a block" "propose.*propose-with-changes"
# 5b: INNER YAML schema documented separately
_grep_ok "Kat-5b: INNER YAML block documented" "Kategorie 5b"
_grep_ok "Kat-5b: source tier-3-intake in INNER block" "tier-3-intake"
_grep_ok "Kat-5b: budget_usd in INNER block" "budget_usd"
_grep_ok "Kat-5b: model constraint in INNER block" "(haiku|sonnet|opus)"
_grep_ok "Kat-5b: trust_tier in INNER block" "trust_tier"
# Key distinction: INNER vs OUTER scan scope explicitly stated
_grep_ok "Scan-scope: INNER YAML scan note present" "(INNER YAML|inner.*yaml|INNER.*Backlog)"

# --- Kategorie 1: min 8 destructive commands (10 required per spec, check 8+) ---
_count_ge "Kat-1: at least 8 destructive command patterns" \
  "(git.rm|rm\s+-rf|drop\s+table|delete\s+from|supabase\s+db|gh\s+repo\s+delete|gh\s+pr\s+merge.*admin|git.reset.*hard|git.push.*(-f|force)|git.branch.*-[Dd])" \
  8

# --- Kategorie 2: min 7 self-mod paths ---
_count_ge "Kat-2: at least 7 self-mod paths" \
  "(\.claude/scripts/|\.claude/agents/|settings\.json|settings\.local\.json|\.user-session-active|CLAUDE\.md|\.github/workflows/|LaunchAgents/com\.inventory)" \
  7

# --- Kategorie 3: min 5 dangerous paths ---
_count_ge "Kat-3: at least 5 dangerous path patterns" \
  "(~/|/etc/|/var/|/usr/|/System/|/Library/|\.env|supabase_config|google-services|GoogleService-Info|\.pem|\.key)" \
  5

# --- Three few-shot examples ---
_grep_ok "Few-Shot Beispiel 1 (PASS)" "(Beispiel 1|beispiel 1)"
_grep_ok "Few-Shot Beispiel 2 (NEEDS-FULL-COUNCIL)" "(Beispiel 2|beispiel 2)"
_grep_ok "Few-Shot Beispiel 3 (QUARANTINE)" "(Beispiel 3|beispiel 3)"
count_examples="$($GREP -cE "^### Beispiel [0-9]" "$AGENT_FILE" 2>/dev/null || true)"
if [ "$count_examples" -ge 3 ]; then
  _check "At least 3 few-shot examples (found $count_examples)" "ok"
else
  _check "At least 3 few-shot examples (found $count_examples)" "fail"
fi

# --- Output paths documented ---
_grep_ok "Output path: overseer/inbox documented" "overseer/inbox"
_grep_ok "Output path: quarantine documented" "quarantine"
_grep_ok "Output: needs-full-council update documented" "needs-full-council"

# --- Processing order documented ---
_grep_ok "Processing order / Verarbeitungs-Reihenfolge section" "(Verarbeitungs-Reihenfolge|verarbeitungs-reihenfolge)"

# --- Self-Mod-Blocklist reference ---
_grep_ok "Self-Mod-Blocklist file reference" "self-mod-blocklist\.sh"

# --- Not in blocklist note ---
_grep_ok "Not-in-Self-Mod-Blocklist note present" "(nicht in|not in|NICHT in).*[Ss]elf.[Mm]od.[Bb]locklist"

# --- created_from: intake-council distinction ---
_grep_ok "created_from: intake-council distinction documented" "created_from.*intake-council"

# --- Sentinel pattern for untrusted zone ---
_grep_ok "UNTRUSTED_PROPOSAL_INPUT sentinel documented" "UNTRUSTED_PROPOSAL_INPUT"

printf '\n=== Results: %d pass, %d fail ===\n\n' "$PASS" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  printf 'VERIFY FAILED — fix the agent file before proceeding.\n'
  exit 1
fi

printf 'VERIFY PASSED — intake-validator.md format is complete.\n'
exit 0
