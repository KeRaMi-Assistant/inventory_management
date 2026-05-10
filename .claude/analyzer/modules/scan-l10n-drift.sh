#!/usr/bin/env bash
# scan-l10n-drift.sh — Analyzer-Modul: detect l10n drift via check-l10n.py.
#
# Usage:
#   scan-l10n-drift.sh           — full run, writes 1 item to overseer/inbox/ if drift found
#   scan-l10n-drift.sh --dry-run — plan to stdout, no files written
#   scan-l10n-drift.sh --status  — print state JSON to stdout
#
# Dedup key: sha256("scan-l10n-drift" + sorted_all_drift_keys) — stable for same drift set.
# One item/run max — no per-key flood.
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

MODULE_NAME="scan-l10n-drift"
STATE_FILE="${ANALYZER_STATE_FILE:-$REPO_ROOT/.claude/analyzer/state/scan-l10n-drift.json}"
INBOX_DIR="${OVERSEER_INBOX_DIR:-$REPO_ROOT/.claude/overseer/inbox}"
CHECK_L10N="${CHECK_L10N_CMD:-python3 $REPO_ROOT/.claude/scripts/check-l10n.py}"
AUDIT_SH="$REPO_ROOT/.claude/scripts/lib/audit.sh"
NOTIFY_SH="$REPO_ROOT/.claude/scripts/notify.sh"

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
      "scan-l10n-drift" "$msg" 2>/dev/null || true
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
    printf '[scan-l10n-drift] SKIP: inbox has %d items (cap=%d)\n' "$INBOX_CNT" "$INBOX_CAP"
    _audit "skip" "inbox-cap" "inbox=$INBOX_CNT > cap=$INBOX_CAP — no items generated"
    exit 0
  fi
fi

# ---------------------------------------------------------------------------
# Run check-l10n.py --json
# ---------------------------------------------------------------------------
L10N_JSON=""
L10N_EXIT=0
L10N_JSON="$(${CHECK_L10N} --json 2>/dev/null)" || L10N_EXIT=$?

if [ "$L10N_EXIT" -eq 2 ]; then
  printf '[scan-l10n-drift] ERROR: check-l10n.py exited with code 2 (IO/parse error)\n'
  _audit "error" "check-l10n-exit2" "check-l10n.py returned exit code 2"
  exit 1
fi

# Parse drift fields from JSON using python3
# Collects all drift keys/items into a sorted flat list for stable hash.
DRIFT_SUMMARY="$(python3 - "$L10N_JSON" <<'PYEOF'
import sys, json

raw = sys.argv[1]
try:
    d = json.loads(raw)
except Exception as e:
    print(f"PARSE_ERROR: {e}", file=sys.stderr)
    sys.exit(1)

missing_en  = d.get("missing_in_en", [])
missing_de  = d.get("missing_in_de", [])
ph_mismatch = d.get("placeholder_mismatch", [])
hardcoded   = d.get("hardcoded_strings", [])

has_drift = bool(missing_en or missing_de or ph_mismatch or hardcoded)

# Build a stable sorted list of all drift identifiers for dedup hash
all_keys = sorted(set(
    missing_en
    + missing_de
    + [e["key"] for e in ph_mismatch]
    + [f"{e['file']}:{e['line']}" for e in hardcoded]
))

import json as _json
print(_json.dumps({
    "has_drift": has_drift,
    "all_keys": all_keys,
    "missing_en": missing_en,
    "missing_de": missing_de,
    "placeholder_mismatch": ph_mismatch,
    "hardcoded_strings": hardcoded,
}))
PYEOF
)"

if [ $? -ne 0 ]; then
  printf '[scan-l10n-drift] ERROR: failed to parse check-l10n.py JSON output\n'
  _audit "error" "json-parse" "could not parse check-l10n.py --json output"
  exit 1
fi

HAS_DRIFT="$(python3 -c "import sys,json; d=json.loads(sys.argv[1]); print(d['has_drift'])" "$DRIFT_SUMMARY")"

if [ "$HAS_DRIFT" != "True" ]; then
  printf '[scan-l10n-drift] No l10n drift found. Done.\n'
  STATE_JSON="$(printf '%s' "$STATE_JSON" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); d['last_run']='$(_iso_now)'; print(json.dumps(d,indent=2))")"
  [ "$DRY_RUN" -eq 0 ] && _save_state "$STATE_JSON"
  exit 0
fi

# ---------------------------------------------------------------------------
# Compute dedup hash: sha256("scan-l10n-drift" + sorted all_keys joined)
# ---------------------------------------------------------------------------
ALL_KEYS_STR="$(python3 -c "import sys,json; d=json.loads(sys.argv[1]); print('|'.join(d['all_keys']))" "$DRIFT_SUMMARY")"
HASH_INPUT="scan-l10n-drift${ALL_KEYS_STR}"
FULL_HASH="$(_sha256 "$HASH_INPUT")"
SHA8="$(_sha8 "$HASH_INPUT")"

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
    printf '[scan-l10n-drift] SKIP (paused until %s): drift hash=%s\n' "$PAUSED_UNTIL" "$SHA8"
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
  printf '[scan-l10n-drift] PAUSE (3 attempts): drift hash=%s — paused until %s\n' "$SHA8" "$NEW_PAUSE"
  _audit "pause" "l10n-drift-$SHA8" "subject paused until $NEW_PAUSE after $RECENT_COUNT attempts"
  _notify_info "l10n-drift subject paused 7d after $MAX_ATTEMPTS attempts: hash=$SHA8"
  STATE_JSON="$(_state_upsert "$STATE_JSON" "$FULL_HASH" "l10n-drift-$SHA8" "$FIRST_SEEN" "$LAST_ATTEMPTS_JSON" "$NEW_PAUSE")"
  STATE_JSON="$(printf '%s' "$STATE_JSON" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); d['last_run']='${NOW_ISO}'; print(json.dumps(d,indent=2))")"
  [ "$DRY_RUN" -eq 0 ] && _save_state "$STATE_JSON"
  exit 0
fi

# ---------------------------------------------------------------------------
# Add this attempt
# ---------------------------------------------------------------------------
NEW_ATTEMPTS_JSON="$(python3 -c "import sys,json; a=json.loads(sys.argv[1]); a.append(sys.argv[2]); print(json.dumps(a))" "$LAST_ATTEMPTS_JSON" "$NOW_ISO")"

STATE_JSON="$(_state_upsert "$STATE_JSON" "$FULL_HASH" "l10n-drift-$SHA8" "$FIRST_SEEN" "$NEW_ATTEMPTS_JSON" "null")"

# ---------------------------------------------------------------------------
# Dry-run output
# ---------------------------------------------------------------------------
if [ "$DRY_RUN" -eq 1 ]; then
  printf '[dry-run] Would generate l10n-drift item: slug=l10n-drift-%s hash=%s\n' "$SHA8" "$FULL_HASH"
  python3 - "$DRIFT_SUMMARY" <<'PYEOF'
import sys, json
d = json.loads(sys.argv[1])
if d["missing_en"]:
    print(f'  missing_in_en ({len(d["missing_en"])}): ' + ', '.join(d["missing_en"][:5]))
if d["missing_de"]:
    print(f'  missing_in_de ({len(d["missing_de"])}): ' + ', '.join(d["missing_de"][:5]))
if d["placeholder_mismatch"]:
    print(f'  placeholder_mismatch ({len(d["placeholder_mismatch"])}): ' + ', '.join(e["key"] for e in d["placeholder_mismatch"][:5]))
if d["hardcoded_strings"]:
    print(f'  hardcoded_strings ({len(d["hardcoded_strings"])}): ' + ', '.join(f'{e["file"]}:{e["line"]}' for e in d["hardcoded_strings"][:5]))
PYEOF
  STATE_JSON="$(printf '%s' "$STATE_JSON" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); d['last_run']='${NOW_ISO}'; print(json.dumps(d,indent=2))")"
  exit 0
fi

# ---------------------------------------------------------------------------
# Build item body
# ---------------------------------------------------------------------------
ITEM_BODY="$(python3 - "$DRIFT_SUMMARY" "$SHA8" <<'PYEOF'
import sys, json

d = json.loads(sys.argv[1])
sha8 = sys.argv[2]

lines = []
lines.append("## Aufgabe")
lines.append("")
lines.append("l10n-Drift erkannt. Führe `python3 .claude/scripts/check-l10n.py --fix` aus,")
lines.append("um fehlende EN-Keys automatisch zu ergänzen. Anschließend fehlende DE-Keys")
lines.append("und Placeholder-Mismatches manuell prüfen.")
lines.append("")

if d["missing_en"]:
    lines.append(f"## Missing in EN ({len(d['missing_en'])} keys)")
    for k in d["missing_en"]:
        lines.append(f"- `{k}`")
    lines.append("")

if d["missing_de"]:
    lines.append(f"## Missing in DE ({len(d['missing_de'])} keys)")
    for k in d["missing_de"]:
        lines.append(f"- `{k}`")
    lines.append("")

if d["placeholder_mismatch"]:
    lines.append(f"## Placeholder Mismatch ({len(d['placeholder_mismatch'])} keys)")
    for e in d["placeholder_mismatch"]:
        lines.append(f"- `{e['key']}`: DE={e['de']} EN={e['en']}")
    lines.append("")

if d["hardcoded_strings"]:
    lines.append(f"## Hardcoded German Strings ({len(d['hardcoded_strings'])} hits)")
    for e in d["hardcoded_strings"][:20]:
        lines.append(f"- `{e['file']}:{e['line']}` — {e['text'][:80]}")
    if len(d["hardcoded_strings"]) > 20:
        lines.append(f"  … and {len(d['hardcoded_strings']) - 20} more")
    lines.append("")

lines.append("## Fix-Befehl")
lines.append("")
lines.append("```bash")
lines.append("python3 .claude/scripts/check-l10n.py --fix")
lines.append("```")
lines.append("")
lines.append("## Acceptance")
lines.append("")
lines.append("- `python3 .claude/scripts/check-l10n.py` exits 0 (no findings).")
lines.append("- DE + EN ARBs sind symmetrisch, alle Platzhalter stimmen überein.")
lines.append("- Keine hardcoded deutschen Strings mehr in lib/.")

print('\n'.join(lines))
PYEOF
)"

# ---------------------------------------------------------------------------
# Write inbox item
# ---------------------------------------------------------------------------
mkdir -p "$INBOX_DIR"
ITEM_FILE="$INBOX_DIR/02-analyzer-${MODULE_NAME}-${SHA8}.md"

# Check exact dedup: file already exists → skip
if [ -f "$ITEM_FILE" ]; then
  printf '[scan-l10n-drift] SKIP: item already exists: %s\n' "$ITEM_FILE"
  STATE_JSON="$(printf '%s' "$STATE_JSON" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); d['last_run']='${NOW_ISO}'; print(json.dumps(d,indent=2))")"
  _save_state "$STATE_JSON"
  exit 0
fi

cat > "$ITEM_FILE" <<EOF
---
slug: l10n-drift-${SHA8}
source: tier-3
priority: 1
budget_usd: 1.0
model: haiku
touches: [lib/l10n/]
needs_gh: false
estimated_minutes: 10
created_from: ${MODULE_NAME}
trust_tier: 3
---

${ITEM_BODY}
EOF

printf '[scan-l10n-drift] Item written: %s\n' "$ITEM_FILE"
_audit "item-created" "l10n-drift-$SHA8" "hash=$FULL_HASH item=$ITEM_FILE"

# ---------------------------------------------------------------------------
# Persist state
# ---------------------------------------------------------------------------
STATE_JSON="$(printf '%s' "$STATE_JSON" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); d['last_run']='${NOW_ISO}'; print(json.dumps(d,indent=2))")"
_save_state "$STATE_JSON"

printf '[scan-l10n-drift] Done.\n'
