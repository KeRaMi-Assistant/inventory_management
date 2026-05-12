#!/usr/bin/env bash
# install-telegram-bot.sh — Installs the macOS LaunchAgent for telegram-bot.py.
#
# The bot is a long-poll daemon — KeepAlive=true, auto-restart on crash.
# It loads .env.headless at process start (TELEGRAM_BOT_TOKEN +
# TELEGRAM_ALLOWED_USER_IDS must live there).
#
# Usage:
#   bash install-telegram-bot.sh           # write plist only
#   bash install-telegram-bot.sh --load-now  # write plist AND launchctl load

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LABEL="com.inventory.telegram-bot"
TEMPLATE="$ROOT/.claude/telegram-bot-launchagent.plist.template"

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
# Sanity: template + script must exist
# ---------------------------------------------------------------------------
if [ ! -f "$TEMPLATE" ]; then
  printf 'ERROR: missing plist template: %s\n' "$TEMPLATE" >&2
  exit 1
fi

BOT_PY="$ROOT/.claude/scripts/telegram-bot.py"
if [ ! -f "$BOT_PY" ]; then
  printf 'ERROR: telegram-bot.py not found at %s\n' "$BOT_PY" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Pre-check: TELEGRAM_BOT_TOKEN + TELEGRAM_ALLOWED_USER_IDS must be in
# .env.headless OR current env.
# ---------------------------------------------------------------------------
ENV_FILE="$ROOT/.env.headless"

_have_var() {
  local name="$1"
  if [ -n "${!name:-}" ]; then return 0; fi
  if [ -f "$ENV_FILE" ] && grep -qE "^${name}=" "$ENV_FILE"; then return 0; fi
  return 1
}

MISSING=()
_have_var TELEGRAM_BOT_TOKEN       || MISSING+=("TELEGRAM_BOT_TOKEN")
_have_var TELEGRAM_ALLOWED_USER_IDS || MISSING+=("TELEGRAM_ALLOWED_USER_IDS")

if [ ${#MISSING[@]} -gt 0 ]; then
  printf 'ERROR: missing required config: %s\n' "${MISSING[*]}" >&2
  printf '\n' >&2
  printf 'Setup steps:\n' >&2
  printf '  1) Telegram: @BotFather  → /newbot → copy token\n' >&2
  printf '  2) Telegram: @userinfobot → your numeric user-id\n' >&2
  printf '  3) Append to %s :\n' "$ENV_FILE" >&2
  printf '       TELEGRAM_BOT_TOKEN=123:ABC...\n' >&2
  printf '       TELEGRAM_ALLOWED_USER_IDS=987654321\n' >&2
  printf '  4) re-run this script with --load-now\n' >&2
  printf '\n' >&2
  printf 'See .claude/scripts/SETUP_TELEGRAM.md for full guide.\n' >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Prepare dirs
# ---------------------------------------------------------------------------
mkdir -p "$LAUNCH_AGENTS_DIR"
mkdir -p "$ROOT/.claude/overseer"
mkdir -p "$ROOT/.claude/overseer/state"

# ---------------------------------------------------------------------------
# Write plist
# ---------------------------------------------------------------------------
sed \
  -e "s|__REPO_ROOT__|$ROOT|g" \
  -e "s|__HOME__|$HOME|g" \
  "$TEMPLATE" > "$TARGET"

# Validate
if command -v plutil >/dev/null 2>&1; then
  if ! plutil -lint "$TARGET" >/dev/null; then
    printf 'ERROR: plist failed plutil -lint\n' >&2
    exit 1
  fi
fi

printf 'installed plist → %s\n' "$TARGET"

# ---------------------------------------------------------------------------
# Optionally load now
# ---------------------------------------------------------------------------
if [ "$LOAD_NOW" -eq 1 ]; then
  launchctl unload -w "$TARGET" 2>/dev/null || true
  launchctl load -w "$TARGET"
  printf 'LaunchAgent loaded — telegram-bot daemon is now running (KeepAlive=true).\n'
else
  printf '\n'
  printf 'NOTE: LaunchAgent installed but NOT loaded.\n'
  printf 'To start now:\n'
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
  audit_record "install-telegram-bot" "info" "LaunchAgent installed" \
    "load_now=$LOAD_NOW target=$TARGET" 2>/dev/null || true
fi

NOTIFY_SH="$ROOT/.claude/scripts/notify.sh"
if [ -x "$NOTIFY_SH" ]; then
  REPO_ROOT="$ROOT" "$NOTIFY_SH" info "claude-code" \
    "Telegram-Bot LaunchAgent installed" \
    "load_now=$LOAD_NOW | target=$TARGET" >/dev/null 2>&1 || true
fi

printf '\n'
printf 'controls:\n'
printf '  bash %s/.claude/scripts/uninstall-telegram-bot.sh    # stop + remove\n' "$ROOT"
printf '  launchctl list | grep %s    # status\n' "$LABEL"
printf '  tail -f %s/.claude/overseer/telegram-bot.err.log\n' "$ROOT"
