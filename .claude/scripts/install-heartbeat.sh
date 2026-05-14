#!/usr/bin/env bash
# install-heartbeat.sh — Installs the heartbeat daemon as a macOS LaunchAgent.
#
# The daemon runs persistently (KeepAlive=true) and uses a Singleton-Lock
# internally — multiple invocations exit silently. Activity-Detection in
# heartbeat.sh ensures pushes only happen when the swarm is actually doing
# something (worker active, inbox > 0, recent failures, PANIC marker, etc.).
#
# Usage:
#   bash .claude/scripts/install-heartbeat.sh             # install + load
#   bash .claude/scripts/install-heartbeat.sh --load-now  # alias (explicit)
#   bash .claude/scripts/install-heartbeat.sh --uninstall # stop + remove

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LAUNCH_AGENTS_DIR="${LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
TEMPLATE="$REPO_ROOT/.claude/heartbeat-launchagent.plist.template"
TARGET="$LAUNCH_AGENTS_DIR/com.inventory.heartbeat.plist"

# Uninstall path
if [ "${1:-}" = "--uninstall" ]; then
  if [ -f "$TARGET" ]; then
    launchctl unload "$TARGET" 2>/dev/null || true
    rm -f "$TARGET"
    echo "uninstalled: $TARGET"
  else
    echo "not installed: $TARGET"
  fi
  # Defensive stray kill via the script's own --stop
  bash "$REPO_ROOT/.claude/scripts/heartbeat.sh" --stop 2>/dev/null || true
  exit 0
fi

mkdir -p "$LAUNCH_AGENTS_DIR"

if [ ! -f "$TEMPLATE" ]; then
  echo "ERROR: template not found: $TEMPLATE" >&2
  exit 2
fi

# Substitute REPO_ROOT + USER_HOME into the template
sed -e "s|__REPO_ROOT__|$REPO_ROOT|g" \
    -e "s|__USER_HOME__|$HOME|g" \
    "$TEMPLATE" > "$TARGET"

echo "installed plist → $TARGET"

# Validate
if command -v plutil >/dev/null 2>&1; then
  plutil -lint "$TARGET" >/dev/null
fi

# Stop any stray heartbeat first (defensive — old script might still run)
bash "$REPO_ROOT/.claude/scripts/heartbeat.sh" --stop 2>/dev/null || true

# Reload
launchctl unload "$TARGET" 2>/dev/null || true
launchctl load -w "$TARGET"

echo "LaunchAgent loaded — heartbeat runs persistently."
echo ""
echo "Logs:        $REPO_ROOT/.claude/overseer/heartbeat.{out,err}.log"
echo "Lock:        $REPO_ROOT/.claude/overseer/.heartbeat.lock"
echo "Stop:        bash $REPO_ROOT/.claude/scripts/heartbeat.sh --stop"
echo "Uninstall:   bash $REPO_ROOT/.claude/scripts/install-heartbeat.sh --uninstall"
