#!/usr/bin/env bash
# install-briefing.sh — Installs the macOS LaunchAgent for briefing.sh (daily 09:00).
#
# Usage:
#   bash install-briefing.sh             # write plist only, do NOT load
#   bash install-briefing.sh --load-now  # write plist AND load immediately
#
# The LaunchAgent fires briefing.sh --once every day at 09:00.
# RunAtLoad=false prevents an immediate run on install.
#
# IMPORTANT: This file is in the Self-Mod-Blocklist (P0-0).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LABEL="com.inventory.briefing"
TEMPLATE="$ROOT/.claude/briefing-launchagent.plist.template"

# Allow env-override of target dir for testing/sandboxing.
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

# ---------------------------------------------------------------------------
# Sanity: template must exist
# ---------------------------------------------------------------------------
if [ ! -f "$TEMPLATE" ]; then
  printf 'ERROR: missing plist template: %s\n' "$TEMPLATE" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Sanity: briefing.sh must exist
# ---------------------------------------------------------------------------
BRIEFING_SH="$ROOT/.claude/scripts/briefing.sh"
if [ ! -f "$BRIEFING_SH" ]; then
  printf 'WARNING: briefing.sh not found at %s\n' "$BRIEFING_SH" >&2
  printf '  The LaunchAgent will be installed anyway, but it will not run.\n' >&2
fi

# ---------------------------------------------------------------------------
# Create target dir
# ---------------------------------------------------------------------------
mkdir -p "$LAUNCH_AGENTS_DIR"

# ---------------------------------------------------------------------------
# Create briefings log dir (logs live here per plist StandardOut/ErrPath)
# ---------------------------------------------------------------------------
mkdir -p "$ROOT/.claude/audit/briefings"

# ---------------------------------------------------------------------------
# Write plist from template
# ---------------------------------------------------------------------------
sed \
  -e "s|__REPO_ROOT__|$ROOT|g" \
  -e "s|__HOME__|$HOME|g" \
  "$TEMPLATE" > "$TARGET"

printf 'installed plist → %s\n' "$TARGET"

# ---------------------------------------------------------------------------
# Optionally load now
# ---------------------------------------------------------------------------
if [ "$LOAD_NOW" -eq 1 ]; then
  launchctl unload -w "$TARGET" 2>/dev/null || true
  launchctl load -w "$TARGET"
  printf 'LaunchAgent loaded — briefing will fire daily at 09:00.\n'
else
  printf '\n'
  printf 'NOTE: LaunchAgent installed but NOT loaded (RunAtLoad=false).\n'
  printf 'To start the briefing agent now:\n'
  printf '  launchctl load -w %s\n' "$TARGET"
  printf 'Or re-run: bash %s --load-now\n' "$(basename "$0")"
fi

# ---------------------------------------------------------------------------
# Audit + notification
# ---------------------------------------------------------------------------
AUDIT_SH="$ROOT/.claude/scripts/lib/audit.sh"
if [ -f "$AUDIT_SH" ]; then
  # shellcheck disable=SC1090
  source "$AUDIT_SH" 2>/dev/null || true
fi
if command -v audit_record >/dev/null 2>&1; then
  audit_record "install-briefing" "info" "LaunchAgent installed" \
    "load_now=$LOAD_NOW target=$TARGET" 2>/dev/null || true
fi

NOTIFY_SH="$ROOT/.claude/scripts/notify.sh"
if [ -x "$NOTIFY_SH" ]; then
  REPO_ROOT="$ROOT" "$NOTIFY_SH" info "claude-code" \
    "Briefing LaunchAgent installed" \
    "load_now=$LOAD_NOW | target=$TARGET" >/dev/null 2>&1 || true
fi

printf '\n'
printf 'controls:\n'
printf '  bash %s/.claude/scripts/uninstall-briefing.sh   # stop + remove\n' "$ROOT"
printf '  launchctl list | grep %s       # status\n' "$LABEL"
printf '  bash %s/.claude/scripts/briefing.sh --dry-run   # test without file\n' "$ROOT"
printf '  tail -f %s/.claude/audit/briefings/briefing.err.log\n' "$ROOT"
