#!/usr/bin/env bash
# scan-failure-lessons-expiry.sh — Analyzer module: prüft expires_at-Felder
# in .claude/memory/failure-lessons.md und erzeugt Backlog-Items für
# abgelaufene Lessons.
#
# Usage: scan-failure-lessons-expiry.sh [--dry-run|--status]
#
# Exit codes:
#   0 — OK (auch wenn File fehlt)
#   1 — interner Fehler

set -uo pipefail

# ---------------------------------------------------------------------------
# Konfiguration
# ---------------------------------------------------------------------------
REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
LESSONS_FILE="${REPO_ROOT}/.claude/memory/failure-lessons.md"
INBOX_DIR="${REPO_ROOT}/.claude/overseer/inbox"
STATE_FILE="${REPO_ROOT}/.claude/analyzer/state/scan-failure-lessons-expiry.json"
AUDIT_LIB="${REPO_ROOT}/.claude/scripts/lib/audit.sh"

INBOX_CAP=50
ACTOR="scan-failure-lessons-expiry"

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
DRY_RUN=false
STATUS_MODE=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --status)  STATUS_MODE=true ;;
  esac
done

# ---------------------------------------------------------------------------
# Audit (best-effort)
# ---------------------------------------------------------------------------
_audit() {
  if [ -f "$AUDIT_LIB" ]; then
    # shellcheck source=/dev/null
    source "$AUDIT_LIB" 2>/dev/null || true
    audit_record "$ACTOR" "$1" "$2" "$3" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# Status mode
# ---------------------------------------------------------------------------
if "$STATUS_MODE"; then
  if [ -f "$STATE_FILE" ]; then
    printf 'State: %s\n' "$STATE_FILE"
    cat "$STATE_FILE"
  else
    printf 'State: (no state file)\n'
  fi
  exit 0
fi

# ---------------------------------------------------------------------------
# File fehlt oder leer → graceful exit 0
# ---------------------------------------------------------------------------
if [ ! -f "$LESSONS_FILE" ]; then
  printf '[%s] failure-lessons.md nicht gefunden — 0 Items, exit 0\n' "$ACTOR"
  exit 0
fi

if [ ! -s "$LESSONS_FILE" ]; then
  printf '[%s] failure-lessons.md leer — 0 Items, exit 0\n' "$ACTOR"
  exit 0
fi

# ---------------------------------------------------------------------------
# Today (UTC, YYYY-MM-DD)
# ---------------------------------------------------------------------------
TODAY="$(date -u +%Y-%m-%d)"

# ---------------------------------------------------------------------------
# Inbox-Cap-Check
# ---------------------------------------------------------------------------
_inbox_count() {
  find "$INBOX_DIR" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' '
}

_check_inbox_cap() {
  local count
  count="$(_inbox_count)"
  if [ "$count" -ge "$INBOX_CAP" ]; then
    printf '[%s] Inbox-Cap erreicht (%d >= %d) — skip\n' "$ACTOR" "$count" "$INBOX_CAP" >&2
    _audit "skip" "inbox" "Inbox-Cap $count >= $INBOX_CAP"
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# State: gelesen / geschrieben via python3 (JSON)
# ---------------------------------------------------------------------------
# state JSON: { "<slug>": { "status": "open|done", "created_at": "..." } }

_state_get() {
  local slug="$1"
  if [ ! -f "$STATE_FILE" ]; then
    printf ''
    return
  fi
  python3 - "$STATE_FILE" "$slug" <<'PYEOF'
import sys, json
state_file, slug = sys.argv[1], sys.argv[2]
try:
    with open(state_file, 'r') as f:
        data = json.load(f)
    entry = data.get(slug, {})
    print(entry.get("status", ""))
except Exception:
    print("")
PYEOF
}

_state_set() {
  local slug="$1"
  local status="$2"
  local created_at="$3"
  mkdir -p "$(dirname "$STATE_FILE")"
  python3 - "$STATE_FILE" "$slug" "$status" "$created_at" <<'PYEOF'
import sys, json, os
state_file, slug, status, created_at = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
data = {}
if os.path.exists(state_file):
    try:
        with open(state_file, 'r') as f:
            data = json.load(f)
    except Exception:
        data = {}
data[slug] = {"status": status, "created_at": created_at}
with open(state_file, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
PYEOF
}

# ---------------------------------------------------------------------------
# Parse Markdown: extrahiere Lessons
# ---------------------------------------------------------------------------
# Erwartetes Format:
#   ## <slug>
#   - cause: ...
#   - pattern: ...
#   - mitigation: ...
#   - expires_at: YYYY-MM-DD
#
# Gibt tab-separated: slug<TAB>expires_at (oder "NONE" wenn kein expires_at)

_parse_lessons() {
  python3 - "$LESSONS_FILE" <<'PYEOF'
import sys, re

lessons_file = sys.argv[1]

with open(lessons_file, 'r', encoding='utf-8') as f:
    content = f.read()

# Split into blocks by H2 headings
blocks = re.split(r'^## ', content, flags=re.MULTILINE)

for block in blocks:
    block = block.strip()
    if not block:
        continue
    lines = block.split('\n')
    slug_line = lines[0].strip()
    # slug: everything on the ## line (already stripped the ## prefix)
    slug = slug_line.strip()
    if not slug:
        continue

    expires_at = None
    for line in lines[1:]:
        m = re.match(r'\s*-\s*expires_at:\s*(\S+)', line)
        if m:
            expires_at = m.group(1)
            break

    if expires_at:
        print(f"{slug}\t{expires_at}")
    else:
        print(f"{slug}\tNONE")
PYEOF
}

# ---------------------------------------------------------------------------
# Date comparison (YYYY-MM-DD)
# ---------------------------------------------------------------------------
_is_expired() {
  local expires_at="$1"
  local today="$2"
  # expired if expires_at < today
  python3 -c "import sys; print('yes' if '$expires_at' < '$today' else 'no')" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
mkdir -p "$INBOX_DIR"

ITEMS_CREATED=0
ITEMS_SKIPPED_DEDUP=0
ITEMS_SKIPPED_FUTURE=0
ITEMS_SKIPPED_NO_EXPIRY=0
DRY_RUN_ITEMS=()

while IFS=$'\t' read -r slug expires_at; do
  [ -z "$slug" ] && continue

  # Lesson ohne expires_at
  if [ "$expires_at" = "NONE" ]; then
    printf '[%s] WARN: Lesson "%s" hat kein expires_at — skip\n' "$ACTOR" "$slug" >&2
    ITEMS_SKIPPED_NO_EXPIRY=$((ITEMS_SKIPPED_NO_EXPIRY + 1))
    continue
  fi

  # Validate date format
  if ! python3 -c "
import sys, re
d = '$expires_at'
if not re.match(r'^\d{4}-\d{2}-\d{2}$', d):
    sys.exit(1)
" 2>/dev/null; then
    printf '[%s] WARN: Lesson "%s" hat ungültiges expires_at-Format "%s" — skip\n' \
      "$ACTOR" "$slug" "$expires_at" >&2
    continue
  fi

  # Nicht abgelaufen
  result="$(_is_expired "$expires_at" "$TODAY")"
  if [ "$result" != "yes" ]; then
    ITEMS_SKIPPED_FUTURE=$((ITEMS_SKIPPED_FUTURE + 1))
    continue
  fi

  # Abgelaufen — Dedup-Check
  existing_status="$(_state_get "$slug")"
  if [ -n "$existing_status" ]; then
    printf '[%s] DEDUP: Lesson "%s" bereits im State (%s) — skip\n' \
      "$ACTOR" "$slug" "$existing_status"
    ITEMS_SKIPPED_DEDUP=$((ITEMS_SKIPPED_DEDUP + 1))
    continue
  fi

  # Inbox-Cap
  if ! _check_inbox_cap; then
    break
  fi

  # Slug sanitizen (nur alphanumeric + Bindestrich)
  safe_slug="$(printf '%s' "$slug" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9-' '-' | sed 's/^-//;s/-$//')"
  item_name="02-analyzer-failure-lessons-expiry-${safe_slug}.md"
  item_path="${INBOX_DIR}/${item_name}"

  # Frontmatter + Body
  item_content="---
slug: failure-lessons-expiry-${safe_slug}
source: tier-3
priority: 2
budget_usd: 1.0
model: haiku
touches: [.claude/memory/failure-lessons.md]
needs_gh: false
estimated_minutes: 5
created_from: scan-failure-lessons-expiry
trust_tier: 3
---

Remove or refresh expired failure-lesson \`${slug}\` (expired \`${expires_at}\`). Either delete the lesson if no longer relevant, or update \`expires_at:\` to a new date with rationale.
"

  if "$DRY_RUN"; then
    DRY_RUN_ITEMS+=("$item_name (expires_at=$expires_at)")
    printf '[DRY-RUN] Würde erzeugen: %s\n' "$item_name"
    ITEMS_CREATED=$((ITEMS_CREATED + 1))
    continue
  fi

  # Schreiben
  printf '%s' "$item_content" > "$item_path"
  _state_set "$slug" "open" "$TODAY"
  _audit "create" "$item_name" "expired failure-lesson: $slug (expires_at=$expires_at)"
  printf '[%s] Item erzeugt: %s\n' "$ACTOR" "$item_name"
  ITEMS_CREATED=$((ITEMS_CREATED + 1))

done < <(_parse_lessons)

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '[%s] Fertig — created=%d skipped_dedup=%d skipped_future=%d skipped_no_expiry=%d\n' \
  "$ACTOR" "$ITEMS_CREATED" "$ITEMS_SKIPPED_DEDUP" "$ITEMS_SKIPPED_FUTURE" "$ITEMS_SKIPPED_NO_EXPIRY"

exit 0
