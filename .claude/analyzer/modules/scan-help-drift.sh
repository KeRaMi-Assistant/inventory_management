#!/usr/bin/env bash
# scan-help-drift.sh — Analyzer-Modul: detect help-screen drift.
#
# Usage:
#   scan-help-drift.sh           — full run, writes 1 item to overseer/inbox/ if drift found
#   scan-help-drift.sh --dry-run — plan to stdout, no files written
#   scan-help-drift.sh --status  — print state JSON to stdout
#
# Heuristic:
#   1. git diff origin/main...HEAD --name-only filters:
#      - lib/screens/ changes
#      - lib/services/ changes with user-facing heuristic (method names / comments)
#      - new ARB keys in lib/l10n/app_*.arb
#   2. If diff found: check if lib/screens/help_screen.dart OR lib/l10n/app_*.arb
#      were touched in the last 7 days.
#   3. If not → drift signal: user-visible changes without help update.
#
# Dedup key: sha256("scan-help-drift" + sorted changed files joined).
# One item/run max — no flood.
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

MODULE_NAME="scan-help-drift"
STATE_FILE="${ANALYZER_STATE_FILE:-$REPO_ROOT/.claude/analyzer/state/scan-help-drift.json}"
INBOX_DIR="${OVERSEER_INBOX_DIR:-$REPO_ROOT/.claude/overseer/inbox}"
AUDIT_SH="$REPO_ROOT/.claude/scripts/lib/audit.sh"
NOTIFY_SH="$REPO_ROOT/.claude/scripts/notify.sh"

INBOX_CAP=50
AGE_DAYS=30
PAUSE_DAYS=7
MAX_ATTEMPTS=3
HELP_STALE_DAYS=7

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
      "scan-help-drift" "$msg" 2>/dev/null || true
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
    printf '[scan-help-drift] SKIP: inbox has %d items (cap=%d)\n' "$INBOX_CNT" "$INBOX_CAP"
    _audit "skip" "inbox-cap" "inbox=$INBOX_CNT > cap=$INBOX_CAP — no items generated"
    exit 0
  fi
fi

# ---------------------------------------------------------------------------
# Detect changed files in branch vs origin/main
# ---------------------------------------------------------------------------
# GIT_DIFF_CMD allows test override (e.g. inject mock file list via env).
_get_branch_diff() {
  if [ -n "${GIT_DIFF_CMD:-}" ]; then
    eval "$GIT_DIFF_CMD"
    return
  fi
  # Only run git diff if we're inside a real git repo.
  if git -C "$REPO_ROOT" rev-parse --git-dir > /dev/null 2>&1; then
    git -C "$REPO_ROOT" diff origin/main...HEAD --name-only 2>/dev/null || true
  fi
}

BRANCH_DIFF="$(_get_branch_diff)"

# Filter: lib/screens/ (excluding help_screen itself for drift logic)
SCREEN_CHANGES="$(printf '%s\n' "$BRANCH_DIFF" \
  | grep -E '^lib/screens/' \
  | grep -v '^lib/screens/help_screen\.dart' \
  || true)"

# Filter: lib/services/ with user-facing heuristic
# Heuristic: grep for "User-facing" or "public api" comments/method names in changed service files.
SERVICE_CHANGES_RAW="$(printf '%s\n' "$BRANCH_DIFF" \
  | grep -E '^lib/services/' \
  || true)"

SERVICE_CHANGES=""
if [ -n "$SERVICE_CHANGES_RAW" ]; then
  while IFS= read -r sf; do
    [ -z "$sf" ] && continue
    FULL_PATH="$REPO_ROOT/$sf"
    if [ -f "$FULL_PATH" ]; then
      if grep -qiE '(User-facing|public api)' "$FULL_PATH" 2>/dev/null; then
        SERVICE_CHANGES="${SERVICE_CHANGES}${sf}"$'\n'
      fi
    else
      # File deleted or not accessible — include it conservatively
      SERVICE_CHANGES="${SERVICE_CHANGES}${sf}"$'\n'
    fi
  done <<< "$SERVICE_CHANGES_RAW"
fi

# Filter: new/changed ARB keys
ARB_CHANGES="$(printf '%s\n' "$BRANCH_DIFF" \
  | grep -E '^lib/l10n/app_.*\.arb' \
  | grep -v '^$' \
  || true)"

# Combine all relevant changed files
ALL_RELEVANT="$(printf '%s\n%s\n%s\n' "$SCREEN_CHANGES" "$SERVICE_CHANGES" "$ARB_CHANGES" \
  | grep -v '^$' \
  | sort -u \
  || true)"

if [ -z "$ALL_RELEVANT" ]; then
  printf '[scan-help-drift] No user-visible changes detected. Done.\n'
  STATE_JSON="$(printf '%s' "$STATE_JSON" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); d['last_run']='$(_iso_now)'; print(json.dumps(d,indent=2))")"
  [ "$DRY_RUN" -eq 0 ] && _save_state "$STATE_JSON"
  exit 0
fi

# ---------------------------------------------------------------------------
# Check if help_screen.dart or ARBs were touched in the last HELP_STALE_DAYS
# ---------------------------------------------------------------------------
NOW_EPOCH="$(date -u +%s)"
STALE_CUTOFF=$(( NOW_EPOCH - HELP_STALE_DAYS * 86400 ))

_file_mtime_epoch() {
  local f="$1"
  if [ -f "$f" ]; then
    # macOS stat
    stat -f '%m' "$f" 2>/dev/null \
      || stat -c '%Y' "$f" 2>/dev/null \
      || python3 -c "import os; print(int(os.path.getmtime('$f')))" 2>/dev/null \
      || echo 0
  else
    echo 0
  fi
}

# Allow test override: HELP_SCREEN_MTIME (epoch) overrides file mtime check.
HELP_SCREEN_MTIME="${HELP_SCREEN_MTIME:-$(_file_mtime_epoch "$REPO_ROOT/lib/screens/help_screen.dart")}"

# ARB files mtime — take the most recent of the two
ARB_DE_MTIME="${ARB_DE_MTIME:-$(_file_mtime_epoch "$REPO_ROOT/lib/l10n/app_de.arb")}"
ARB_EN_MTIME="${ARB_EN_MTIME:-$(_file_mtime_epoch "$REPO_ROOT/lib/l10n/app_en.arb")}"

# Effective: max of all three
EFFECTIVE_MTIME="$(python3 -c "print(max($HELP_SCREEN_MTIME, $ARB_DE_MTIME, $ARB_EN_MTIME))")"

if [ "$EFFECTIVE_MTIME" -gt "$STALE_CUTOFF" ]; then
  printf '[scan-help-drift] Help files recently updated (mtime=%d, cutoff=%d). No drift.\n' \
    "$EFFECTIVE_MTIME" "$STALE_CUTOFF"
  STATE_JSON="$(printf '%s' "$STATE_JSON" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); d['last_run']='$(_iso_now)'; print(json.dumps(d,indent=2))")"
  [ "$DRY_RUN" -eq 0 ] && _save_state "$STATE_JSON"
  exit 0
fi

printf '[scan-help-drift] Drift detected: user-visible changes without help update.\n'

# ---------------------------------------------------------------------------
# Compute dedup hash: sha256("scan-help-drift" + sorted changed files joined)
# ---------------------------------------------------------------------------
SORTED_FILES="$(printf '%s\n' "$ALL_RELEVANT" | sort | tr '\n' '|')"
HASH_INPUT="scan-help-drift${SORTED_FILES}"
FULL_HASH="$(_sha256 "$HASH_INPUT")"
SHA8="$(_sha8 "$HASH_INPUT")"

# ---------------------------------------------------------------------------
# State helpers
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
    printf '[scan-help-drift] SKIP (paused until %s): drift hash=%s\n' "$PAUSED_UNTIL" "$SHA8"
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
  printf '[scan-help-drift] PAUSE (3 attempts): drift hash=%s — paused until %s\n' "$SHA8" "$NEW_PAUSE"
  _audit "pause" "help-drift-$SHA8" "subject paused until $NEW_PAUSE after $RECENT_COUNT attempts"
  _notify_info "help-drift subject paused 7d after $MAX_ATTEMPTS attempts: hash=$SHA8"
  STATE_JSON="$(_state_upsert "$STATE_JSON" "$FULL_HASH" "help-drift-$SHA8" "$FIRST_SEEN" "$LAST_ATTEMPTS_JSON" "$NEW_PAUSE")"
  STATE_JSON="$(printf '%s' "$STATE_JSON" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); d['last_run']='${NOW_ISO}'; print(json.dumps(d,indent=2))")"
  [ "$DRY_RUN" -eq 0 ] && _save_state "$STATE_JSON"
  exit 0
fi

# ---------------------------------------------------------------------------
# Add this attempt
# ---------------------------------------------------------------------------
NEW_ATTEMPTS_JSON="$(python3 -c "import sys,json; a=json.loads(sys.argv[1]); a.append(sys.argv[2]); print(json.dumps(a))" "$LAST_ATTEMPTS_JSON" "$NOW_ISO")"

STATE_JSON="$(_state_upsert "$STATE_JSON" "$FULL_HASH" "help-drift-$SHA8" "$FIRST_SEEN" "$NEW_ATTEMPTS_JSON" "null")"

# ---------------------------------------------------------------------------
# Dry-run output
# ---------------------------------------------------------------------------
if [ "$DRY_RUN" -eq 1 ]; then
  printf '[dry-run] Would generate help-drift item: slug=help-drift-%s hash=%s\n' "$SHA8" "$FULL_HASH"
  printf '[dry-run] Relevant changed files:\n'
  printf '%s\n' "$ALL_RELEVANT" | while IFS= read -r f; do
    [ -n "$f" ] && printf '  - %s\n' "$f"
  done
  STATE_JSON="$(printf '%s' "$STATE_JSON" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); d['last_run']='${NOW_ISO}'; print(json.dumps(d,indent=2))")"
  exit 0
fi

# ---------------------------------------------------------------------------
# Build item body
# ---------------------------------------------------------------------------
ITEM_BODY="$(python3 - "$ALL_RELEVANT" "$SHA8" <<'PYEOF'
import sys

files_raw = sys.argv[1]
sha8 = sys.argv[2]

files = [f for f in files_raw.strip().split('\n') if f.strip()]

lines = []
lines.append("## Aufgabe")
lines.append("")
lines.append("Run `/update-help --apply` to sync help-screen with recent UI changes.")
lines.append("")
lines.append("## Relevante Code-Änderungen")
lines.append("")
for f in files:
    lines.append(f"- `{f}`")
lines.append("")
lines.append("## Hintergrund")
lines.append("")
lines.append("Der Analyzer hat User-sichtbare Änderungen (Screens, Services, ARB-Keys) erkannt,")
lines.append("aber `lib/screens/help_screen.dart` und die ARB-Dateien wurden in den letzten")
lines.append("7 Tagen nicht aktualisiert. Das deutet auf Drift zwischen Code und Hilfeseite hin.")
lines.append("")
lines.append("## Fix-Befehl")
lines.append("")
lines.append("```bash")
lines.append("/update-help --apply")
lines.append("```")
lines.append("")
lines.append("Alternativ direkt:")
lines.append("")
lines.append("```bash")
lines.append("# Dry-run: zeigt Plan + geplante ARB-Keys")
lines.append("/update-help")
lines.append("# Apply: schreibt DE+EN ARBs + help_screen.dart")
lines.append("/update-help --apply")
lines.append("```")
lines.append("")
lines.append("## Acceptance")
lines.append("")
lines.append("- `lib/screens/help_screen.dart` enthält Abschnitte für alle neuen Screens/Features.")
lines.append("- DE + EN ARBs sind symmetrisch und enthalten keine [TODO en]-Marker.")
lines.append("- `/check-l10n` läuft durch (0 findings).")

print('\n'.join(lines))
PYEOF
)"

# ---------------------------------------------------------------------------
# Write inbox item
# ---------------------------------------------------------------------------
mkdir -p "$INBOX_DIR"
ITEM_FILE="$INBOX_DIR/02-analyzer-${MODULE_NAME}-${SHA8}.md"

# Exact dedup: file already exists → skip
if [ -f "$ITEM_FILE" ]; then
  printf '[scan-help-drift] SKIP: item already exists: %s\n' "$ITEM_FILE"
  STATE_JSON="$(printf '%s' "$STATE_JSON" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); d['last_run']='${NOW_ISO}'; print(json.dumps(d,indent=2))")"
  _save_state "$STATE_JSON"
  exit 0
fi

cat > "$ITEM_FILE" <<EOF
---
slug: help-drift-${SHA8}
source: tier-3
priority: 2
budget_usd: 1.5
model: sonnet
touches: [lib/screens/help_screen.dart, lib/l10n/]
needs_gh: false
estimated_minutes: 30
created_from: ${MODULE_NAME}
trust_tier: 3
---

${ITEM_BODY}
EOF

printf '[scan-help-drift] Item written: %s\n' "$ITEM_FILE"
_audit "item-created" "help-drift-$SHA8" "hash=$FULL_HASH item=$ITEM_FILE"

# ---------------------------------------------------------------------------
# Persist state
# ---------------------------------------------------------------------------
STATE_JSON="$(printf '%s' "$STATE_JSON" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); d['last_run']='${NOW_ISO}'; print(json.dumps(d,indent=2))")"
_save_state "$STATE_JSON"

printf '[scan-help-drift] Done.\n'
