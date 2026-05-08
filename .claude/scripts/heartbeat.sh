#!/usr/bin/env bash
# Heartbeat: pusht alle 10 Minuten via ntfy.sh den aktuellen Status der
# headless-Pipeline. Liest .current_task (vom headless-runner geschrieben)
# und meldet: aktiver Task + Laufzeit, oder "idle".
#
# Aufruf als Daemon:
#   nohup bash .claude/scripts/heartbeat.sh > .claude/backlog/runs/heartbeat.log 2>&1 &
#   echo $! > .claude/backlog/.heartbeat.pid
#
# Stoppen:
#   kill "$(cat .claude/backlog/.heartbeat.pid)" && rm .claude/backlog/.heartbeat.pid

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE="$ROOT/.claude/backlog/.current_task"
INBOX="$ROOT/.claude/backlog/inbox"
DONE_DIR="$ROOT/.claude/backlog/done"
FAILED_DIR="$ROOT/.claude/backlog/failed"
NOTIFY="$ROOT/.claude/scripts/notify.sh"
INTERVAL="${HEARTBEAT_INTERVAL:-600}"  # 10 Min Default

# .env.headless laden (für NTFY_TOPIC)
if [ -f "$ROOT/.env.headless" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/.env.headless"
  set +a
fi

if [ -z "${NTFY_TOPIC:-}" ]; then
  echo "[heartbeat] NTFY_TOPIC not set in .env.headless — exiting."
  exit 1
fi

format_duration() {
  local sec="$1"
  local h=$((sec / 3600))
  local m=$(((sec % 3600) / 60))
  local s=$((sec % 60))
  if [ "$h" -gt 0 ]; then
    printf '%dh%02dm' "$h" "$m"
  elif [ "$m" -gt 0 ]; then
    printf '%dm%02ds' "$m" "$s"
  else
    printf '%ds' "$s"
  fi
}

echo "[heartbeat] started, interval=${INTERVAL}s, ntfy=${NTFY_TOPIC}"

while true; do
  INBOX_COUNT="$(find "$INBOX" -maxdepth 1 -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
  DONE_TODAY="$(find "$DONE_DIR" -maxdepth 1 -type f -name '*.md' -newermt "$(date -u +%Y-%m-%d)" 2>/dev/null | wc -l | tr -d ' ')"
  FAILED_TODAY="$(find "$FAILED_DIR" -maxdepth 1 -type f -name '*.md' -newermt "$(date -u +%Y-%m-%d)" 2>/dev/null | wc -l | tr -d ' ')"

  if [ -f "$STATE" ]; then
    SLUG="$(awk -F= '$1=="slug"{print substr($0, length($1)+2)}' "$STATE")"
    STARTED="$(awk -F= '$1=="started"{print $2}' "$STATE")"
    BRANCH="$(awk -F= '$1=="branch"{print substr($0, length($1)+2)}' "$STATE")"
    NOW="$(date -u +%s)"
    ELAPSED=$((NOW - STARTED))
    DURATION="$(format_duration "$ELAPSED")"
    TITLE="🔧 Task läuft: $SLUG"
    BODY="Seit $DURATION auf $BRANCH. Inbox: $INBOX_COUNT offen, $DONE_TODAY done, $FAILED_TODAY failed (heute)."
    "$NOTIFY" "$TITLE" "$BODY" info
    echo "[heartbeat $(date -u +%H:%M:%S)] active: $SLUG ($DURATION) — $BODY"
  else
    if [ "$INBOX_COUNT" -gt 0 ]; then
      TITLE="💤 Pipeline idle"
      BODY="$INBOX_COUNT Tasks warten in Inbox, kein aktiver Task. $DONE_TODAY done, $FAILED_TODAY failed (heute)."
    else
      TITLE="✅ Backlog leer"
      BODY="Inbox ist leer. $DONE_TODAY done, $FAILED_TODAY failed (heute)."
    fi
    "$NOTIFY" "$TITLE" "$BODY" info
    echo "[heartbeat $(date -u +%H:%M:%S)] idle — $BODY"
  fi

  sleep "$INTERVAL"
done
