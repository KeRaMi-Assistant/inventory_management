#!/usr/bin/env bash
# install-recovery.sh — Installs the macOS LaunchAgent for recover.sh (every 5 min).
#
# Usage:
#   bash install-recovery.sh           # write plist only, do NOT load
#   bash install-recovery.sh --load-now  # write plist AND load immediately
#
# IMPORTANT: This file is in the Self-Mod-Blocklist (P0-0).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LABEL="com.inventory.recovery"
TEMPLATE="$ROOT/.claude/recovery-launchagent.plist.template"

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
# Sanity: recover.sh must exist
# ---------------------------------------------------------------------------
RECOVER_SH="$ROOT/.claude/scripts/recover.sh"
if [ ! -f "$RECOVER_SH" ]; then
  printf 'WARNING: recover.sh not found at %s\n' "$RECOVER_SH" >&2
  printf '  The LaunchAgent will be installed anyway, but recovery will not run.\n' >&2
fi

# ---------------------------------------------------------------------------
# Create target dir
# ---------------------------------------------------------------------------
mkdir -p "$LAUNCH_AGENTS_DIR"

# ---------------------------------------------------------------------------
# Create overseer log dir
# ---------------------------------------------------------------------------
mkdir -p "$ROOT/.claude/overseer"

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
  printf 'LaunchAgent loaded — recovery watchdog will run every 5 min.\n'
else
  printf '\n'
  printf 'NOTE: LaunchAgent installed but NOT loaded (RunAtLoad=false).\n'
  printf 'To start recovery watchdog now:\n'
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
  audit_record "install-recovery" "info" "LaunchAgent installed" "load_now=$LOAD_NOW target=$TARGET" 2>/dev/null || true
fi

NOTIFY_SH="$ROOT/.claude/scripts/notify.sh"
if [ -x "$NOTIFY_SH" ]; then
  REPO_ROOT="$ROOT" "$NOTIFY_SH" info "claude-code" \
    "Recovery LaunchAgent installed" \
    "load_now=$LOAD_NOW | interval=300s | target=$TARGET" >/dev/null 2>&1 || true
fi

printf '\n'
printf 'controls:\n'
printf '  bash %s/.claude/scripts/uninstall-recovery.sh    # stop + remove\n' "$ROOT"
printf '  launchctl list | grep %s         # status\n' "$LABEL"
printf '  bash %s/.claude/scripts/recover.sh --status      # recovery counters\n' "$ROOT"
printf '  tail -f %s/.claude/overseer/recovery.err.log\n' "$ROOT"
