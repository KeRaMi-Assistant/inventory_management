#!/usr/bin/env bash
# yota-go.sh — Local CLI approval for intake pending-approvals (T26).
#
# Usage:
#   yota-go.sh <id_or_slug> [<token>]
#
# Equivalent to Telegram "go <id> <token>" reply.
# Uses local-$USER as user_id (creator-binding aware).
#
# Exit codes:
#   0 — approved and queued
#   1 — error
#   2 — no pending approval found
#   3 — creator-binding mismatch
#   4 — token mismatch

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

# Source shared intake-actions lib
LIB="${SCRIPT_DIR}/lib/intake-actions.sh"
if [ ! -f "$LIB" ]; then
  printf 'yota-go: ERROR: lib/intake-actions.sh not found at %s\n' "$LIB" >&2
  exit 1
fi
# shellcheck source=lib/intake-actions.sh
source "$LIB"

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  printf 'Usage: yota-go.sh <id_or_slug> [<token>]\n' >&2
  exit 0
fi

if [ $# -lt 1 ]; then
  printf 'Usage: yota-go.sh <id_or_slug> [<token>]\n' >&2
  exit 1
fi

ID_OR_SLUG="$1"
TOKEN="${2:-}"
USER_ID="local-${USER:-$(id -un 2>/dev/null || echo unknown)}"

intake_go "$ID_OR_SLUG" "$TOKEN" "$USER_ID"
RC=$?

case $RC in
  0) printf '[yota-go] ✅ approved: %s\n' "$ID_OR_SLUG" ;;
  2) printf '[yota-go] no pending approval found for: %s\n' "$ID_OR_SLUG" >&2 ;;
  3) printf '[yota-go] creator-binding mismatch (not your proposal)\n' >&2 ;;
  4) printf '[yota-go] token mismatch\n' >&2 ;;
  *) printf '[yota-go] failed (rc=%d)\n' "$RC" >&2 ;;
esac

exit $RC
