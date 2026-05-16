#!/usr/bin/env bash
# yota-live.sh — Live-Terminal-Display der Autonomous Council Swarm Activity.
#
# Loop: clear-screen + yota-snapshot.sh --human, alle X Sekunden.
# Bei All-Done (workers=0 UND backlog=0 UND stakeholder=0): "Heute fertig"-Mode.
# Exit via Ctrl+C.
#
# Override via ENV:
#   YOTA_LIVE_INTERVAL=5    Refresh-Intervall in Sekunden (default 2)
#   YOTA_LIVE_DONE_LIMIT=10 Wie viele done-Items im Idle-Mode (default 10)
#   YOTA_LIVE_NO_COLOR=1    Farben deaktivieren
#
# Usage:
#   bash .claude/scripts/yota-live.sh
#   YOTA_LIVE_INTERVAL=1 bash .claude/scripts/yota-live.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

INTERVAL="${YOTA_LIVE_INTERVAL:-2}"
DONE_LIMIT="${YOTA_LIVE_DONE_LIMIT:-10}"

# Validate interval (must be positive integer)
if ! [[ "$INTERVAL" =~ ^[1-9][0-9]*$ ]]; then
  printf 'yota-live: YOTA_LIVE_INTERVAL muss positive Integer sein (got: %s)\n' "$INTERVAL" >&2
  exit 1
fi

# Colors
if [ -t 1 ] && [ -z "${YOTA_LIVE_NO_COLOR:-}" ] && command -v tput >/dev/null 2>&1; then
  BOLD="$(tput bold 2>/dev/null || true)"
  DIM="$(tput dim 2>/dev/null || true)"
  GREEN="$(tput setaf 2 2>/dev/null || true)"
  YELLOW="$(tput setaf 3 2>/dev/null || true)"
  RED="$(tput setaf 1 2>/dev/null || true)"
  CYAN="$(tput setaf 6 2>/dev/null || true)"
  RESET="$(tput sgr0 2>/dev/null || true)"
else
  BOLD=""; DIM=""; GREEN=""; YELLOW=""; RED=""; CYAN=""; RESET=""
fi

cleanup() {
  printf '\n%sYota-Live beendet.%s\n' "$DIM" "$RESET"
  exit 0
}
trap cleanup INT TERM

clear_screen() {
  # ANSI clear + home (funktioniert in Terminal.app, iTerm, tmux, screen)
  printf '\033[2J\033[H'
}

print_header() {
  local ts
  ts="$(date '+%H:%M:%S')"
  printf '%s%s═══ Yota Live ═══%s  %s%s · refresh %ds%s\n\n' \
    "$BOLD" "$CYAN" "$RESET" "$DIM" "$ts" "$INTERVAL" "$RESET"
}

print_footer() {
  printf '\n%s─────────────────────────────────────%s\n' "$DIM" "$RESET"
  printf '%sCtrl+C zum Beenden · YOTA_LIVE_INTERVAL=%s%s\n' "$DIM" "$INTERVAL" "$RESET"
}

# Parse snapshot JSON, set globals: $STATUS $WORKERS_ACTIVE $BACKLOG $STAKEHOLDER $IN_PROGRESS $DONE_TODAY
read_snapshot_state() {
  local json
  json="$(bash "$SCRIPT_DIR/yota-snapshot.sh" 2>/dev/null)"
  if [ -z "$json" ]; then
    STATUS="unknown"; WORKERS_ACTIVE=0; BACKLOG=0; STAKEHOLDER=0; IN_PROGRESS=0; DONE_TODAY=0
    return
  fi
  local parsed
  parsed="$(printf '%s' "$json" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get("status", "unknown"))
    print(d.get("workers", {}).get("active", 0))
    print(d.get("inbox", {}).get("backlog", 0))
    print(d.get("inbox", {}).get("stakeholder", 0))
    print(d.get("inbox", {}).get("in_progress", 0))
    print(d.get("inbox", {}).get("done_today", 0))
except Exception:
    print("unknown"); print(0); print(0); print(0); print(0); print(0)
' 2>/dev/null)"
  STATUS="$(printf '%s' "$parsed" | sed -n '1p')"
  WORKERS_ACTIVE="$(printf '%s' "$parsed" | sed -n '2p')"
  BACKLOG="$(printf '%s' "$parsed" | sed -n '3p')"
  STAKEHOLDER="$(printf '%s' "$parsed" | sed -n '4p')"
  IN_PROGRESS="$(printf '%s' "$parsed" | sed -n '5p')"
  DONE_TODAY="$(printf '%s' "$parsed" | sed -n '6p')"
  STATUS="${STATUS:-unknown}"
  WORKERS_ACTIVE="${WORKERS_ACTIVE:-0}"
  BACKLOG="${BACKLOG:-0}"
  STAKEHOLDER="${STAKEHOLDER:-0}"
  IN_PROGRESS="${IN_PROGRESS:-0}"
  DONE_TODAY="${DONE_TODAY:-0}"
}

# Liefert die letzten N done-Slugs (heute zuerst)
list_done_today() {
  local limit="$1"
  local count=0
  local today_y today_m today_d
  today_y="$(date '+%Y')"; today_m="$(date '+%m')"; today_d="$(date '+%d')"

  # macOS-kompatibel: -newermt funktioniert via BSD find
  local since_date="${today_y}-${today_m}-${today_d}"

  for dir in "$REPO_ROOT/.claude/overseer/done" "$REPO_ROOT/.claude/backlog/done"; do
    [ -d "$dir" ] || continue
    while IFS= read -r f; do
      [ -f "$f" ] || continue
      [ "$count" -ge "$limit" ] && return
      local slug
      slug="$(basename "$f" .md)"
      printf '  %s✓%s %s\n' "$GREEN" "$RESET" "$slug"
      count=$((count + 1))
    done < <(find "$dir" -name "*.md" -newermt "$since_date" -type f 2>/dev/null | sort -r)
  done

  if [ "$count" -eq 0 ]; then
    printf '  %s(noch nichts heute)%s\n' "$DIM" "$RESET"
  fi
}

print_done_summary() {
  printf '\n%s%s✓ Alles fertig — kein laufender Agent, leere Inbox.%s\n\n' "$BOLD" "$GREEN" "$RESET"
  printf '%sHeute erledigt:%s\n' "$BOLD" "$RESET"
  list_done_today "$DONE_LIMIT"
}

print_worker_detail() {
  # Zeigt aktive Worker als Liste (aus snapshot details[])
  local json
  json="$(bash "$SCRIPT_DIR/yota-snapshot.sh" 2>/dev/null)"
  printf '%s' "$json" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    details = d.get("workers", {}).get("details", []) or []
    if not details:
        sys.exit(0)
    print()
    print("Aktive Worker:")
    for w in details[:5]:
        slug = w.get("slug", "?")
        agent = w.get("agent", "?")
        elapsed = w.get("elapsed_s", "?")
        print(f"  → {slug} ({agent}, {elapsed}s)")
except Exception:
    pass
' 2>/dev/null
}

is_idle() {
  [ "$STATUS" = "idle" ] \
    && [ "$WORKERS_ACTIVE" -eq 0 ] \
    && [ "$BACKLOG" -eq 0 ] \
    && [ "$STAKEHOLDER" -eq 0 ] \
    && [ "$IN_PROGRESS" -eq 0 ]
}

# Main loop
while true; do
  clear_screen
  print_header

  read_snapshot_state

  if is_idle; then
    print_done_summary
  else
    bash "$SCRIPT_DIR/yota-snapshot.sh" --human 2>/dev/null
    print_worker_detail
  fi

  print_footer

  sleep "$INTERVAL"
done
