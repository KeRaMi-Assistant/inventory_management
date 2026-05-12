#!/usr/bin/env bash
# install-yota-watch.sh — Installiert macOS LaunchAgent für yota-watch.sh (15min).
#
# Usage:
#   bash install-yota-watch.sh             # write plist only, do NOT load
#   bash install-yota-watch.sh --load-now  # write plist AND load immediately

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LABEL="com.inventory.yota-watch"
TEMPLATE="$ROOT/.claude/yota-watch-launchagent.plist.template"

LAUNCH_AGENTS_DIR="${LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
TARGET="$LAUNCH_AGENTS_DIR/$LABEL.plist"

LOAD_NOW=0
for arg in "$@"; do
  case "$arg" in
    --load-now) LOAD_NOW=1 ;;
    *)
      printf 'Usage: %s [--load-now]\n' "$(basename "$0")" >&2
      exit 1
      ;;
  esac
done

[ -f "$TEMPLATE" ] || { printf 'ERROR: missing template: %s\n' "$TEMPLATE" >&2; exit 1; }

mkdir -p "$LAUNCH_AGENTS_DIR"
mkdir -p "$ROOT/.claude/audit"

sed \
  -e "s|__REPO_ROOT__|$ROOT|g" \
  -e "s|__HOME__|$HOME|g" \
  "$TEMPLATE" > "$TARGET"

printf 'installed plist → %s\n' "$TARGET"

if [ "$LOAD_NOW" -eq 1 ]; then
  launchctl unload -w "$TARGET" 2>/dev/null || true
  launchctl load -w "$TARGET"
  printf 'LaunchAgent loaded — yota-watch fires every 15min.\n'
else
  printf 'Run with --load-now to activate. Stop later via uninstall-yota-watch.sh.\n'
fi
