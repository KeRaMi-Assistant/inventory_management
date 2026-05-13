#!/usr/bin/env bash
# install-live-status.sh — Installs the live-status daemon as a LaunchAgent.
# Runs every 60s, writes .claude/overseer/LIVE_STATUS.md.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LAUNCH_AGENTS_DIR="${LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
TEMPLATE="$REPO_ROOT/.claude/live-status-launchagent.plist.template"
TARGET="$LAUNCH_AGENTS_DIR/com.inventory.live-status.plist"

mkdir -p "$LAUNCH_AGENTS_DIR"

sed "s|__REPO_ROOT__|$REPO_ROOT|g" "$TEMPLATE" > "$TARGET"
echo "installed plist → $TARGET"

# Validate
if command -v plutil >/dev/null 2>&1; then
  plutil -lint "$TARGET" >/dev/null
fi

# Load (with --load-now flag or by default)
if [ "${1:-}" = "--load-now" ] || [ -z "${1:-}" ]; then
  launchctl unload "$TARGET" 2>/dev/null || true
  launchctl load -w "$TARGET"
  echo "LaunchAgent loaded — live-status updates every 60s."
  echo ""
  echo "Status file: $REPO_ROOT/.claude/overseer/LIVE_STATUS.md"
  echo "Logs:        $REPO_ROOT/.claude/overseer/live-status.{out,err}.log"
fi
