#!/usr/bin/env bash
# Aktiviert ein vorgefertigtes Backlog-Template (kopiert nach inbox/).
#
# Usage:
#   queue-template.sh <template-name>      # einzelnes Template
#   queue-template.sh sprint-7             # alle Templates mit Prefix s7-
#   queue-template.sh sprint-9             # alle s9-*
#   queue-template.sh querschnitt          # alle q-*
#   queue-template.sh tech-debt            # alle td-*
#   queue-template.sh all                  # alles
#   queue-template.sh list                 # nur listen, nichts kopieren

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEMPLATES="$ROOT/.claude/backlog/templates"
INBOX="$ROOT/.claude/backlog/inbox"

mkdir -p "$INBOX"

ARG="${1:-}"
if [ -z "$ARG" ]; then
  echo "usage: queue-template.sh <name|sprint-7|sprint-9|querschnitt|tech-debt|all|list>" >&2
  exit 1
fi

# Glob für Selektion
case "$ARG" in
  list)
    echo "Available templates:"
    find "$TEMPLATES" -maxdepth 1 -type f -name '*.md' ! -name 'README.md' \
      | sort | xargs -n1 basename | sed 's/^/  /'
    exit 0
    ;;
  sprint-7) GLOB="s7-*.md" ;;
  sprint-9) GLOB="s9-*.md" ;;
  querschnitt) GLOB="q-*.md" ;;
  tech-debt) GLOB="td-*.md" ;;
  all) GLOB="*.md" ;;
  *)
    # Einzelnes Template — vollständig oder Prefix
    if [ -f "$TEMPLATES/$ARG.md" ]; then
      GLOB="$ARG.md"
    elif [ -f "$TEMPLATES/$ARG" ]; then
      GLOB="$ARG"
    else
      # Prefix-Match: erstes File das mit ARG beginnt
      MATCH="$(find "$TEMPLATES" -maxdepth 1 -type f -name "${ARG}*.md" ! -name 'README.md' | head -1)"
      if [ -z "$MATCH" ]; then
        echo "no template matches '$ARG'" >&2
        echo "available:" >&2
        find "$TEMPLATES" -maxdepth 1 -type f -name '*.md' ! -name 'README.md' \
          | xargs -n1 basename | sed 's/^/  /' >&2
        exit 1
      fi
      GLOB="$(basename "$MATCH")"
    fi
    ;;
esac

# Bestimme nächste freie Sequence-Nummer in inbox/
next_seq() {
  local highest=0
  for f in "$INBOX"/*.md; do
    [ -e "$f" ] || continue
    local name="$(basename "$f")"
    local n="${name%%-*}"
    if [[ "$n" =~ ^[0-9]+$ ]]; then
      n=$((10#$n))
      [ "$n" -gt "$highest" ] && highest="$n"
    fi
  done
  printf '%02d' $((highest + 1))
}

COUNT=0
for src in "$TEMPLATES"/$GLOB; do
  [ -e "$src" ] || continue
  [ "$(basename "$src")" = "README.md" ] && continue

  base="$(basename "$src" .md)"
  # strip s7-/s9-/q-/td-/leading-XX- prefixes for clean inbox-name
  clean="${base#s[0-9]-}"
  clean="${clean#q-}"
  clean="${clean#td-}"
  clean="${clean#[0-9][0-9]-}"

  seq="$(next_seq)"
  target="$INBOX/${seq}-${clean}.md"

  cp "$src" "$target"
  echo "queued: $(basename "$target")"
  COUNT=$((COUNT + 1))
done

echo
echo "→ $COUNT item(s) in inbox: $INBOX"
echo "  trigger now: bash .claude/scripts/headless-runner.sh"
echo "  or wait for LaunchAgent (every 30 min)"
