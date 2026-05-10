#!/usr/bin/env bash
# scan-dead-code.sh — Analyzer-Modul: detect dead code via dart analyze.
#
# Usage:
#   scan-dead-code.sh           — full run, writes items to overseer/inbox/
#   scan-dead-code.sh --dry-run — plan to stdout, no files written
#   scan-dead-code.sh --status  — print state JSON to stdout
#
# Read-Only: never modifies source code.
# Dedup key: sha256("scan-dead-code" + file_path) — stable per file.
# Cap: 5 items/run, one item per file with >= 2 dead-code lints.
# Pause logic: after 3 attempts on same subject within 30 days → pause 7 days.
# Inbox-Cap: skip if .claude/overseer/inbox/ has > 50 files.
# Lints tracked: unused_import, unused_local_variable, unused_field,
#                unused_element, dead_code.

set -uo pipefail

# ---------------------------------------------------------------------------
# Paths & config
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  REPO_ROOT="$(cd "$CLAUDE_PROJECT_DIR" && pwd)"
else
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi

MODULE_NAME="scan-dead-code"
STATE_FILE="${ANALYZER_STATE_FILE:-$REPO_ROOT/.claude/analyzer/state/scan-dead-code.json}"
INBOX_DIR="${OVERSEER_INBOX_DIR:-$REPO_ROOT/.claude/overseer/inbox}"
AUDIT_SH="$REPO_ROOT/.claude/scripts/lib/audit.sh"
NOTIFY_SH="$REPO_ROOT/.claude/scripts/notify.sh"

MAX_ITEMS=5
INBOX_CAP=50
PAUSE_DAYS=7
MAX_ATTEMPTS=3
WINDOW_DAYS=30
MIN_LINTS=2  # minimum lints in a file to generate an item

DEAD_CODE_LINTS="unused_import|unused_local_variable|unused_field|unused_element|dead_code"

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
      "$MODULE_NAME" "$msg" 2>/dev/null || true
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
    printf '[%s] SKIP: inbox has %d items (cap=%d)\n' "$MODULE_NAME" "$INBOX_CNT" "$INBOX_CAP"
    _audit "skip" "inbox-cap" "inbox=$INBOX_CNT > cap=$INBOX_CAP — no items generated"
    exit 0
  fi
fi

# ---------------------------------------------------------------------------
# Check dart availability
# ---------------------------------------------------------------------------
DART_CMD="${DART_CMD:-dart}"
if ! command -v "$DART_CMD" &>/dev/null; then
  printf '[%s] WARNING: dart not found in PATH — skipping\n' "$MODULE_NAME"
  exit 0
fi

# ---------------------------------------------------------------------------
# Run dart analyze, parse JSON output
# ---------------------------------------------------------------------------
ANALYZE_OUT=""
ANALYZE_EXIT=0
ANALYZE_OUT="$("$DART_CMD" analyze "$REPO_ROOT/lib/" --no-fatal-infos --format json 2>/dev/null)" || ANALYZE_EXIT=$?

# dart analyze exits non-zero when there are issues — that's expected.
# Exit code 2+ typically means a config error; exit 1 means findings.
# We treat any JSON output as valid.

if [ -z "$ANALYZE_OUT" ]; then
  printf '[%s] dart analyze returned no output. Done.\n' "$MODULE_NAME"
  exit 0
fi

# ---------------------------------------------------------------------------
# Parse JSON: aggregate dead-code lints per file
# ---------------------------------------------------------------------------
# Output: "<lint_count>\t<file>\t<lint_list_json>"
FILE_LINT_MAP="$(python3 - "$ANALYZE_OUT" "$DEAD_CODE_LINTS" <<'PYEOF'
import sys, json, re

raw = sys.argv[1]
pattern = sys.argv[2]
allowed = set(pattern.split('|'))

try:
    data = json.loads(raw)
except json.JSONDecodeError:
    # Try to find JSON object in output (dart may prefix text)
    m = re.search(r'\{.*\}', raw, re.DOTALL)
    if not m:
        sys.exit(0)
    data = json.loads(m.group(0))

diagnostics = data.get('diagnostics', [])

from collections import defaultdict
files = defaultdict(list)

for d in diagnostics:
    code = d.get('code', '')
    if code not in allowed:
        continue
    loc = d.get('location', {})
    fpath = loc.get('file', '')
    if not fpath:
        fpath = d.get('file', '')
    if not fpath:
        continue
    msg = d.get('message', code)
    line = loc.get('range', {}).get('start', {}).get('line', 0)
    files[fpath].append({'code': code, 'line': line, 'message': msg})

for fpath, lints in sorted(files.items(), key=lambda x: -len(x[1])):
    print(f"{len(lints)}\t{fpath}\t{json.dumps(lints)}")
PYEOF
)"

if [ -z "$FILE_LINT_MAP" ]; then
  printf '[%s] No dead-code lints found. Done.\n' "$MODULE_NAME"
  STATE_JSON="$(printf '%s' "$STATE_JSON" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); d['last_run']='$(_iso_now)'; print(json.dumps(d,indent=2))")"
  [ "$DRY_RUN" -eq 0 ] && _save_state "$STATE_JSON"
  exit 0
fi

# ---------------------------------------------------------------------------
# State helpers (same pattern as scan-tech-debt)
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
state_json, h, fpath, first_seen, last_attempts_json, paused_until = sys.argv[1:]
d = json.loads(state_json)
subjs = d.setdefault('subjects', {})
subjs[h] = {
    'file': fpath,
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

# ---------------------------------------------------------------------------
# Process files — dedup, pause check, cap, write items
# ---------------------------------------------------------------------------
NOW_ISO="$(_iso_now)"
NOW_EPOCH="$(date -u +%s)"
ITEMS_WRITTEN=0

while IFS=$'\t' read -r lint_count fpath lints_json; do
  [ "$ITEMS_WRITTEN" -ge "$MAX_ITEMS" ] && break

  # Only process files with >= MIN_LINTS
  if [ "$lint_count" -lt "$MIN_LINTS" ]; then
    continue
  fi

  # Dedup hash: sha256("scan-dead-code" + file_path)
  hash_input="${MODULE_NAME}${fpath}"
  full_hash="$(_sha256 "$hash_input")"
  sha8="$(_sha8 "$hash_input")"

  # Load subject state
  subj_json="$(_state_get_subject "$full_hash")"

  first_seen="$(python3 -c "import sys,json; d=json.loads(sys.argv[1]); print(d.get('first_seen',''))" "$subj_json")"
  [ -z "$first_seen" ] && first_seen="$NOW_ISO"

  last_attempts_json="$(python3 -c "import sys,json; d=json.loads(sys.argv[1]); print(json.dumps(d.get('last_attempts',[])))" "$subj_json")"
  paused_until="$(python3 -c "import sys,json; d=json.loads(sys.argv[1]); print(d.get('paused_until') or 'null')" "$subj_json")"

  # Check if lints are resolved (counter reset)
  # If we have a state entry but the file still has lints, continue processing.
  # If file has 0 lints we wouldn't be here — handled above by min_lints filter.

  # Check pause
  if [ "$paused_until" != "null" ] && [ -n "$paused_until" ]; then
    pause_epoch="$(_iso_to_epoch "$paused_until")"
    if [ "$NOW_EPOCH" -lt "$pause_epoch" ]; then
      printf '[%s] SKIP (paused until %s): %s\n' "$MODULE_NAME" "$paused_until" "$fpath"
      continue
    else
      # Pause expired — reset
      paused_until="null"
      last_attempts_json="[]"
    fi
  fi

  # Count recent attempts within window
  recent_count="$(python3 - "$last_attempts_json" "$NOW_EPOCH" "$WINDOW_DAYS" <<'PYEOF'
import sys, json, datetime
attempts = json.loads(sys.argv[1])
now_epoch = int(sys.argv[2])
window_days = int(sys.argv[3])
cutoff = now_epoch - window_days * 86400
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

  if [ "$recent_count" -ge "$MAX_ATTEMPTS" ]; then
    new_pause="$(_date_add_days "$NOW_EPOCH" "$PAUSE_DAYS")"
    printf '[%s] PAUSE (3 attempts): %s — paused until %s\n' "$MODULE_NAME" "$fpath" "$new_pause"
    _audit "pause" "$fpath" "subject $full_hash paused until $new_pause after $recent_count attempts"
    _notify_info "Dead-code subject paused 7d after $MAX_ATTEMPTS attempts: $fpath"
    STATE_JSON="$(_state_upsert "$STATE_JSON" "$full_hash" "$fpath" "$first_seen" "$last_attempts_json" "$new_pause")"
    continue
  fi

  # Add this attempt
  new_attempts_json="$(python3 -c "import sys,json; a=json.loads(sys.argv[1]); a.append(sys.argv[2]); print(json.dumps(a))" "$last_attempts_json" "$NOW_ISO")"

  # Update state
  STATE_JSON="$(_state_upsert "$STATE_JSON" "$full_hash" "$fpath" "$first_seen" "$new_attempts_json" "null")"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] Would generate item for %s (%s dead-code lints, hash=%s)\n' \
      "$fpath" "$lint_count" "$sha8"
    ITEMS_WRITTEN=$(( ITEMS_WRITTEN + 1 ))
    continue
  fi

  # -------------------------------------------------------------------------
  # Generate inbox item
  # -------------------------------------------------------------------------
  mkdir -p "$INBOX_DIR"
  item_file="$INBOX_DIR/02-analyzer-${MODULE_NAME}-${sha8}.md"

  # Format lint list for body
  lint_body="$(python3 - "$lints_json" <<'PYEOF'
import sys, json
lints = json.loads(sys.argv[1])
for l in lints:
    code = l.get('code', '')
    msg = l.get('message', '')
    line = l.get('line', 0)
    print(f"- `{code}` (line {line}): {msg}")
PYEOF
)"

  # Relative path for display
  rel_path="${fpath#$REPO_ROOT/}"

  cat > "$item_file" <<EOF
---
slug: dead-code-${sha8}
source: tier-3
priority: 2
budget_usd: 1.0
model: haiku
touches: [${rel_path}]
needs_gh: false
estimated_minutes: 10
created_from: ${MODULE_NAME}
trust_tier: 3
---

## Aufgabe

Remove dead code / unused symbols in \`${rel_path}\` (${lint_count} lint(s) found by \`dart analyze\`).

## Dead-Code-Lints

${lint_body}

## Acceptance

- All listed lints resolved (symbols removed or annotated if intentional).
- \`dart analyze lib/\` exits clean for this file.
- No regression in existing tests.
EOF

  printf '[%s] Item written: %s\n' "$MODULE_NAME" "$item_file"
  _audit "item-created" "$fpath" "hash=$full_hash lints=${lint_count} item=$item_file"
  ITEMS_WRITTEN=$(( ITEMS_WRITTEN + 1 ))

done <<< "$FILE_LINT_MAP"

# ---------------------------------------------------------------------------
# Persist state
# ---------------------------------------------------------------------------
STATE_JSON="$(printf '%s' "$STATE_JSON" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); d['last_run']='${NOW_ISO}'; print(json.dumps(d,indent=2))")"

[ "$DRY_RUN" -eq 0 ] && _save_state "$STATE_JSON"

printf '[%s] Done. Items generated: %d\n' "$MODULE_NAME" "$ITEMS_WRITTEN"
