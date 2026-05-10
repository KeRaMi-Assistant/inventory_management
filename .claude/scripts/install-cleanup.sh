#!/usr/bin/env bash
# install-cleanup.sh — Installs the macOS LaunchAgent for cleanup.sh (daily 03:00).
#
# Usage:
#   bash install-cleanup.sh           # write plist only, do NOT load
#   bash install-cleanup.sh --load-now  # write plist AND load immediately
#
# IMPORTANT: This file is in the Self-Mod-Blocklist (P0-0).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LABEL="com.inventory.cleanup"
TEMPLATE="$ROOT/.claude/cleanup-launchagent.plist.template"

LAUNCH_AGENTS_DIR="${LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
TARGET="$LAUNCH_AGENTS_DIR/$LABEL.plist"

LOAD_NOW=0
for arg in "$@"; do
  case "$arg" in
    --load-now) LOAD_NOW=1 ;;
    *)
      printf 'Unknown argument: %s\n' "$arg" >&2
      printf 'Usage: %s [--load-now]\n' "$(basename "$0")" >&2
      exit 1
      ;;
  esac
done

if [ ! -f "$TEMPLATE" ]; then
  printf 'ERROR: missing plist template: %s\n' "$TEMPLATE" >&2
  exit 1
fi

CLEANUP_SH="$ROOT/.claude/scripts/cleanup.sh"
if [ ! -f "$CLEANUP_SH" ]; then
  printf 'WARNING: cleanup.sh not found at %s\n' "$CLEANUP_SH" >&2
fi

mkdir -p "$LAUNCH_AGENTS_DIR"

# Unload existing if loaded
if launchctl list "$LABEL" &>/dev/null 2>&1; then
  printf 'Unloading existing %s...\n' "$LABEL"
  launchctl unload "$TARGET" 2>/dev/null || true
fi

# Instantiate template
sed \
  -e "s|__REPO_ROOT__|$ROOT|g" \
  -e "s|__HOME__|$HOME|g" \
  "$TEMPLATE" > "$TARGET"

chmod 0644 "$TARGET"
printf 'Installed LaunchAgent: %s\n' "$TARGET"

if [ "$LOAD_NOW" -eq 1 ]; then
  launchctl load -w "$TARGET"
  printf 'Loaded: %s\n' "$LABEL"
  printf 'Next fire: daily at 03:00.\n'
else
  printf 'To load manually:\n'
  printf '  launchctl load -w %s\n' "$TARGET"
fi
