#!/usr/bin/env bash
# scan-test-coverage.sh — Analyzer-Modul: detect service-layer test-coverage drops.
#
# Usage:
#   scan-test-coverage.sh           — full run, writes items to overseer/inbox/
#   scan-test-coverage.sh --dry-run — plan to stdout, no files written
#   scan-test-coverage.sh --status  — print state JSON to stdout
#
# Read-Only: never modifies source code.
# Dedup: hysteresis — no re-alert until coverage recovers by +2 pts.
# Pause logic: after 3 failed fix attempts without recovery → pause 7 days.
# Inbox-Cap: skip if .claude/overseer/inbox/ has > 50 files.

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

MODULE_NAME="scan-test-coverage"
STATE_FILE="${ANALYZER_STATE_FILE:-$REPO_ROOT/.claude/analyzer/state/scan-test-coverage.json}"
INBOX_DIR="${OVERSEER_INBOX_DIR:-$REPO_ROOT/.claude/overseer/inbox}"
AUDIT_SH="$REPO_ROOT/.claude/scripts/lib/audit.sh"
NOTIFY_SH="$REPO_ROOT/.claude/scripts/notify.sh"
COVERAGE_DIR="${COVERAGE_DIR:-$REPO_ROOT/coverage}"
LCOV_INFO="$COVERAGE_DIR/lcov.info"

INBOX_CAP=50
PAUSE_DAYS=7
MAX_ATTEMPTS=3
SERVICES_PATH="lib/services/"
# Alert threshold: drop of more than 5 percentage points triggers an item
ALERT_THRESHOLD=5
# Hysteresis: must recover this many points above last_alert_pct before re-alerting
HYSTERESIS=2
# flutter test timeout in seconds (5 min)
FLUTTER_TIMEOUT=300

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
# Status-only mode
# ---------------------------------------------------------------------------
if [ "$STATUS_ONLY" -eq 1 ]; then
  if [ -f "$STATE_FILE" ]; then
    cat "$STATE_FILE"
  else
    printf '{"last_run":null,"last_coverage_pct":null,"last_alert_pct":null,"last_fix_attempt":0,"paused_until":null}\n'
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
    printf '{"last_run":null,"last_coverage_pct":null,"last_alert_pct":null,"last_fix_attempt":0,"paused_until":null}\n'
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
    _audit "skip" "inbox-cap" "inbox=$INBOX_CNT > cap=$INBOX_CAP"
    exit 0
  fi
fi

# ---------------------------------------------------------------------------
# Check pause state
# ---------------------------------------------------------------------------
NOW_EPOCH="$(date -u +%s)"
NOW_ISO="$(_iso_now)"

PAUSED_UNTIL="$(python3 -c "import sys,json; d=json.loads(sys.argv[1]); print(d.get('paused_until') or 'null')" "$STATE_JSON")"
if [ "$PAUSED_UNTIL" != "null" ] && [ -n "$PAUSED_UNTIL" ]; then
  pause_epoch="$(_iso_to_epoch "$PAUSED_UNTIL")"
  if [ "$NOW_EPOCH" -lt "$pause_epoch" ]; then
    printf '[%s] SKIP: paused until %s\n' "$MODULE_NAME" "$PAUSED_UNTIL"
    _audit "skip" "paused" "paused_until=$PAUSED_UNTIL"
    exit 0
  fi
  # Pause expired — reset fix-attempt counter
  STATE_JSON="$(python3 -c "
import sys, json
d = json.loads(sys.argv[1])
d['paused_until'] = None
d['last_fix_attempt'] = 0
print(json.dumps(d, indent=2))
" "$STATE_JSON")"
fi

# ---------------------------------------------------------------------------
# Run flutter test --coverage
# ---------------------------------------------------------------------------
printf '[%s] Running flutter test --coverage (timeout=%ds)…\n' "$MODULE_NAME" "$FLUTTER_TIMEOUT"

if ! command -v flutter &>/dev/null; then
  printf '[%s] WARNING: flutter not in PATH — skipping coverage check.\n' "$MODULE_NAME"
  _audit "skip" "no-flutter" "flutter not found in PATH"
  exit 0
fi

FLUTTER_EXIT=0
(
  cd "$REPO_ROOT"
  timeout "$FLUTTER_TIMEOUT" flutter test --coverage 2>&1
) || FLUTTER_EXIT=$?

if [ "$FLUTTER_EXIT" -ne 0 ]; then
  if [ "$FLUTTER_EXIT" -eq 124 ]; then
    printf '[%s] WARNING: flutter test --coverage timed out after %ds — skipping.\n' \
      "$MODULE_NAME" "$FLUTTER_TIMEOUT"
    _audit "skip" "flutter-timeout" "timeout=${FLUTTER_TIMEOUT}s"
  else
    printf '[%s] WARNING: flutter test --coverage exited %d (crashed) — skipping.\n' \
      "$MODULE_NAME" "$FLUTTER_EXIT"
    _audit "skip" "flutter-crash" "exit=$FLUTTER_EXIT"
  fi
  exit 0
fi

if [ ! -f "$LCOV_INFO" ]; then
  printf '[%s] WARNING: coverage/lcov.info not found after flutter test — skipping.\n' "$MODULE_NAME"
  _audit "skip" "no-lcov" "lcov.info missing"
  exit 0
fi

# ---------------------------------------------------------------------------
# Parse coverage for lib/services/ — prefer lcov --summary, fallback Python
# ---------------------------------------------------------------------------
_parse_coverage_lcov_cli() {
  # Filter lcov.info to only lib/services/ files then run lcov --summary
  local tmp_filtered
  tmp_filtered="$(mktemp /tmp/lcov_services_XXXXXX.info)"
  python3 - "$LCOV_INFO" "$SERVICES_PATH" "$tmp_filtered" <<'PYEOF'
import sys, re
lcov_file, prefix, outfile = sys.argv[1], sys.argv[2], sys.argv[3]

sections = []
cur = []
in_section = False
with open(lcov_file) as f:
    for line in f:
        if line.startswith('SF:'):
            path = line.strip()[3:]
            if prefix in path:
                in_section = True
            else:
                in_section = False
        if in_section:
            cur.append(line)
        elif cur and line.strip() == 'end_of_record':
            cur.append(line)
            sections.extend(cur)
            cur = []
        elif not in_section:
            cur = []

with open(outfile, 'w') as f:
    f.write(''.join(sections))
PYEOF

  local result=""
  if command -v lcov &>/dev/null; then
    result="$(lcov --summary "$tmp_filtered" 2>&1)"
  fi
  rm -f "$tmp_filtered"
  printf '%s' "$result"
}

_parse_coverage_python() {
  # Pure-python parse of lcov.info for lib/services/ files
  python3 - "$LCOV_INFO" "$SERVICES_PATH" <<'PYEOF'
import sys, re

lcov_file = sys.argv[1]
prefix = sys.argv[2]

total_found = 0
total_hit = 0
file_stats = {}

current_file = None
in_section = False

with open(lcov_file) as f:
    for line in f:
        line = line.strip()
        if line.startswith('SF:'):
            path = line[3:]
            if prefix in path:
                in_section = True
                current_file = path
                file_stats[path] = {'found': 0, 'hit': 0}
            else:
                in_section = False
                current_file = None
        elif in_section and line.startswith('LF:'):
            found = int(line[3:])
            file_stats[current_file]['found'] = found
            total_found += found
        elif in_section and line.startswith('LH:'):
            hit = int(line[3:])
            file_stats[current_file]['hit'] = hit
            total_hit += hit
        elif line == 'end_of_record':
            in_section = False
            current_file = None

if total_found == 0:
    print('COVERAGE:0.0')
    sys.exit(0)

pct = round(100.0 * total_hit / total_found, 2)
print(f'COVERAGE:{pct}')

# File-level stats sorted by coverage ascending (worst first)
file_lines = []
for path, stats in file_stats.items():
    f = stats['found']
    h = stats['hit']
    if f > 0:
        p = round(100.0 * h / f, 2)
        file_lines.append(f'FILE:{path}|{h}/{f}|{p}%')
    else:
        file_lines.append(f'FILE:{path}|0/0|n/a')

# Sort worst first
def sort_key(l):
    parts = l.split('|')
    try:
        return float(parts[-1].rstrip('%'))
    except Exception:
        return 999
file_lines.sort(key=sort_key)

for fl in file_lines:
    print(fl)
PYEOF
}

# Try lcov CLI first, then fall back to Python
COVERAGE_PCT=""
FILE_STATS_LINES=""

lcov_cli_out="$(_parse_coverage_lcov_cli)"
if printf '%s' "$lcov_cli_out" | grep -q 'lines\.\.\.\.\.\.' 2>/dev/null; then
  # lcov --summary format: "  lines......: 72.5% (58 of 80 lines)"
  COVERAGE_PCT="$(printf '%s' "$lcov_cli_out" \
    | grep 'lines\.\.\.\.\.\.' \
    | grep -oE '[0-9]+\.[0-9]+' | head -1)"
fi

# Always also run python parse for file-level breakdown
python_out="$(_parse_coverage_python)"
if [ -z "$COVERAGE_PCT" ]; then
  COVERAGE_PCT="$(printf '%s' "$python_out" | grep '^COVERAGE:' | cut -d: -f2)"
fi
FILE_STATS_LINES="$(printf '%s' "$python_out" | grep '^FILE:')"

if [ -z "$COVERAGE_PCT" ]; then
  printf '[%s] WARNING: could not parse coverage — skipping.\n' "$MODULE_NAME"
  _audit "skip" "parse-error" "could not determine coverage pct"
  exit 0
fi

printf '[%s] Service-layer coverage: %s%%\n' "$MODULE_NAME" "$COVERAGE_PCT"

# ---------------------------------------------------------------------------
# Compare with last known coverage
# ---------------------------------------------------------------------------
LAST_COVERAGE_PCT="$(python3 -c "import sys,json; d=json.loads(sys.argv[1]); v=d.get('last_coverage_pct'); print(v if v is not None else 'null')" "$STATE_JSON")"
LAST_ALERT_PCT="$(python3 -c "import sys,json; d=json.loads(sys.argv[1]); v=d.get('last_alert_pct'); print(v if v is not None else 'null')" "$STATE_JSON")"
LAST_FIX_ATTEMPT="$(python3 -c "import sys,json; d=json.loads(sys.argv[1]); print(d.get('last_fix_attempt', 0))" "$STATE_JSON")"

SHOULD_ALERT=0
DROP_ABS=""

if [ "$LAST_COVERAGE_PCT" != "null" ]; then
  DROP_ABS="$(python3 -c "
last = float('$LAST_COVERAGE_PCT')
current = float('$COVERAGE_PCT')
drop = last - current
print(f'{drop:.2f}')
")"

  IS_DROP="$(python3 -c "
drop = float('$DROP_ABS')
threshold = float('$ALERT_THRESHOLD')
print('1' if drop >= threshold else '0')
")"

  if [ "$IS_DROP" = "1" ]; then
    # Check hysteresis: if there's a last_alert_pct, only re-alert if we had recovered first
    if [ "$LAST_ALERT_PCT" != "null" ]; then
      RECOVERED="$(python3 -c "
current = float('$COVERAGE_PCT')
last_alert = float('$LAST_ALERT_PCT')
hysteresis = float('$HYSTERESIS')
# coverage must have recovered above last_alert+hysteresis before this new drop can alert
print('1' if current < last_alert - hysteresis else '0')
")"
      # Note: if current is already low (< last_alert - hysteresis), alert is appropriate
      # If current >= last_alert - hysteresis, we haven't recovered enough, suppress
      SUPPRESS="$(python3 -c "
current = float('$COVERAGE_PCT')
last_alert = float('$LAST_ALERT_PCT')
hysteresis = float('$HYSTERESIS')
# We suppress if current coverage is NOT more than hysteresis below last_alert
# i.e., suppress if recovery never happened — meaning current is near or above last_alert
# Actually: suppress if coverage never went back up to last_alert+hysteresis
# We track this via last_coverage_pct history. Simplified: suppress if last known
# coverage (before this drop) was still below last_alert+hysteresis too.
last_cov = float('$LAST_COVERAGE_PCT')
required_recovery = last_alert + hysteresis
print('1' if last_cov < required_recovery else '0')
")"
      if [ "$SUPPRESS" = "1" ]; then
        printf '[%s] SUPPRESS: hysteresis — must recover to %.1f%% before re-alert (last_alert=%.1f%%, last=%.1f%%)\n' \
          "$MODULE_NAME" \
          "$(python3 -c "print(float('$LAST_ALERT_PCT') + float('$HYSTERESIS'))")" \
          "$LAST_ALERT_PCT" "$LAST_COVERAGE_PCT"
        SHOULD_ALERT=0
      else
        SHOULD_ALERT=1
      fi
    else
      SHOULD_ALERT=1
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Update state with new coverage value (always, even if no alert)
# ---------------------------------------------------------------------------
NEW_STATE_JSON="$(python3 - "$STATE_JSON" "$COVERAGE_PCT" "$NOW_ISO" <<'PYEOF'
import sys, json
state_json, new_pct, now_iso = sys.argv[1], float(sys.argv[2]), sys.argv[3]
d = json.loads(state_json)
d['last_run'] = now_iso
d['last_coverage_pct'] = new_pct
print(json.dumps(d, indent=2))
PYEOF
)"

if [ "$SHOULD_ALERT" -eq 0 ]; then
  if [ "$LAST_COVERAGE_PCT" = "null" ]; then
    printf '[%s] Initial coverage recorded: %s%% (no previous baseline — no item).\n' \
      "$MODULE_NAME" "$COVERAGE_PCT"
  elif [ -z "${IS_DROP:-}" ] || [ "${IS_DROP:-0}" = "0" ]; then
    printf '[%s] Coverage OK: %s%% (last: %s%%, drop: %s%%).\n' \
      "$MODULE_NAME" "$COVERAGE_PCT" "$LAST_COVERAGE_PCT" "${DROP_ABS:-0}"
  fi
  [ "$DRY_RUN" -eq 0 ] && _save_state "$NEW_STATE_JSON"
  printf '[%s] Done. Items generated: 0\n' "$MODULE_NAME"
  exit 0
fi

# ---------------------------------------------------------------------------
# Alert path: check fix-attempt counter + 7d-pause
# ---------------------------------------------------------------------------
NEW_FIX_ATTEMPT=$(( LAST_FIX_ATTEMPT + 1 ))

if [ "$NEW_FIX_ATTEMPT" -gt "$MAX_ATTEMPTS" ]; then
  NEW_PAUSE="$(_date_add_days "$NOW_EPOCH" "$PAUSE_DAYS")"
  printf '[%s] PAUSE: %d fix attempts without recovery — pausing until %s\n' \
    "$MODULE_NAME" "$LAST_FIX_ATTEMPT" "$NEW_PAUSE"
  NEW_STATE_JSON="$(python3 - "$NEW_STATE_JSON" "$NEW_PAUSE" "$NEW_FIX_ATTEMPT" <<'PYEOF'
import sys, json
state_json, pause_until, fix_attempt = sys.argv[1], sys.argv[2], int(sys.argv[3])
d = json.loads(state_json)
d['paused_until'] = pause_until
d['last_fix_attempt'] = fix_attempt
print(json.dumps(d, indent=2))
PYEOF
)"
  _audit "pause" "max-attempts" "attempts=$NEW_FIX_ATTEMPT paused_until=$NEW_PAUSE"
  _notify_info "Coverage scan paused after $MAX_ATTEMPTS failed fix attempts"
  [ "$DRY_RUN" -eq 0 ] && _save_state "$NEW_STATE_JSON"
  printf '[%s] Done. Items generated: 0 (paused)\n' "$MODULE_NAME"
  exit 0
fi

# ---------------------------------------------------------------------------
# Build item
# ---------------------------------------------------------------------------
SHA8="$(_sha8 "test-coverage-drop-${COVERAGE_PCT}-${LAST_COVERAGE_PCT}")"
GIT_SHA8="$(git -C "$REPO_ROOT" rev-parse --short=8 HEAD 2>/dev/null || printf '%s' "$SHA8")"
ITEM_SLUG="test-coverage-drop-${GIT_SHA8}"

# Build file breakdown list (worst-coverage files first, max 10)
FILE_BREAKDOWN="$(printf '%s' "$FILE_STATS_LINES" \
  | head -10 \
  | sed 's/^FILE://' \
  | awk -F'|' '{printf "- %s: %s (%s)\n", $1, $2, $3}')"

if [ "$DRY_RUN" -eq 1 ]; then
  printf '[dry-run] Would generate item: %s\n' "$ITEM_SLUG"
  printf '[dry-run] Coverage drop: %s%% → %s%% (drop=%s%%)\n' \
    "$LAST_COVERAGE_PCT" "$COVERAGE_PCT" "$DROP_ABS"
  printf '[dry-run] Fix attempt: %d\n' "$NEW_FIX_ATTEMPT"
  # Still update state in dry-run? No — don't persist
  printf '[%s] Done. Items generated: 1 (dry-run)\n' "$MODULE_NAME"
  exit 0
fi

mkdir -p "$INBOX_DIR"
ITEM_FILE="$INBOX_DIR/00-analyzer-${MODULE_NAME}-${GIT_SHA8}.md"

cat > "$ITEM_FILE" <<ITEMEOF
---
slug: ${ITEM_SLUG}
source: tier-3
priority: 0
budget_usd: 3.0
model: sonnet
touches: [lib/services/, test/]
needs_gh: false
estimated_minutes: 60
created_from: scan-test-coverage
trust_tier: 3
---

## Aufgabe

Service-Layer-Test-Coverage ist um **${DROP_ABS}%** gefallen:
- Vorherige Coverage: **${LAST_COVERAGE_PCT}%**
- Aktuelle Coverage: **${COVERAGE_PCT}%**
- Threshold: ${ALERT_THRESHOLD}%

## Files mit niedrigster Coverage (service-layer)

${FILE_BREAKDOWN:-Keine File-Details verfügbar.}

## Acceptance

- Service-Layer-Coverage steigt wieder auf mindestens **${LAST_COVERAGE_PCT}%**.
- \`flutter test\` ist grün.
- Neue Tests in \`test/\` für die unterdeckten Services.
ITEMEOF

printf '[%s] Item written: %s\n' "$MODULE_NAME" "$ITEM_FILE"
_audit "item-created" "coverage-drop" \
  "from=${LAST_COVERAGE_PCT}% to=${COVERAGE_PCT}% drop=${DROP_ABS}% item=$ITEM_FILE"
_notify_info "Coverage drop detected: ${LAST_COVERAGE_PCT}% → ${COVERAGE_PCT}% (drop=${DROP_ABS}%)"

# Update state: record alert_pct + fix_attempt
NEW_STATE_JSON="$(python3 - "$NEW_STATE_JSON" "$COVERAGE_PCT" "$NEW_FIX_ATTEMPT" <<'PYEOF'
import sys, json
state_json, alert_pct, fix_attempt = sys.argv[1], float(sys.argv[2]), int(sys.argv[3])
d = json.loads(state_json)
d['last_alert_pct'] = alert_pct
d['last_fix_attempt'] = fix_attempt
print(json.dumps(d, indent=2))
PYEOF
)"

[ "$DRY_RUN" -eq 0 ] && _save_state "$NEW_STATE_JSON"

printf '[%s] Done. Items generated: 1\n' "$MODULE_NAME"
