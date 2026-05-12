#!/usr/bin/env bash
# api-key-preflight.sh — Sourceable library: ANTHROPIC_API_KEY pre-flight check.
#
# Usage: source this file, then call:
#   check_no_api_key
#
# Background: when ANTHROPIC_API_KEY env-var is set, `claude --print` dispatches
# through the Anthropic API (pay-per-token) instead of Max-Plan-Quota.
# This is Anthropic issue #39903. Any script that calls `claude --print` must
# abort loudly when the key is set to avoid unexpected billing.
#
# Audit action written on block: intake_api_key_blocked
#
# Optional soft warning: if ~/.anthropic/auth.json (Max-Plan OAuth token) is
# absent, a warning is printed to stderr (no exit).

# Deliberately NO set -e — sourceable library.
set -uo pipefail

# ---------------------------------------------------------------------------
# Internal: resolve repo root
# ---------------------------------------------------------------------------
_apk_resolve_repo_root() {
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
    printf '%s' "$CLAUDE_PROJECT_DIR"
    return
  fi
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

_APK_REPO_ROOT="$(_apk_resolve_repo_root)"
_APK_AUDIT_LIB="$_APK_REPO_ROOT/.claude/scripts/lib/audit.sh"

# Load audit library if available
_apk_audit_available=0
if [ -f "$_APK_AUDIT_LIB" ]; then
  # shellcheck disable=SC1090
  . "$_APK_AUDIT_LIB"
  _apk_audit_available=1
fi

_apk_audit() {
  local action="$1"
  local subject="${2:-api-key-preflight}"
  local reason="${3:-}"
  if [ "$_apk_audit_available" -eq 1 ]; then
    audit_record "api-key-preflight" "$action" "$subject" "$reason" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# check_no_api_key
#
# Exits 1 with clear stderr message when ANTHROPIC_API_KEY is non-empty.
# Returns 0 silently when the variable is unset or empty.
# Optional soft warning when Max-Plan OAuth token file is absent.
# ---------------------------------------------------------------------------
check_no_api_key() {
  # --- Hard block: API key set ---
  if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    cat >&2 <<'EOF'
[api-key-preflight] FATAL: ANTHROPIC_API_KEY environment variable is set.

This script uses `claude --print` which would route through API billing
(pay-per-token) instead of Max-Plan-Quota. This is the Anthropic bug #39903
behavior. To proceed:

  unset ANTHROPIC_API_KEY
  bash <this-script>

Audit-Eintrag: intake_api_key_blocked
EOF
    _apk_audit "intake_api_key_blocked" "ANTHROPIC_API_KEY" "ANTHROPIC_API_KEY env set"
    exit 1
  fi

  # --- Soft warning: Max-Plan OAuth token absent ---
  local _auth_file="${HOME}/.anthropic/auth.json"
  if [ ! -f "$_auth_file" ]; then
    printf '[api-key-preflight] WARNING: Max-Plan OAuth token not found at %s — claude --print might fail.\n' \
      "$_auth_file" >&2
  fi

  return 0
}
