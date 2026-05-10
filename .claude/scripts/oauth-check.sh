#!/usr/bin/env bash
# oauth-check.sh — CLI wrapper for oauth-check library.
#
# Usage:
#   bash .claude/scripts/oauth-check.sh [--silent] [--json]
#
# Flags:
#   (none)     : human-readable summary + exit code
#   --silent   : no stdout output, only exit code
#   --json     : print oauth-status.json to stdout after check
#
# Exit codes:
#   0 = all services ok
#   1 = one or more non-critical issues (gh/supabase)
#   2 = anthropic token expired (Overseer pause signal)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$SCRIPT_DIR/lib/oauth-check.sh"

if [ ! -f "$LIB" ]; then
  printf '[oauth-check] ERROR: library not found: %s\n' "$LIB" >&2
  exit 1
fi

# shellcheck disable=SC1090
. "$LIB"

# Parse flags
_silent=0
_json=0
for _arg in "$@"; do
  case "$_arg" in
    --silent) _silent=1 ;;
    --json)   _json=1   ;;
    *)
      printf '[oauth-check] Unknown flag: %s\n' "$_arg" >&2
      exit 1
      ;;
  esac
done

# Run all checks
_exit_code=0
oauth_check_all || _exit_code=$?

# Output
if [ "$_silent" -eq 0 ]; then
  _status_file="$_OAUTH_REPO_ROOT/.claude/overseer/oauth-status.json"
  if [ "$_json" -eq 1 ]; then
    if [ -f "$_status_file" ]; then
      cat "$_status_file"
    else
      printf '{"error":"oauth-status.json not found"}\n'
    fi
  else
    printf '[oauth-check] Done. Status:\n'
    if [ -f "$_status_file" ]; then
      cat "$_status_file"
    fi
    case "$_exit_code" in
      0) printf '[oauth-check] All services OK.\n' ;;
      1) printf '[oauth-check] WARNING: one or more non-critical issues (see above).\n' ;;
      2) printf '[oauth-check] CRITICAL: Anthropic token expired — Overseer should pause!\n' ;;
    esac
  fi
fi

exit "$_exit_code"
