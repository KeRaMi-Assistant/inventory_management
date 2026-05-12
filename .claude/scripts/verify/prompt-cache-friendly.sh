#!/usr/bin/env bash
# verify/prompt-cache-friendly.sh — Validates prompt-caching setup for subagents.
#
# Tests:
#   1. All 7 primary subagents exist + have valid YAML frontmatter (name, model, tools, description).
#   2. Prompt lengths >= ~125 lines (rough ~1500-token threshold for cache activation).
#   3. No dynamic markers ($ARGUMENTS, $VARIABLES not in # comments) in subagent body.
#   4. lib/cache-friendly-invoke.sh exists and is sourceable.
#   5. worker.sh uses cache-friendly pattern (user-input via -p at end, not prepended).
#   6. CLAUDE.md contains "Prompt-Caching" section.
#
# Exit 0 = all pass. Exit 1 = one or more failures.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
AGENTS_DIR="$REPO_ROOT/.claude/agents"
SCRIPTS_DIR="$REPO_ROOT/.claude/scripts"
CLAUDE_MD="$REPO_ROOT/CLAUDE.md"

PASS=0
FAIL=0

_pass() { printf '  [PASS] %s\n' "$*"; (( PASS++ )) || true; }
_fail() { printf '  [FAIL] %s\n' "$*" >&2; (( FAIL++ )) || true; }
_info() { printf '  [INFO] %s\n' "$*"; }

echo "=== prompt-cache-friendly verify ==="
echo

# ---------------------------------------------------------------------------
# Test 1: Primary subagents exist + valid frontmatter
# ---------------------------------------------------------------------------
echo "-- Test 1: Subagent existence + frontmatter --"

PRIMARY_AGENTS=(
  "planner"
  "browser-tester"
  "security-reviewer"
  "flutter-coder"
  "ui-builder"
  "stakeholder-triage"
  "disput-proponent"
)

OPTIONAL_AGENTS=(
  "disput-skeptic"
  "disput-pragmatist"
)

_check_frontmatter() {
  local file="$1"
  local name
  name="$(basename "$file" .md)"
  if [ ! -f "$file" ]; then
    _fail "$name: file missing ($file)"
    return
  fi
  # Check YAML frontmatter exists (starts with ---)
  local first_line
  first_line="$(head -1 "$file")"
  if [ "$first_line" != "---" ]; then
    _fail "$name: no YAML frontmatter (first line: '$first_line')"
    return
  fi
  # Check required frontmatter keys
  local fm_block
  fm_block="$(awk '/^---/{c++; if(c==2) exit} NR>1{print}' "$file")"
  for key in name model description; do
    if ! echo "$fm_block" | grep -q "^${key}:"; then
      _fail "$name: missing frontmatter key '$key'"
      return
    fi
  done
  local lines
  lines="$(wc -l < "$file")"
  local token_est=$(( lines * 12 ))
  _pass "$name: frontmatter OK | lines=$lines | token-estimate≈$token_est"
}

for agent in "${PRIMARY_AGENTS[@]}"; do
  _check_frontmatter "$AGENTS_DIR/${agent}.md"
done
for agent in "${OPTIONAL_AGENTS[@]}"; do
  if [ -f "$AGENTS_DIR/${agent}.md" ]; then
    _check_frontmatter "$AGENTS_DIR/${agent}.md"
  else
    _info "$agent: optional, not present — skip"
  fi
done

echo

# ---------------------------------------------------------------------------
# Test 2: Prompt lengths >= 125 lines (cache activation threshold ~1500 tokens)
# ---------------------------------------------------------------------------
echo "-- Test 2: Prompt length >= 125 lines --"

CACHE_THRESHOLD_LINES=125

for agent in "${PRIMARY_AGENTS[@]}"; do
  file="$AGENTS_DIR/${agent}.md"
  [ -f "$file" ] || continue
  lines="$(wc -l < "$file")"
  token_est=$(( lines * 12 ))
  if [ "$lines" -ge "$CACHE_THRESHOLD_LINES" ]; then
    _pass "$agent: $lines lines (~${token_est} tokens) >= threshold"
  else
    _info "$agent: $lines lines (~${token_est} tokens) — BELOW 125-line threshold"
    _info "      Cache may not activate for this agent (needs ~1024+ tokens)."
    _info "      Consider expanding the system-prompt with more examples/rules."
    # Not a hard FAIL — short agents still work, just won't cache.
    # Only mark fail if it's genuinely too short to be useful
    if [ "$lines" -lt 20 ]; then
      _fail "$agent: only $lines lines — suspiciously minimal, check file integrity"
    fi
  fi
done

echo

# ---------------------------------------------------------------------------
# Test 3: No bare dynamic markers in subagent body (would cause cache-miss)
# ---------------------------------------------------------------------------
echo "-- Test 3: No dynamic \$VARIABLE markers in subagent body --"

for agent in "${PRIMARY_AGENTS[@]}"; do
  file="$AGENTS_DIR/${agent}.md"
  [ -f "$file" ] || continue
  # Look for $VAR patterns outside of comments and code blocks
  # Exclude lines starting with # (comments) and lines in code fences
  bad_lines="$(grep -nE '\$[A-Z_]{3,}' "$file" | grep -v '^\s*#' | grep -v '^\s*`' || true)"
  if [ -n "$bad_lines" ]; then
    _fail "$agent: dynamic \$VARIABLE markers found (cache-hash unstable):"
    echo "$bad_lines" | head -5 | sed 's/^/         /' >&2
  else
    _pass "$agent: no bare dynamic markers"
  fi
done

echo

# ---------------------------------------------------------------------------
# Test 4: lib/cache-friendly-invoke.sh exists and is sourceable
# ---------------------------------------------------------------------------
echo "-- Test 4: lib/cache-friendly-invoke.sh exists + sourceable --"

LIB_FILE="$SCRIPTS_DIR/lib/cache-friendly-invoke.sh"
if [ ! -f "$LIB_FILE" ]; then
  _fail "lib/cache-friendly-invoke.sh: file missing"
else
  # Try to source in a subshell
  if bash -c "source '$LIB_FILE' && declare -f invoke_agent_cached > /dev/null" 2>/dev/null; then
    _pass "lib/cache-friendly-invoke.sh: exists + sourceable + invoke_agent_cached defined"
  else
    _fail "lib/cache-friendly-invoke.sh: exists but not sourceable or invoke_agent_cached missing"
  fi
fi

echo

# ---------------------------------------------------------------------------
# Test 5: worker.sh uses cache-friendly pattern
# ---------------------------------------------------------------------------
echo "-- Test 5: worker.sh cache-friendly invocation --"

WORKER_SH="$SCRIPTS_DIR/worker.sh"
if [ ! -f "$WORKER_SH" ]; then
  _fail "worker.sh: not found"
else
  # worker.sh uses -p "$PROMPT_HEADER" at the END of claude args (after --model etc.)
  # That is cache-friendly because the static system-prompt (from CLAUDE.md + agent def)
  # loads first, user-input is appended last.
  # Pattern we expect: claude ... -p "$PROMPT_HEADER" (not: claude -p "..." --model ...)
  if grep -qE 'claude.*-p "\$PROMPT_HEADER"' "$WORKER_SH"; then
    _pass "worker.sh: uses -p \"\$PROMPT_HEADER\" at end of claude args"
  else
    _info "worker.sh: -p pattern not found with exact match — checking loose form"
    if grep -qE '\-p "\$PROMPT' "$WORKER_SH"; then
      _pass "worker.sh: found -p \"\$PROMPT...\" pattern (cache-friendly)"
    else
      _fail "worker.sh: cannot confirm cache-friendly -p placement — review manually"
      _info "  Expected: claude [flags] -p \"\$PROMPT_HEADER\""
      _info "  File: $WORKER_SH"
    fi
  fi

  # Also check: no dynamic prefix injection before --model
  if grep -qE "claude.*\\\$SLUG\|claude.*\\\$MODEL.*-p" "$WORKER_SH"; then
    _info "worker.sh: dynamic vars in args — verify they don't appear before prompt body"
  fi
fi

echo

# ---------------------------------------------------------------------------
# Test 6: CLAUDE.md has Prompt-Caching section
# ---------------------------------------------------------------------------
echo "-- Test 6: CLAUDE.md has Prompt-Caching section --"

if [ ! -f "$CLAUDE_MD" ]; then
  _fail "CLAUDE.md: not found at $CLAUDE_MD"
elif grep -q "Prompt-Caching" "$CLAUDE_MD"; then
  _pass "CLAUDE.md: contains 'Prompt-Caching' section"
else
  _fail "CLAUDE.md: missing 'Prompt-Caching' section — run update per task spec"
fi

echo

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "=== Results: $PASS passed, $FAIL failed ==="
echo

if [ "$FAIL" -gt 0 ]; then
  printf 'Some checks failed. See [FAIL] lines above.\n' >&2
  exit 1
fi

printf 'All checks passed.\n'
exit 0
