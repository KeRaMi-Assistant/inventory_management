#!/usr/bin/env bash
# lib/cache-friendly-invoke.sh — Cache-friendly helper for claude --print invocations.
#
# Anthropic's Prompt-Cache holds static system-prompts (subagent definitions) for
# 5 min TTL → ~90% cost reduction + ~85% latency reduction on repeated agent calls.
#
# KEY RULE: User-input MUST arrive at the PROMPT-END (via stdin or -p at the end).
# Prepending dynamic content BEFORE the agent body invalidates the cache.
#
# Usage:
#   source .claude/scripts/lib/cache-friendly-invoke.sh
#
#   # Option A: stdin pipe (preferred when input is multi-line)
#   printf '%s' "$user_input" | invoke_agent_cached <agent> <budget_usd>
#
#   # Option B: positional arg (short single-line prompts)
#   invoke_agent_cached <agent> <budget_usd> "<user_input>"
#
# Returns the claude exit code. Stdout = claude output.

CACHE_FRIENDLY_LIB_VERSION="1.0.0"

# ---------------------------------------------------------------------------
# invoke_agent_cached <agent-name> <budget-usd> [user-input]
#
# If user-input is provided as $3, it is piped to claude via stdin.
# If omitted, the function reads from its own stdin (caller must pipe).
# ---------------------------------------------------------------------------
invoke_agent_cached() {
  local agent="${1:?invoke_agent_cached: agent-name required}"
  local budget="${2:?invoke_agent_cached: budget-usd required}"
  local user_input="${3:-}"

  # Validate agent name (no path traversal, no spaces)
  if [[ "$agent" =~ [[:space:]/\\] ]]; then
    printf 'invoke_agent_cached: invalid agent name: %s\n' "$agent" >&2
    return 1
  fi

  # Build base args — model and permission-mode are NOT prepended dynamically;
  # they are fixed per invocation so cache stays stable.
  local claude_args=(
    --print
    --permission-mode auto
    --max-budget-usd "$budget"
    --agent "$agent"
  )

  if [ -n "$user_input" ]; then
    # Deliver user input via -p (appended AFTER the agent body → cache-friendly)
    claude "${claude_args[@]}" -p "$user_input"
  else
    # Deliver user input via stdin (also cache-friendly: body comes first)
    claude "${claude_args[@]}"
  fi
}

# ---------------------------------------------------------------------------
# _validate_cache_friendly_invocation <full-claude-command-string>
#
# Checks whether a given claude command string is cache-friendly.
# Prints a warning to stderr and returns 1 if a cache-busting pattern is detected.
#
# Heuristics checked:
#   1. Dynamic content (variable interpolation) appears before --agent flag.
#   2. --agent flag is missing entirely (no agent = no cached system-prompt).
#   3. User-input string appears before the agent flag positionally.
#
# Note: This is a heuristic, not a guarantee. It catches common mistakes.
# ---------------------------------------------------------------------------
_validate_cache_friendly_invocation() {
  local cmd="${1:?_validate_cache_friendly_invocation: command string required}"
  local ok=0

  # Must contain --agent or --print --agent
  if ! echo "$cmd" | grep -q -- '--agent'; then
    printf '[cache-warn] No --agent flag found — no static system-prompt to cache.\n' >&2
    ok=1
  fi

  # Warn if -p / --print appears with content BEFORE --agent
  # Pattern: "-p '...'" or '--print "..."' occurring before '--agent'
  local before_agent
  before_agent="$(echo "$cmd" | sed 's/--agent.*//')"
  if echo "$before_agent" | grep -qE -- '-p ["\x27]|--print ["\x27]'; then
    printf '[cache-warn] Inline prompt (-p) appears BEFORE --agent — this may prepend dynamic\n' >&2
    printf '             content before the system-prompt and bust the cache.\n' >&2
    printf '             Move user-input to AFTER --agent, or pipe via stdin.\n' >&2
    ok=1
  fi

  return $ok
}
