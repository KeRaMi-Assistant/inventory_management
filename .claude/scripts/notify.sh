#!/usr/bin/env bash
# Notification-Helper. Default: macOS osascript. Optional: ntfy.sh push.
# Usage: notify.sh "Title" "Body" [success|failure|info]
#
# Env-Vars:
#   NTFY_TOPIC — falls gesetzt, wird zusätzlich an ntfy.sh/$TOPIC gepusht.

set -euo pipefail

# Auto-load .env.headless if invoked standalone — runner already loads it,
# but direct invocations (`bash notify.sh ...`) won't have NTFY_TOPIC otherwise.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../../.env.headless"
if [ -z "${NTFY_TOPIC:-}" ] && [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi

TITLE="${1:-Claude}"
BODY="${2:-}"
KIND="${3:-info}"

case "$KIND" in
  success) SOUND="Glass"; PRIO="default" ;;
  failure) SOUND="Basso"; PRIO="high" ;;
  *)       SOUND="Pop";   PRIO="low" ;;
esac

# macOS native — nutzt osascript; failed silent wenn nicht macOS.
if command -v osascript >/dev/null 2>&1; then
  # Escape double-quotes for AppleScript
  SAFE_TITLE="$(printf '%s' "$TITLE" | sed 's/"/\\"/g')"
  SAFE_BODY="$(printf '%s' "$BODY" | sed 's/"/\\"/g')"
  osascript -e "display notification \"$SAFE_BODY\" with title \"$SAFE_TITLE\" sound name \"$SOUND\"" 2>/dev/null || true
fi

# Optional: ntfy.sh push (für Mobile-Notifications, kostenlos, kein Account)
if [ -n "${NTFY_TOPIC:-}" ]; then
  curl -fsSL \
    -H "Title: $TITLE" \
    -H "Priority: $PRIO" \
    -H "Tags: claude-code" \
    -d "$BODY" \
    "https://ntfy.sh/$NTFY_TOPIC" >/dev/null 2>&1 || true
fi

exit 0
