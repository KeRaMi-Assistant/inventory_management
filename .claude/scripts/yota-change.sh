#!/usr/bin/env bash
# yota-change.sh — Local CLI change-request for intake pending-approvals (T26).
#
# Usage:
#   yota-change.sh <id_or_slug> <text>
#
# Equivalent to Telegram "change <id> <text>" reply.
# Creates round+1 pending-proposal, re-spawns council.
# Uses local-$USER as user_id (creator-binding aware).
#
# Exit codes:
#   0 — change applied, new round started
#   1 — error
#   2 — no pending approval found
#   3 — creator-binding mismatch
#   5 — max rounds reached

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

LIB="${SCRIPT_DIR}/lib/intake-actions.sh"
if [ ! -f "$LIB" ]; then
  printf 'yota-change: ERROR: lib/intake-actions.sh not found at %s\n' "$LIB" >&2
  exit 1
fi
# shellcheck source=lib/intake-actions.sh
source "$LIB"

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  printf 'Usage: yota-change.sh <id_or_slug> <text>\n' >&2
  exit 0
fi

if [ $# -lt 2 ]; then
  printf 'Usage: yota-change.sh <id_or_slug> <text>\n' >&2
  exit 1
fi

ID_OR_SLUG="$1"
shift
TEXT="$*"
USER_ID="local-${USER:-$(id -un 2>/dev/null || echo unknown)}"

intake_change "$ID_OR_SLUG" "$TEXT" "$USER_ID"
RC=$?

case $RC in
  0) printf '[yota-change] 🔄 change applied, new round started: %s\n' "$ID_OR_SLUG" ;;
  2) printf '[yota-change] no pending approval found for: %s\n' "$ID_OR_SLUG" >&2 ;;
  3) printf '[yota-change] creator-binding mismatch (not your proposal)\n' >&2 ;;
  5) printf '[yota-change] max rounds reached — use yota-go.sh or yota-reject.sh\n' >&2 ;;
  *) printf '[yota-change] failed (rc=%d)\n' "$RC" >&2 ;;
esac

exit $RC
