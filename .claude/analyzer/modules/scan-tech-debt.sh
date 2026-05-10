#!/usr/bin/env bash
# scan-tech-debt.sh — Analyzer-Modul: detect old TODO/FIXME/XXX/HACK comments.
#
# Usage:
#   scan-tech-debt.sh           — full run, writes items to overseer/inbox/
#   scan-tech-debt.sh --dry-run — plan to stdout, no files written
#   scan-tech-debt.sh --status  — print state JSON to stdout
#
# Read-Only: never modifies source code.
# Dedup key: sha256(file_path + "scan-tech-debt") — stable across line changes.
# Cap: 5 items/run, sorted oldest-first.
# Pause logic: after 3 attempts on same subject within 30 days → pause 7 days.
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

MODULE_NAME="scan-tech-debt"
STATE_FILE="${ANALYZER_STATE_FILE:-$REPO_ROOT/.claude/analyzer/state/scan-tech-debt.json}"
INBOX_DIR="${OVERSEER_INBOX_DIR:-$REPO_ROOT/.claude/overseer/inbox}"
AUDIT_SH="$REPO_ROOT/.claude/scripts/lib/audit.sh"
NOTIFY_SH="$REPO_ROOT/.claude/scripts/notify.sh"

SEARCH_DIRS=("lib" "supabase" "test" ".claude/scripts" ".claude/agents")
PATTERN="TODO|FIXME|XXX|HACK"
MAX_ITEMS=5
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
      "scan-tech-debt" "$msg" 2>/dev/null || true
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
    printf '[scan-tech-debt] SKIP: inbox has %d items (cap=%d)\n' "$INBOX_CNT" "$INBOX_CAP"
    _audit "skip" "inbox-cap" "inbox=$INBOX_CNT > cap=$INBOX_CAP — no items generated"
    exit 0
  fi
fi

# ---------------------------------------------------------------------------
# Collect TODO/FIXME/XXX/HACK hits with git-blame age filter
# ---------------------------------------------------------------------------
# Each entry: "<age_days>\t<file>\t<line_num>\t<line_content>"
declare -a HITS=()

for dir in "${SEARCH_DIRS[@]}"; do
  abs_dir="$REPO_ROOT/$dir"
  [ -d "$abs_dir" ] || continue

  while IFS=: read -r fpath lineno line_content; do
    # Skip binary, skip this script itself
    [[ "$fpath" == *.sh ]] && [[ "$fpath" == *"$MODULE_NAME"* ]] && continue

    # git blame: get commit date for this line
    blame_date=""
    blame_date="$(git -C "$REPO_ROOT" blame --porcelain -L "${lineno},${lineno}" \
      -- "$fpath" 2>/dev/null \
      | grep '^committer-time ' \
      | awk '{print $2}')" || true

    if [ -z "$blame_date" ]; then
      # Untracked / uncommitted file — skip (no blame date available)
      continue
    fi

    now_epoch="$(date -u +%s)"
    age_secs=$(( now_epoch - blame_date ))
    age_days=$(( age_secs / 86400 ))

    if [ "$age_days" -ge "$AGE_DAYS" ]; then
      HITS+=("${age_days}"$'\t'"${fpath}"$'\t'"${lineno}"$'\t'"${line_content}")
    fi
  done < <(grep -rn --include="*.dart" --include="*.ts" --include="*.js" \
    --include="*.sh" --include="*.md" \
    -E "$PATTERN" "$abs_dir" 2>/dev/null \
    | grep -v "Binary file" || true)
done

# Sort by age descending (oldest first) and cap
if [ "${#HITS[@]}" -eq 0 ]; then
  printf '[scan-tech-debt] No old TODO/FIXME found (>%d days). Done.\n' "$AGE_DAYS"
  STATE_JSON="$(printf '%s' "$STATE_JSON" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); d['last_run']='$(
      _iso_now)'; print(json.dumps(d,indent=2))")"
  [ "$DRY_RUN" -eq 0 ] && _save_state "$STATE_JSON"
  exit 0
fi

# Sort hits by age (field 1) descending — oldest first
IFS=$'\n' SORTED_HITS=($(printf '%s\n' "${HITS[@]}" | sort -rn -t$'\t' -k1)) || true
unset IFS

# ---------------------------------------------------------------------------
# Process hits — dedup, pause check, cap
# ---------------------------------------------------------------------------
NOW_ISO="$(_iso_now)"
NOW_EPOCH="$(date -u +%s)"
ITEMS_WRITTEN=0
declare -a NEW_STATE_SUBJECTS=()

# Build a python helper for state manipulation (avoids jq dependency)
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
  # args: state_json hash file first_seen last_attempts paused_until
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

for hit in "${SORTED_HITS[@]}"; do
  [ "$ITEMS_WRITTEN" -ge "$MAX_ITEMS" ] && break

  IFS=$'\t' read -r age_days fpath lineno line_content <<< "$hit"

  # Compute dedup hash: sha256(file_path + module_name)
  hash_input="${fpath}${MODULE_NAME}"
  full_hash="$(_sha256 "$hash_input")"
  sha8="$(_sha8 "$hash_input")"

  # Load subject state
  subj_json="$(_state_get_subject "$full_hash")"

  first_seen="$(python3 -c "import sys,json; d=json.loads(sys.argv[1]); print(d.get('first_seen',''))" "$subj_json")"
  [ -z "$first_seen" ] && first_seen="$NOW_ISO"

  last_attempts_json="$(python3 -c "import sys,json; d=json.loads(sys.argv[1]); print(json.dumps(d.get('last_attempts',[])))" "$subj_json")"
  paused_until="$(python3 -c "import sys,json; d=json.loads(sys.argv[1]); print(d.get('paused_until') or 'null')" "$subj_json")"

  # Check pause
  if [ "$paused_until" != "null" ] && [ -n "$paused_until" ]; then
    pause_epoch="$(_iso_to_epoch "$paused_until")"
    if [ "$NOW_EPOCH" -lt "$pause_epoch" ]; then
      printf '[scan-tech-debt] SKIP (paused until %s): %s\n' "$paused_until" "$fpath"
      continue
    else
      # Pause expired — reset
      paused_until="null"
      last_attempts_json="[]"
    fi
  fi

  # Attempt-counter check: count attempts in last 30 days
  recent_count="$(python3 - "$last_attempts_json" "$NOW_EPOCH" "$AGE_DAYS" <<'PYEOF'
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

  if [ "$recent_count" -ge "$MAX_ATTEMPTS" ]; then
    # Pause this subject 7 days
    new_pause="$(_date_add_days "$NOW_EPOCH" "$PAUSE_DAYS")"
    printf '[scan-tech-debt] PAUSE (3 attempts): %s — paused until %s\n' "$fpath" "$new_pause"
    _audit "pause" "$fpath" "subject $full_hash paused until $new_pause after $recent_count attempts"
    _notify_info "Tech-debt subject paused 7d after $MAX_ATTEMPTS attempts: $fpath"
    STATE_JSON="$(_state_upsert "$STATE_JSON" "$full_hash" "$fpath" "$first_seen" "$last_attempts_json" "$new_pause")"
    continue
  fi

  # Add this attempt
  new_attempts_json="$(python3 -c "import sys,json; a=json.loads(sys.argv[1]); a.append(sys.argv[2]); print(json.dumps(a))" "$last_attempts_json" "$NOW_ISO")"

  # Update state
  STATE_JSON="$(_state_upsert "$STATE_JSON" "$full_hash" "$fpath" "$first_seen" "$new_attempts_json" "null")"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] Would generate item for %s:%s (age=%s days, hash=%s)\n' \
      "$fpath" "$lineno" "$age_days" "$sha8"
    ITEMS_WRITTEN=$(( ITEMS_WRITTEN + 1 ))
    continue
  fi

  # -------------------------------------------------------------------
  # Generate inbox item
  # -------------------------------------------------------------------
  mkdir -p "$INBOX_DIR"
  item_file="$INBOX_DIR/02-analyzer-${MODULE_NAME}-${sha8}.md"

  # Read a few lines of context around the TODO
  context_lines=""
  if [ -f "$fpath" ]; then
    start=$(( lineno > 2 ? lineno - 2 : 1 ))
    end=$(( lineno + 2 ))
    context_lines="$(awk "NR>=${start} && NR<=${end} {printf \"%4d | %s\n\", NR, \$0}" "$fpath" 2>/dev/null || true)"
  fi

  cat > "$item_file" <<EOF
---
slug: tech-debt-${sha8}
source: tier-3
priority: 2
budget_usd: 1.5
model: sonnet
touches: [${fpath}]
needs_gh: false
estimated_minutes: 15
created_from: ${MODULE_NAME}
trust_tier: 3
---

## Aufgabe

Resolve TODO/FIXME in \`${fpath}:${lineno}\` (older than ${AGE_DAYS} days, age=${age_days} days).

## TODO-Snippet

\`\`\`
${context_lines:-${line_content}}
\`\`\`

## Acceptance

- TODO/FIXME comment removed AND functionality implemented or properly documented.
- \`dart analyze\` (or equivalent linter) exits clean.
- No regression in existing tests.
EOF

  printf '[scan-tech-debt] Item written: %s\n' "$item_file"
  _audit "item-created" "$fpath" "hash=$full_hash age=${age_days}d item=$item_file"
  ITEMS_WRITTEN=$(( ITEMS_WRITTEN + 1 ))
done

# ---------------------------------------------------------------------------
# Persist state
# ---------------------------------------------------------------------------
STATE_JSON="$(printf '%s' "$STATE_JSON" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); d['last_run']='${NOW_ISO}'; print(json.dumps(d,indent=2))")"

[ "$DRY_RUN" -eq 0 ] && _save_state "$STATE_JSON"

printf '[scan-tech-debt] Done. Items generated: %d\n' "$ITEMS_WRITTEN"
