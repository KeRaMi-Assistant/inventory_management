#!/usr/bin/env bash
# scan-mobile-overflow.sh — Analyzer-Modul: parse smoke-full-app-audit findings.json
#                            and create backlog items for mobile overflow / layout issues.
#
# Usage:
#   scan-mobile-overflow.sh           — full run, writes items to overseer/inbox/
#   scan-mobile-overflow.sh --dry-run — plan to stdout, no files written
#   scan-mobile-overflow.sh --status  — print state JSON to stdout
#
# Read-Only: never modifies source code.
# Dedup key: sha256("scan-mobile-overflow" + route + category)
# Cap: 3 items/run (mobile fixes are complex).
# Pause logic: after 3 attempts on same subject within 30 days → pause 7 days.
# Stale check: if latest test-run > 7 days old → skip (data too old to act on).
# Inbox-Cap: skip if .claude/overseer/inbox/ has > 50 files.
#
# Filtered categories (phone + tablet viewports only):
#   pixel-overflow, mobile-no-bottom-nav, touch-target-too-small

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

MODULE_NAME="scan-mobile-overflow"
STATE_FILE="${ANALYZER_STATE_FILE:-$REPO_ROOT/.claude/analyzer/state/scan-mobile-overflow.json}"
INBOX_DIR="${OVERSEER_INBOX_DIR:-$REPO_ROOT/.claude/overseer/inbox}"
AUDIT_SH="$REPO_ROOT/.claude/scripts/lib/audit.sh"
NOTIFY_SH="$REPO_ROOT/.claude/scripts/notify.sh"
TEST_RUNS_DIR="${TEST_RUNS_DIR_OVERRIDE:-$REPO_ROOT/.claude/test-runs}"

MAX_ITEMS=3
INBOX_CAP=50
AGE_DAYS=30
PAUSE_DAYS=7
MAX_ATTEMPTS=3
STALE_DAYS=7

# Mobile/tablet viewport labels that we care about
MOBILE_VIEWPORTS=("phone" "tablet")

# Categories that trigger a backlog item
MOBILE_CATEGORIES=("pixel-overflow" "mobile-no-bottom-nav" "touch-target-too-small")

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
# Find latest test-run with findings.json
# ---------------------------------------------------------------------------
LATEST_RUN_DIR=""
FINDINGS_FILE=""

if [ -d "$TEST_RUNS_DIR" ]; then
  LATEST_RUN_DIR="$(find "$TEST_RUNS_DIR" -maxdepth 1 -type d -name '20*' 2>/dev/null \
    | sort -r | head -1 || true)"
fi

if [ -z "$LATEST_RUN_DIR" ]; then
  printf '[%s] No test-runs found — skipping.\n' "$MODULE_NAME"
  _audit "skip" "no-test-run" "no test-run directories found under $TEST_RUNS_DIR"
  exit 0
fi

FINDINGS_FILE="$LATEST_RUN_DIR/findings.json"

if [ ! -f "$FINDINGS_FILE" ]; then
  printf '[%s] findings.json not found in %s — skipping.\n' "$MODULE_NAME" "$LATEST_RUN_DIR"
  _audit "skip" "no-findings-json" "missing $FINDINGS_FILE"
  exit 0
fi

# ---------------------------------------------------------------------------
# Stale-run check (> STALE_DAYS days)
# ---------------------------------------------------------------------------
_iso_to_epoch() {
  python3 -c "import datetime; \
dt=datetime.datetime.strptime('$1','%Y-%m-%dT%H:%M:%SZ'); \
print(int(dt.replace(tzinfo=datetime.timezone.utc).timestamp()))" 2>/dev/null || echo 0
}

_date_add_days() {
  local epoch="$1" days="$2"
  local target=$(( epoch + days * 86400 ))
  if date -r "$target" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null; then :
  else date -u -d "@$target" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
       python3 -c "import datetime; print(datetime.datetime.utcfromtimestamp($target).strftime('%Y-%m-%dT%H:%M:%SZ'))"; fi
}

NOW_EPOCH="$(date -u +%s)"
NOW_ISO="$(_iso_now)"

# Extract started_at from findings.json
RUN_STARTED="$(python3 -c "
import sys, json
with open(sys.argv[1]) as f:
    d = json.load(f)
print(d.get('started_at') or d.get('started') or '')
" "$FINDINGS_FILE" 2>/dev/null || true)"

if [ -n "$RUN_STARTED" ]; then
  RUN_EPOCH="$(_iso_to_epoch "$RUN_STARTED")"
  RUN_AGE_DAYS=$(( (NOW_EPOCH - RUN_EPOCH) / 86400 ))
  if [ "$RUN_AGE_DAYS" -gt "$STALE_DAYS" ]; then
    printf '[%s] WARNING: test-run is %d days old (stale > %d days) — skipping.\n' \
      "$MODULE_NAME" "$RUN_AGE_DAYS" "$STALE_DAYS"
    _audit "skip" "stale-run" "run_dir=$LATEST_RUN_DIR age=${RUN_AGE_DAYS}d > stale_threshold=${STALE_DAYS}d"
    exit 0
  fi
else
  printf '[%s] WARNING: could not parse started_at from findings.json — proceeding anyway.\n' "$MODULE_NAME"
fi

# ---------------------------------------------------------------------------
# Parse findings.json — collect mobile/tablet findings with target categories
# (single Python pass: collect + filter in one step, output written to tmpfile)
# ---------------------------------------------------------------------------
_FINDINGS_TMP="$(mktemp)"
trap 'rm -f "$_FINDINGS_TMP"' EXIT

python3 - "$FINDINGS_FILE" <<'PYEOF' > "$_FINDINGS_TMP" 2>/dev/null || true
import sys, json

CATEGORIES = {"pixel-overflow", "mobile-no-bottom-nav", "touch-target-too-small"}
VIEWPORTS  = {"phone", "tablet"}

findings_file = sys.argv[1]
with open(findings_file) as f:
    data = json.load(f)

results = []

def process_finding(finding, route_hint=""):
    cat = finding.get("category", "")
    if cat not in CATEGORIES:
        return
    vp = finding.get("viewport", finding.get("viewport_label", ""))
    # Only emit if viewport is mobile/tablet (or empty — unknown, included conservatively)
    if vp and vp not in VIEWPORTS:
        return
    route = finding.get("route", route_hint or "unknown")
    screenshot = finding.get("screenshot", finding.get("screenshot_path", ""))
    results.append("\t".join([route, cat, vp, screenshot]))

# Flat findings array
for f in data.get("findings", []):
    process_finding(f)

# Route-level findings
for r in data.get("routes", []):
    for f in r.get("findings", []):
        process_finding(f, route_hint=r.get("route", ""))

# Top-level routes: overflow_h flag + per-route findings
for r in data.get("top_level_routes", []):
    route = r.get("route", "")
    if r.get("overflow_h"):
        for vp_label in ("phone", "tablet"):
            if r.get(f"overflow_{vp_label}"):
                results.append("\t".join([route, "pixel-overflow", vp_label, ""]))
    for f in r.get("findings", []):
        process_finding(f, route_hint=route)

# Deduplicate while preserving order
seen = set()
for row in results:
    if row not in seen:
        seen.add(row)
        print(row)
PYEOF

FILTERED_TSV="$(cat "$_FINDINGS_TMP")"

if [ -z "$FILTERED_TSV" ]; then
  printf '[%s] No relevant mobile findings in %s. Done.\n' "$MODULE_NAME" "$FINDINGS_FILE"
  STATE_JSON="$(printf '%s' "$STATE_JSON" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); d['last_run']='${NOW_ISO}'; print(json.dumps(d,indent=2))")"
  [ "$DRY_RUN" -eq 0 ] && _save_state "$STATE_JSON"
  exit 0
fi

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
  python3 - "$1" "$2" "$3" "$4" "$5" "$6" "$7" <<'PYEOF'
import sys, json
state_json, h, route, category, first_seen, last_attempts_json, paused_until = sys.argv[1:]
d = json.loads(state_json)
subjs = d.setdefault('subjects', {})
subjs[h] = {
    'route': route,
    'category': category,
    'first_seen': first_seen,
    'last_attempts': json.loads(last_attempts_json),
    'paused_until': paused_until if paused_until != 'null' else None,
}
print(json.dumps(d, indent=2))
PYEOF
}

# ---------------------------------------------------------------------------
# Route → touches path mapping
# ---------------------------------------------------------------------------
_route_to_touches() {
  local route="$1"
  python3 - "$route" <<'PYEOF'
import sys, re

route = sys.argv[1]
# Strip leading slash and query params
slug = re.sub(r'^/', '', route).split('?')[0].split('__')[0]
slug = re.sub(r'[<>].*', '', slug)  # remove dynamic segments like <slug>
slug = slug.rstrip('/')

# Map common routes to file paths
mapping = {
    'dashboard': 'lib/screens/dashboard_screen.dart',
    'deals': 'lib/screens/deals_screen.dart',
    'tickets': 'lib/screens/tickets_screen.dart',
    'inbox': 'lib/screens/inbox_screen.dart',
    'inventory': 'lib/screens/inventory_screen.dart',
    'suppliers': 'lib/screens/suppliers_screen.dart',
    'statistics': 'lib/screens/statistics_screen.dart',
    'activity': 'lib/screens/activity_screen.dart',
    'help': 'lib/screens/help_screen.dart',
    'settings': 'lib/screens/settings_screen.dart',
    'pricing': 'lib/screens/pricing_screen.dart',
    'billing-profile': 'lib/screens/billing_profile_screen.dart',
    'main': 'lib/screens/main_screen.dart',
    'login': 'lib/screens/login_screen.dart',
    'register': 'lib/screens/register_screen.dart',
    'forgot-password': 'lib/screens/forgot_password_screen.dart',
}

path = mapping.get(slug)
if path:
    print(path)
else:
    # Fallback: derive from slug
    safe = re.sub(r'[^a-z0-9_]', '_', slug.replace('-', '_'))
    print(f'lib/screens/{safe}_screen.dart')
PYEOF
}

# ---------------------------------------------------------------------------
# Process findings — dedup, pause check, cap
# ---------------------------------------------------------------------------
ITEMS_WRITTEN=0

while IFS=$'\t' read -r route category viewport screenshot; do
  [ "$ITEMS_WRITTEN" -ge "$MAX_ITEMS" ] && break
  [ -z "$route" ] && continue
  [ -z "$category" ] && continue

  # Dedup hash: sha256("scan-mobile-overflow" + route + category)
  hash_input="${MODULE_NAME}${route}${category}"
  full_hash="$(_sha256 "$hash_input")"
  sha8="$(_sha8 "$hash_input")"

  subj_json="$(_state_get_subject "$full_hash")"

  first_seen="$(python3 -c "import sys,json; d=json.loads(sys.argv[1]); print(d.get('first_seen',''))" "$subj_json")"
  [ -z "$first_seen" ] && first_seen="$NOW_ISO"

  last_attempts_json="$(python3 -c "import sys,json; d=json.loads(sys.argv[1]); print(json.dumps(d.get('last_attempts',[])))" "$subj_json")"
  paused_until="$(python3 -c "import sys,json; d=json.loads(sys.argv[1]); print(d.get('paused_until') or 'null')" "$subj_json")"

  # Check pause
  if [ "$paused_until" != "null" ] && [ -n "$paused_until" ]; then
    pause_epoch="$(_iso_to_epoch "$paused_until")"
    if [ "$NOW_EPOCH" -lt "$pause_epoch" ]; then
      printf '[%s] SKIP (paused until %s): %s / %s\n' "$MODULE_NAME" "$paused_until" "$route" "$category"
      continue
    else
      paused_until="null"
      last_attempts_json="[]"
    fi
  fi

  # Count recent attempts (within AGE_DAYS)
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
    printf '[%s] PAUSE (%d attempts): %s / %s — paused until %s\n' \
      "$MODULE_NAME" "$MAX_ATTEMPTS" "$route" "$category" "$new_pause"
    _audit "pause" "${route}/${category}" "subject $full_hash paused until $new_pause after $recent_count attempts"
    _notify_info "Mobile-overflow subject paused 7d after ${MAX_ATTEMPTS} attempts: ${route} / ${category}"
    STATE_JSON="$(_state_upsert "$STATE_JSON" "$full_hash" "$route" "$category" "$first_seen" "$last_attempts_json" "$new_pause")"
    continue
  fi

  # Record this attempt
  new_attempts_json="$(python3 -c "import sys,json; a=json.loads(sys.argv[1]); a.append(sys.argv[2]); print(json.dumps(a))" \
    "$last_attempts_json" "$NOW_ISO")"

  STATE_JSON="$(_state_upsert "$STATE_JSON" "$full_hash" "$route" "$category" "$first_seen" "$new_attempts_json" "null")"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] Would generate item for route=%s category=%s viewport=%s (hash=%s)\n' \
      "$route" "$category" "$viewport" "$sha8"
    ITEMS_WRITTEN=$(( ITEMS_WRITTEN + 1 ))
    continue
  fi

  # ---------------------------------------------------------------------------
  # Generate inbox item
  # ---------------------------------------------------------------------------
  mkdir -p "$INBOX_DIR"
  item_file="$INBOX_DIR/02-analyzer-${MODULE_NAME}-${sha8}.md"

  touches="$(_route_to_touches "$route")"

  # Build screenshot line if present
  screenshot_line=""
  if [ -n "$screenshot" ]; then
    screenshot_line="- **Screenshot:** \`${screenshot}\`"
  fi

  cat > "$item_file" <<EOF
---
slug: mobile-overflow-${sha8}
source: tier-3
priority: 1
budget_usd: 2.0
model: sonnet
touches: [${touches}]
needs_gh: false
estimated_minutes: 30
created_from: ${MODULE_NAME}
trust_tier: 3
---

## Aufgabe

Fix mobile layout issue detected by smoke-full-app-audit.

- **Route:** \`${route}\`
- **Category:** \`${category}\`
- **Viewport:** \`${viewport:-phone/tablet}\`
${screenshot_line}

## Hintergrund

Das Analyzer-Modul \`scan-mobile-overflow\` hat dieses Finding aus dem letzten
\`smoke-full-app-audit\`-Run (\`${LATEST_RUN_DIR##*/}\`) extrahiert.

**Kategorie-Details:**
- \`pixel-overflow\`: \`scrollWidth > innerWidth\` oder Element rechts > Viewport-Breite auf Phone/Tablet.
- \`mobile-no-bottom-nav\`: Phone-Viewport zeigt Sidebar statt Bottom-Nav oder gar keine Top-Level-Nav.
- \`touch-target-too-small\`: Tap-Target < 44 dp im Phone-Pass.

## Acceptance

- Finding \`${category}\` auf Route \`${route}\` im Phone/Tablet-Viewport behoben.
- Kein horizontales Scrollen auf 360×640 und 390×844.
- Touch-Targets mind. 48×48 dp.
- Bottom-Nav bei \`MediaQuery.sizeOf(context).width < 600\`.
- \`flutter analyze\` exits clean.
- Kein Regression in bestehenden Tests.
EOF

  printf '[%s] Item written: %s\n' "$MODULE_NAME" "$item_file"
  _audit "item-created" "${route}/${category}" "hash=$full_hash viewport=$viewport item=$item_file"
  ITEMS_WRITTEN=$(( ITEMS_WRITTEN + 1 ))

done <<< "$FILTERED_TSV"

# ---------------------------------------------------------------------------
# Persist state
# ---------------------------------------------------------------------------
STATE_JSON="$(printf '%s' "$STATE_JSON" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); d['last_run']='${NOW_ISO}'; print(json.dumps(d,indent=2))")"

[ "$DRY_RUN" -eq 0 ] && _save_state "$STATE_JSON"

printf '[%s] Done. Items generated: %d\n' "$MODULE_NAME" "$ITEMS_WRITTEN"
