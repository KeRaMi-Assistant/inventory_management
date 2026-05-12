#!/usr/bin/env bash
# yota-trigger-pending.sh — Triggert overseer.sh --once für jeden
# Inbox-Item (01-stakeholder-*.md), der noch nicht in_progress ist.
#
# Sinn: Falls der User vergangene `go`-Items „nachholen" möchte, ohne den
# Overseer-LaunchAgent zu installieren. Spawnt overseer.sh --once einmal
# pro Item (Inbox-Picker übernimmt dedup intern).
#
# Pre-Flight:
#   - ANTHROPIC_API_KEY darf NICHT gesetzt sein (Max-Plan-OAuth bevorzugt).
#   - .claude/.user-session-active muss existieren (Self-Mod-Guard).
#
# Usage: bash .claude/scripts/yota-trigger-pending.sh
#
# Exit codes:
#   0 — alle Items getriggert (oder nichts zu tun)
#   1 — Pre-Flight-Fail oder overseer.sh fehlt

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
INBOX_DIR="$REPO_ROOT/.claude/overseer/inbox"
OVERSEER_SH="$REPO_ROOT/.claude/scripts/overseer.sh"
SESSION_MARKER="$REPO_ROOT/.claude/.user-session-active"
WORKERS_DIR="$REPO_ROOT/.claude/overseer/state/workers"

if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  echo "ERROR: ANTHROPIC_API_KEY env gesetzt — würde API-Billing statt Max-Plan nutzen." >&2
  echo "       Unset und erneut versuchen: unset ANTHROPIC_API_KEY" >&2
  exit 1
fi

if [ ! -f "$SESSION_MARKER" ]; then
  echo "ERROR: User-Session-Marker fehlt ($SESSION_MARKER)" >&2
  echo "       Run: bash .claude/scripts/session-start.sh" >&2
  exit 1
fi

if [ ! -x "$OVERSEER_SH" ] && [ ! -f "$OVERSEER_SH" ]; then
  echo "ERROR: overseer.sh nicht gefunden: $OVERSEER_SH" >&2
  exit 1
fi

if [ ! -d "$INBOX_DIR" ]; then
  echo "Nichts zu tun — Inbox-Dir fehlt: $INBOX_DIR"
  exit 0
fi

shopt -s nullglob
items=("$INBOX_DIR"/01-stakeholder-*.md)
shopt -u nullglob

if [ ${#items[@]} -eq 0 ]; then
  echo "Nichts zu tun — keine 01-stakeholder-*.md Items in Inbox."
  exit 0
fi

# Sammle slugs, die aktuell schon von einem Worker bearbeitet werden,
# damit wir keine Redundant-Trigger zählen.
in_progress_slugs=""
if [ -d "$WORKERS_DIR" ]; then
  shopt -s nullglob
  for pidfile in "$WORKERS_DIR"/*.pid; do
    if [ -f "$pidfile" ]; then
      slug=$(grep -o '"slug"[[:space:]]*:[[:space:]]*"[^"]*"' "$pidfile" 2>/dev/null \
              | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
      if [ -n "$slug" ]; then
        in_progress_slugs="$in_progress_slugs $slug"
      fi
    fi
  done
  shopt -u nullglob
fi

triggered=0
skipped=0
for item in "${items[@]}"; do
  base="$(basename "$item" .md)"
  slug="${base#01-stakeholder-}"
  if echo " $in_progress_slugs " | grep -q " $slug "; then
    echo "skip: $slug (in_progress)"
    skipped=$((skipped + 1))
    continue
  fi
  echo "trigger: $slug"
  unset ANTHROPIC_API_KEY
  REPO_ROOT="$REPO_ROOT" bash "$OVERSEER_SH" --once >/dev/null 2>&1 &
  disown || true
  triggered=$((triggered + 1))
done

echo ""
echo "Done. triggered=$triggered skipped=$skipped (total=${#items[@]})"
exit 0
