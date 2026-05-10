#!/usr/bin/env bash
# scan-dependency-rot.sh — Analyzer-Modul: detect major-version dependency bumps.
#
# Usage:
#   scan-dependency-rot.sh           — full run (Path A: flutter pub outdated)
#   scan-dependency-rot.sh --dry-run — plan to stdout, no files written
#   scan-dependency-rot.sh --status  — print state JSON to stdout
#
# Path A (default): flutter pub outdated --json → filter major bumps → cap 3 items/run.
# Path B (optional): set RENOVATE_DASHBOARD_ISSUE_NUM → parse gh issue checkboxes.
#
# Dedup key: sha256("scan-dependency-rot" + <package> + <latest_version>).
# Cap: 3 items/run.
# Inbox-Cap: skip if .claude/overseer/inbox/ has > 50 files.
# last_fix_attempt counter: after 3 attempts within 30 days → pause 7 days.

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

MODULE_NAME="scan-dependency-rot"
STATE_FILE="${ANALYZER_STATE_FILE:-$REPO_ROOT/.claude/analyzer/state/scan-dependency-rot.json}"
INBOX_DIR="${OVERSEER_INBOX_DIR:-$REPO_ROOT/.claude/overseer/inbox}"
AUDIT_SH="$REPO_ROOT/.claude/scripts/lib/audit.sh"
NOTIFY_SH="$REPO_ROOT/.claude/scripts/notify.sh"

MAX_ITEMS=3
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
# State helpers (Python-based to avoid jq dependency)
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
  python3 - "$1" "$2" "$3" "$4" "$5" "$6" "$7" <<'PYEOF'
import sys, json
state_json, h, pkg, current_ver, first_seen, last_attempts_json, paused_until = sys.argv[1:]
d = json.loads(state_json)
subjs = d.setdefault('subjects', {})
subjs[h] = {
    'package': pkg,
    'current': current_ver,
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
# Collect candidates
# Format: "pkg\tcurrent\tlatest"
# ---------------------------------------------------------------------------
declare -a CANDIDATES=()

# ---------------------------------------------------------------------------
# Path B: Renovate Dashboard Issue
# ---------------------------------------------------------------------------
if [ -n "${RENOVATE_DASHBOARD_ISSUE_NUM:-}" ]; then
  printf '[%s] Path B: reading Renovate Dashboard Issue #%s\n' "$MODULE_NAME" "$RENOVATE_DASHBOARD_ISSUE_NUM"

  GH_BIN="${GH_BIN:-gh}"
  if command -v "$GH_BIN" >/dev/null 2>&1; then
    issue_body="$("$GH_BIN" issue view "$RENOVATE_DASHBOARD_ISSUE_NUM" --json body -q '.body' 2>/dev/null || true)"
    if [ -n "$issue_body" ]; then
      # Parse unchecked boxes (lines starting with "- [ ] ")
      # Renovate format example: "- [ ] <!-- rebase-branch=... --> **pkg** (`1.0.0` -> `2.0.0`)"
      # Write body to temp file to avoid bash heredoc-in-process-substitution limitation
      _tmp_body="$(mktemp /tmp/dep-rot-body.XXXXXX)"
      printf '%s\n' "$issue_body" > "$_tmp_body"

      _parse_renovate_body() {
        local body_file="$1"
python3 - "$body_file" <<'PYEOF'
import sys, re

with open(sys.argv[1]) as f:
    body = f.read()

for line in body.splitlines():
    if not line.startswith('- [ ]'):
        continue
    # Extract package name (bold markdown **pkg**)
    pkg_match = re.search(r'\*\*([^*]+)\*\*', line)
    if not pkg_match:
        pkg_match = re.search(r'`([a-z][a-z0-9_-]+)`', line)
    if not pkg_match:
        continue
    pkg = pkg_match.group(1).strip()

    # Extract version range: `1.x.y` -> `2.x.y` or (1.x → 2.x) or (1.x.y -> 2.x.y)
    ver_match = re.search(r'`(\d+\.\d+[.\d]*)` ?[-→]+ ?`(\d+\.\d+[.\d]*)`', line)
    if not ver_match:
        ver_match = re.search(r'\((\d+\.\d+[.\d]*) ?[-→>]+ ?(\d+\.\d+[.\d]*)\)', line)
    if not ver_match:
        ver_match = re.search(r'(\d+\.\d+[.\d]*) ?[-→]+ ?(\d+\.\d+[.\d]*)', line)
    if not ver_match:
        continue

    current_v = ver_match.group(1)
    latest_v  = ver_match.group(2)

    try:
        current_major = int(current_v.split('.')[0])
        latest_major  = int(latest_v.split('.')[0])
    except ValueError:
        continue

    if latest_major > current_major:
        print(f"{pkg}\t{current_v}\t{latest_v}")
PYEOF
      }

      while IFS=$'\t' read -r pkg current latest; do
        [ -n "$pkg" ] && CANDIDATES+=("${pkg}"$'\t'"${current}"$'\t'"${latest}")
      done < <(_parse_renovate_body "$_tmp_body")

      rm -f "$_tmp_body" 2>/dev/null || true
    else
      printf '[%s] WARNING: gh issue view returned empty body — falling back to Path A\n' "$MODULE_NAME"
    fi
  else
    printf '[%s] WARNING: gh not found — falling back to Path A\n' "$MODULE_NAME"
  fi
fi

# ---------------------------------------------------------------------------
# Path A: flutter pub outdated --json (default or fallback)
# ---------------------------------------------------------------------------
if [ "${#CANDIDATES[@]}" -eq 0 ]; then
  FLUTTER_BIN="${FLUTTER_BIN:-flutter}"

  if ! command -v "$FLUTTER_BIN" >/dev/null 2>&1; then
    printf '[%s] flutter not found — exit 0 (no-op)\n' "$MODULE_NAME"
    exit 0
  fi

  printf '[%s] Path A: running flutter pub outdated --json\n' "$MODULE_NAME"

  outdated_json=""
  outdated_json="$(cd "$REPO_ROOT" && timeout 60 "$FLUTTER_BIN" pub outdated --json 2>/dev/null || true)"

  if [ -z "$outdated_json" ]; then
    printf '[%s] flutter pub outdated returned empty — exit 0\n' "$MODULE_NAME"
    exit 0
  fi

  # Parse JSON: filter packages where current major < latest major
  while IFS=$'\t' read -r pkg current latest; do
    [ -n "$pkg" ] && CANDIDATES+=("${pkg}"$'\t'"${current}"$'\t'"${latest}")
  done < <(python3 - "$outdated_json" <<'PYEOF'
import sys, json

try:
    data = json.loads(sys.argv[1])
except Exception:
    sys.exit(0)

packages = data.get('packages', [])
for pkg in packages:
    name = pkg.get('package', '')
    current_info = pkg.get('current') or {}
    latest_info  = pkg.get('latest')  or {}
    current_v = current_info.get('version', '')
    latest_v  = latest_info.get('version', '')
    if not current_v or not latest_v:
        continue
    try:
        current_major = int(current_v.split('.')[0])
        latest_major  = int(latest_v.split('.')[0])
    except ValueError:
        continue
    if latest_major > current_major:
        print(f"{name}\t{current_v}\t{latest_v}")
PYEOF
)
fi

if [ "${#CANDIDATES[@]}" -eq 0 ]; then
  printf '[%s] No major-version bumps found. Done.\n' "$MODULE_NAME"
  STATE_JSON="$(printf '%s' "$STATE_JSON" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); d['last_run']='$(_iso_now)'; print(json.dumps(d,indent=2))")"
  [ "$DRY_RUN" -eq 0 ] && _save_state "$STATE_JSON"
  exit 0
fi

# ---------------------------------------------------------------------------
# Process candidates — dedup, pause check, cap
# ---------------------------------------------------------------------------
NOW_ISO="$(_iso_now)"
NOW_EPOCH="$(date -u +%s)"
ITEMS_WRITTEN=0

for candidate in "${CANDIDATES[@]}"; do
  [ "$ITEMS_WRITTEN" -ge "$MAX_ITEMS" ] && break

  IFS=$'\t' read -r pkg current_v latest_v <<< "$candidate"

  # Dedup hash: sha256(module_name + pkg + latest_version)
  hash_input="${MODULE_NAME}${pkg}${latest_v}"
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
      printf '[%s] SKIP (paused until %s): %s\n' "$MODULE_NAME" "$paused_until" "$pkg"
      continue
    else
      paused_until="null"
      last_attempts_json="[]"
    fi
  fi

  # Attempt-counter: count attempts in last 30 days
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
    new_pause="$(_date_add_days "$NOW_EPOCH" "$PAUSE_DAYS")"
    printf '[%s] PAUSE (3 attempts): %s — paused until %s\n' "$MODULE_NAME" "$pkg" "$new_pause"
    _audit "pause" "$pkg" "subject $full_hash paused until $new_pause after $recent_count attempts"
    _notify_info "Dep-rot subject paused 7d after $MAX_ATTEMPTS attempts: $pkg"
    STATE_JSON="$(_state_upsert "$STATE_JSON" "$full_hash" "$pkg" "$current_v" "$first_seen" "$last_attempts_json" "$new_pause")"
    continue
  fi

  # Add this attempt
  new_attempts_json="$(python3 -c "import sys,json; a=json.loads(sys.argv[1]); a.append(sys.argv[2]); print(json.dumps(a))" "$last_attempts_json" "$NOW_ISO")"

  # Update state
  STATE_JSON="$(_state_upsert "$STATE_JSON" "$full_hash" "$pkg" "$current_v" "$first_seen" "$new_attempts_json" "null")"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] Would generate item for %s (%s → %s, hash=%s)\n' \
      "$pkg" "$current_v" "$latest_v" "$sha8"
    ITEMS_WRITTEN=$(( ITEMS_WRITTEN + 1 ))
    continue
  fi

  # -------------------------------------------------------------------------
  # Generate inbox item
  # -------------------------------------------------------------------------
  mkdir -p "$INBOX_DIR"
  item_file="$INBOX_DIR/02-analyzer-${MODULE_NAME}-${sha8}.md"

  cat > "$item_file" <<EOF
---
slug: dep-rot-${pkg}-${sha8}
source: tier-3
priority: 1
budget_usd: 2.0
model: sonnet
touches: [pubspec.yaml]
needs_gh: false
needs_dispute: true
estimated_minutes: 60
created_from: ${MODULE_NAME}
trust_tier: 3
---

## Aufgabe

Update \`${pkg}\` from \`${current_v}\` → \`${latest_v}\` (major-version bump).

This is a **breaking-change** upgrade — review the changelog before applying.

- Package: **${pkg}**
- Current: \`${current_v}\`
- Latest:  \`${latest_v}\`
- Changelog: https://pub.dev/packages/${pkg}/changelog

## Schritte

1. Read the changelog for breaking changes between \`${current_v}\` and \`${latest_v}\`.
2. Update \`pubspec.yaml\`: set \`${pkg}: ^${latest_v}\`.
3. Run \`flutter pub get\`.
4. Fix any compile errors caused by API changes.
5. Run \`flutter analyze\` + \`flutter test\` — must be clean.

## Acceptance

- \`pubspec.yaml\` references \`${pkg}\` at major version \`${latest_v%%.*}\`.
- \`flutter analyze\` exits 0.
- Existing tests pass.
- \`needs_dispute: true\` — this item must pass dispute before auto-merge.
EOF

  printf '[%s] Item written: %s\n' "$MODULE_NAME" "$item_file"
  _audit "item-created" "$pkg" "hash=$full_hash current=$current_v latest=$latest_v item=$item_file"
  ITEMS_WRITTEN=$(( ITEMS_WRITTEN + 1 ))
done

# ---------------------------------------------------------------------------
# Persist state
# ---------------------------------------------------------------------------
STATE_JSON="$(printf '%s' "$STATE_JSON" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); d['last_run']='${NOW_ISO}'; print(json.dumps(d,indent=2))")"

[ "$DRY_RUN" -eq 0 ] && _save_state "$STATE_JSON"

printf '[%s] Done. Items generated: %d\n' "$MODULE_NAME" "$ITEMS_WRITTEN"
