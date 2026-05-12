#!/usr/bin/env bash
# uninstall-telegram-bot.sh — Stops + removes the telegram-bot LaunchAgent.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LABEL="com.inventory.telegram-bot"
LAUNCH_AGENTS_DIR="${LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
TARGET="$LAUNCH_AGENTS_DIR/$LABEL.plist"

if [ -f "$TARGET" ]; then
  launchctl unload -w "$TARGET" 2>/dev/null || true
  rm -f "$TARGET"
  printf 'removed plist → %s\n' "$TARGET"
else
  printf 'no plist found at %s — nothing to remove\n' "$TARGET"
fi

AUDIT_SH="$ROOT/.claude/scripts/lib/audit.sh"
if [ -f "$AUDIT_SH" ]; then
  # shellcheck disable=SC1090
  source "$AUDIT_SH" 2>/dev/null || true
fi
if command -v audit_record >/dev/null 2>&1; then
  audit_record "uninstall-telegram-bot" "info" "LaunchAgent removed" \
    "target=$TARGET" 2>/dev/null || true
fi
