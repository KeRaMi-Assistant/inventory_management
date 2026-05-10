#!/usr/bin/env bash
# scan-doc-drift.sh — Analyzer-Modul: detect handbook drift via git heuristic.
#
# Usage:
#   scan-doc-drift.sh           — full run, writes 1 item to overseer/inbox/ if drift found
#   scan-doc-drift.sh --dry-run — plan to stdout, no files written
#   scan-doc-drift.sh --status  — print state JSON to stdout
#
# Heuristic:
#   1. git diff origin/main...HEAD --name-only → filter lib/, supabase/functions/, supabase/migrations/
#   2. git log --since='7 days ago' --name-only -- 'docs/handbook/*' → any handbook touches?
#   3. Code changes + no handbook update in 7d → drift signal.
#
# Dedup key: sha256("scan-doc-drift" + sha8 of HEAD commit on code-change branch)
# One item/run max — one aggregated item for "doc drift", not per-file.
# Pause logic: after 3 attempts on same drift hash within 30 days → pause 7 days.
# Inbox-Cap: skip if .claude/overseer/inbox/ has > 50 files.

set -uo pipefail

# ---------------------------------------------------------------------------
# Paths & config
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# CLAUDE_PROJECT_DIR allows sandbox/test overrides of the repo root.
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  REPO_ROOT="$(cd "$CLAUDE_PROJECT_DIR" && pwd)"
else
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi

MODULE_NAME="scan-doc-drift"
STATE_FILE="${ANALYZER_STATE_FILE:-$REPO_ROOT/.claude/analyzer/state/scan-doc-drift.json}"
INBOX_DIR="${OVERSEER_INBOX_DIR:-$REPO_ROOT/.claude/overseer/inbox}"
AUDIT_SH="$REPO_ROOT/.claude/scripts/lib/audit.sh"
NOTIFY_SH="$REPO_ROOT/.claude/scripts/notify.sh"

# Allow overrides from env (for testing)
BASE_REF="${DOC_DRIFT_BASE_REF:-origin/main}"
HANDBOOK_SINCE="${DOC_DRIFT_HANDBOOK_SINCE:-7 days ago}"

INBOX_CAP=50
AGE_DAYS=30
PAUSE_DAYS=7
MAX_ATTEMPTS=3

DRY_RUN=0
STATUS_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --status)  STATUS_ONLY=1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
_iso_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

_sha256() {
  printf '%s' "$1" | shasum -a 256 2>/dev/null | awk '{print $1}' \
    || printf '%s' "$1" | sha256sum | awk '{print $1}'
}

_sha8() { printf '%s' "$(_sha256 "$1")" | cut -c1-8; }

_audit() {
  if [ -f "$AUDIT_SH" ]; then
    # shellcheck source=/dev/null
    source "$AUDIT_SH"
    audit_record "$MODULE_NAME" "${1:-info}" "${2:-}" "${3:-}" 2>/dev/null || true
  fi
}

_notify_info() {
  local msg="$1"
  if [ -f "$NOTIFY_SH" ]; then
    NOTIFY_DRY_RUN="${NOTIFY_DRY_RUN:-0}" bash "$NOTIFY_SH" info "claude-swarm" \
      "scan-doc-drift" "$msg" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# Status-only mode
# ---------------------------------------------------------------------------
if [ "$STATUS_ONLY" -eq 1 ]; then
  if [ -f "$STATE_FILE" ]; then
    cat "$STATE_FILE"
  else
    printf '{"last_run":null,"subjects":{}}\n'
  fi
  exit 0
fi

# ---------------------------------------------------------------------------
# Load / initialise state
# ---------------------------------------------------------------------------
_load_state() {
  if [ -f "$STATE_FILE" ]; then
    cat "$STATE_FILE"
  else
    printf '{"last_run":null,"subjects":{}}\n'
  fi
}

_save_state() {
  local json="$1"
  mkdir -p "$(dirname "$STATE_FILE")"
  printf '%s\n' "$json" > "$STATE_FILE"
}

STATE_JSON="$(_load_state)"

# ---------------------------------------------------------------------------
# Inbox-Cap check
# ---------------------------------------------------------------------------
_inbox_count() {
  find "$INBOX_DIR" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l | tr -d ' '
}

if [ -d "$INBOX_DIR" ]; then
  INBOX_CNT="$(_inbox_count)"
  if [ "$INBOX_CNT" -gt "$INBOX_CAP" ]; then
    printf '[scan-doc-drift] SKIP: inbox has %d items (cap=%d)\n' "$INBOX_CNT" "$INBOX_CAP"
    _audit "skip" "inbox-cap" "inbox=$INBOX_CNT > cap=$INBOX_CAP — no items generated"
    exit 0
  fi
fi

# ---------------------------------------------------------------------------
# Heuristic: detect doc drift
# ---------------------------------------------------------------------------

# Step 1: collect code-change files since base ref
# Allow GIT_CMD override for testing (e.g. mock git)
GIT_CMD="${GIT_CMD:-git}"

CODE_CHANGED_FILES=""
CODE_CHANGED_FILES="$(
  cd "$REPO_ROOT" && $GIT_CMD diff "${BASE_REF}...HEAD" --name-only 2>/dev/null \
    | grep -E '^(lib/|supabase/functions/|supabase/migrations/)' || true
)"

if [ -z "$CODE_CHANGED_FILES" ]; then
  printf '[scan-doc-drift] No relevant code changes vs %s. Done.\n' "$BASE_REF"
  STATE_JSON="$(printf '%s' "$STATE_JSON" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); d['last_run']='$(_iso_now)'; print(json.dumps(d,indent=2))")"
  [ "$DRY_RUN" -eq 0 ] && _save_state "$STATE_JSON"
  exit 0
fi

# Step 2: check if handbook was updated in the last 7 days
HANDBOOK_UPDATED_FILES=""
HANDBOOK_UPDATED_FILES="$(
  cd "$REPO_ROOT" && $GIT_CMD log --since="$HANDBOOK_SINCE" --name-only --format="" \
    -- 'docs/handbook/*' 2>/dev/null | grep -v '^$' || true
)"

if [ -n "$HANDBOOK_UPDATED_FILES" ]; then
  printf '[scan-doc-drift] Handbook recently updated — no drift signal. Done.\n'
  STATE_JSON="$(printf '%s' "$STATE_JSON" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); d['last_run']='$(_iso_now)'; print(json.dumps(d,indent=2))")"
  [ "$DRY_RUN" -eq 0 ] && _save_state "$STATE_JSON"
  exit 0
fi

# Step 3: drift confirmed — code changed, handbook stale
# ---------------------------------------------------------------------------
# Compute dedup hash: sha256("scan-doc-drift" + sorted changed files joined)
# ---------------------------------------------------------------------------
SORTED_FILES="$(printf '%s\n' "$CODE_CHANGED_FILES" | sort | tr '\n' '|')"
HASH_INPUT="scan-doc-drift${SORTED_FILES}"
FULL_HASH="$(_sha256 "$HASH_INPUT")"
SHA8="$(_sha8 "$HASH_INPUT")"

# ---------------------------------------------------------------------------
# State helpers (same pattern as scan-l10n-drift)
# ---------------------------------------------------------------------------
_state_get_subject() {
  local hash="$1"
  python3 - "$STATE_FILE" "$hash" <<'PYEOF'
import sys, json, os
sf, h = sys.argv[1], sys.argv[2]
if not os.path.exists(sf):
    print('{}')
    sys.exit(0)
with open(sf) as f:
    d = json.load(f)
subj = d.get('subjects', {}).get(h, {})
print(json.dumps(subj))
PYEOF
}

_state_upsert() {
  python3 - "$1" "$2" "$3" "$4" "$5" "$6" <<'PYEOF'
import sys, json
state_json, h, label, first_seen, last_attempts_json, paused_until = sys.argv[1:]
d = json.loads(state_json)
subjs = d.setdefault('subjects', {})
subjs[h] = {
    'label': label,
    'first_seen': first_seen,
    'last_attempts': json.loads(last_attempts_json),
    'paused_until': paused_until if paused_until != 'null' else None,
}
print(json.dumps(d, indent=2))
PYEOF
}

_date_add_days() {
  local epoch="$1" days="$2"
  local target=$(( epoch + days * 86400 ))
  if date -r "$target" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null; then :
  else date -u -d "@$target" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
       python3 -c "import datetime; print(datetime.datetime.utcfromtimestamp($target).strftime('%Y-%m-%dT%H:%M:%SZ'))"; fi
}

_iso_to_epoch() {
  python3 -c "import datetime; \
dt=datetime.datetime.strptime('$1','%Y-%m-%dT%H:%M:%SZ'); \
print(int(dt.replace(tzinfo=datetime.timezone.utc).timestamp()))" 2>/dev/null || echo 0
}

NOW_ISO="$(_iso_now)"
NOW_EPOCH="$(date -u +%s)"

# ---------------------------------------------------------------------------
# Load subject state
# ---------------------------------------------------------------------------
SUBJ_JSON="$(_state_get_subject "$FULL_HASH")"

FIRST_SEEN="$(python3 -c "import sys,json; d=json.loads(sys.argv[1]); print(d.get('first_seen',''))" "$SUBJ_JSON")"
[ -z "$FIRST_SEEN" ] && FIRST_SEEN="$NOW_ISO"

LAST_ATTEMPTS_JSON="$(python3 -c "import sys,json; d=json.loads(sys.argv[1]); print(json.dumps(d.get('last_attempts',[])))" "$SUBJ_JSON")"
PAUSED_UNTIL="$(python3 -c "import sys,json; d=json.loads(sys.argv[1]); print(d.get('paused_until') or 'null')" "$SUBJ_JSON")"

# ---------------------------------------------------------------------------
# Check pause
# ---------------------------------------------------------------------------
if [ "$PAUSED_UNTIL" != "null" ] && [ -n "$PAUSED_UNTIL" ]; then
  PAUSE_EPOCH="$(_iso_to_epoch "$PAUSED_UNTIL")"
  if [ "$NOW_EPOCH" -lt "$PAUSE_EPOCH" ]; then
    printf '[scan-doc-drift] SKIP (paused until %s): drift hash=%s\n' "$PAUSED_UNTIL" "$SHA8"
    STATE_JSON="$(printf '%s' "$STATE_JSON" \
      | python3 -c "import sys,json; d=json.load(sys.stdin); d['last_run']='${NOW_ISO}'; print(json.dumps(d,indent=2))")"
    [ "$DRY_RUN" -eq 0 ] && _save_state "$STATE_JSON"
    exit 0
  else
    # Pause expired — reset
    PAUSED_UNTIL="null"
    LAST_ATTEMPTS_JSON="[]"
  fi
fi

# ---------------------------------------------------------------------------
# Attempt-counter check
# ---------------------------------------------------------------------------
RECENT_COUNT="$(python3 - "$LAST_ATTEMPTS_JSON" "$NOW_EPOCH" "$AGE_DAYS" <<'PYEOF'
import sys, json, datetime
attempts = json.loads(sys.argv[1])
now_epoch = int(sys.argv[2])
age_days = int(sys.argv[3])
cutoff = now_epoch - age_days * 86400
count = 0
for a in attempts:
    try:
        dt = datetime.datetime.strptime(a, '%Y-%m-%dT%H:%M:%SZ')
        epoch = int(dt.replace(tzinfo=datetime.timezone.utc).timestamp())
        if epoch >= cutoff:
            count += 1
    except Exception:
        pass
print(count)
PYEOF
)"

if [ "$RECENT_COUNT" -ge "$MAX_ATTEMPTS" ]; then
  NEW_PAUSE="$(_date_add_days "$NOW_EPOCH" "$PAUSE_DAYS")"
  printf '[scan-doc-drift] PAUSE (3 attempts): drift hash=%s — paused until %s\n' "$SHA8" "$NEW_PAUSE"
  _audit "pause" "doc-drift-$SHA8" "subject paused until $NEW_PAUSE after $RECENT_COUNT attempts"
  _notify_info "doc-drift subject paused 7d after $MAX_ATTEMPTS attempts: hash=$SHA8"
  STATE_JSON="$(_state_upsert "$STATE_JSON" "$FULL_HASH" "doc-drift-$SHA8" "$FIRST_SEEN" "$LAST_ATTEMPTS_JSON" "$NEW_PAUSE")"
  STATE_JSON="$(printf '%s' "$STATE_JSON" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); d['last_run']='${NOW_ISO}'; print(json.dumps(d,indent=2))")"
  [ "$DRY_RUN" -eq 0 ] && _save_state "$STATE_JSON"
  exit 0
fi

# ---------------------------------------------------------------------------
# Add this attempt
# ---------------------------------------------------------------------------
NEW_ATTEMPTS_JSON="$(python3 -c "import sys,json; a=json.loads(sys.argv[1]); a.append(sys.argv[2]); print(json.dumps(a))" "$LAST_ATTEMPTS_JSON" "$NOW_ISO")"

STATE_JSON="$(_state_upsert "$STATE_JSON" "$FULL_HASH" "doc-drift-$SHA8" "$FIRST_SEEN" "$NEW_ATTEMPTS_JSON" "null")"

# ---------------------------------------------------------------------------
# Dry-run output
# ---------------------------------------------------------------------------
if [ "$DRY_RUN" -eq 1 ]; then
  printf '[dry-run] Would generate doc-drift item: slug=doc-drift-%s hash=%s\n' "$SHA8" "$FULL_HASH"
  printf '[dry-run] Changed code files (no handbook update in 7d):\n'
  printf '%s\n' "$CODE_CHANGED_FILES" | sed 's/^/  /'
  STATE_JSON="$(printf '%s' "$STATE_JSON" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); d['last_run']='${NOW_ISO}'; print(json.dumps(d,indent=2))")"
  exit 0
fi

# ---------------------------------------------------------------------------
# Build item body
# ---------------------------------------------------------------------------
CHANGED_LIST="$(printf '%s\n' "$CODE_CHANGED_FILES" | sed 's/^/- `/' | sed 's/$/`/')"

ITEM_BODY="## Aufgabe

Handbook-Drift erkannt. Code-Änderungen ohne entsprechendes Handbook-Update in
den letzten 7 Tagen. Führe \`/update-docs --apply\` aus, um das Handbook mit den
aktuellen Code-Änderungen zu synchronisieren.

## Geänderte Code-Files (ohne Handbook-Update)

${CHANGED_LIST}

## Fix-Befehl

\`\`\`bash
# Im Claude Code:
/update-docs --apply

# Oder direkt:
claude --print --agent doc-updater 'update docs --from origin/main --apply'
\`\`\`

## Acceptance

- \`docs/handbook/\` wurde nach dem Fix aktualisiert.
- Alle neuen Screens, Provider, Services, Migrations und Edge-Functions sind
  im Handbook dokumentiert.
- \`/update-docs --from origin/main --strict\` exits 0."

# ---------------------------------------------------------------------------
# Write inbox item
# ---------------------------------------------------------------------------
mkdir -p "$INBOX_DIR"
ITEM_FILE="$INBOX_DIR/02-analyzer-${MODULE_NAME}-${SHA8}.md"

# Exact dedup: file already exists → skip
if [ -f "$ITEM_FILE" ]; then
  printf '[scan-doc-drift] SKIP: item already exists: %s\n' "$ITEM_FILE"
  STATE_JSON="$(printf '%s' "$STATE_JSON" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); d['last_run']='${NOW_ISO}'; print(json.dumps(d,indent=2))")"
  _save_state "$STATE_JSON"
  exit 0
fi

cat > "$ITEM_FILE" <<EOF
---
slug: doc-drift-${SHA8}
source: tier-3
priority: 2
budget_usd: 1.5
model: sonnet
touches: [docs/handbook/]
needs_gh: false
estimated_minutes: 30
created_from: ${MODULE_NAME}
trust_tier: 3
---

${ITEM_BODY}
EOF

printf '[scan-doc-drift] Item written: %s\n' "$ITEM_FILE"
_audit "item-created" "doc-drift-$SHA8" "hash=$FULL_HASH item=$ITEM_FILE"

# ---------------------------------------------------------------------------
# Persist state
# ---------------------------------------------------------------------------
STATE_JSON="$(printf '%s' "$STATE_JSON" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); d['last_run']='${NOW_ISO}'; print(json.dumps(d,indent=2))")"
_save_state "$STATE_JSON"

printf '[scan-doc-drift] Done.\n'
