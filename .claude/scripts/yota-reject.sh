#!/usr/bin/env bash
# yota-reject.sh — Local CLI rejection for intake pending-approvals (T26).
#
# Usage:
#   yota-reject.sh <id_or_slug> [<reason>]
#
# Equivalent to Telegram "reject <id> <reason>" reply.
# Uses local-$USER as user_id (creator-binding aware).
#
# Exit codes:
#   0 — rejected
#   1 — error
#   2 — no pending approval found
#   3 — creator-binding mismatch

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

LIB="${SCRIPT_DIR}/lib/intake-actions.sh"
if [ ! -f "$LIB" ]; then
  printf 'yota-reject: ERROR: lib/intake-actions.sh not found at %s\n' "$LIB" >&2
  exit 1
fi
# shellcheck source=lib/intake-actions.sh
source "$LIB"

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  printf 'Usage: yota-reject.sh <id_or_slug> [<reason>]\n' >&2
  exit 0
fi

if [ $# -lt 1 ]; then
  printf 'Usage: yota-reject.sh <id_or_slug> [<reason>]\n' >&2
  exit 1
fi

ID_OR_SLUG="$1"
REASON="${2:-}"
USER_ID="local-${USER:-$(id -un 2>/dev/null || echo unknown)}"

intake_reject "$ID_OR_SLUG" "$REASON" "$USER_ID"
RC=$?

case $RC in
  0) printf '[yota-reject] ❌ rejected: %s\n' "$ID_OR_SLUG" ;;
  2) printf '[yota-reject] no pending approval found for: %s\n' "$ID_OR_SLUG" >&2 ;;
  3) printf '[yota-reject] creator-binding mismatch (not your proposal)\n' >&2 ;;
  *) printf '[yota-reject] failed (rc=%d)\n' "$RC" >&2 ;;
esac

exit $RC
