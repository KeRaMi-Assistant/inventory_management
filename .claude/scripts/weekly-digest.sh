#!/usr/bin/env bash
# weekly-digest.sh — P3-9.5 Wochen-Digest (Sonntag 09:00)
#
# Usage:
#   weekly-digest.sh [--once]     — Generate one digest and exit (default for LaunchAgent)
#   weekly-digest.sh --dry-run    — Print digest to stdout, do NOT write file or notify
#
# Output: .claude/stakeholder/digest/<YYYY-Wxx>.md
# Sends push notification via notify.sh with week summary.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

# Bibliotheken laden
# shellcheck source=lib/cost-cap.sh
source "$SCRIPT_DIR/lib/cost-cap.sh"

NOTIFY_SH="$SCRIPT_DIR/notify.sh"

# ---------------------------------------------------------------------------
# Pfade (überschreibbar für Tests)
# ---------------------------------------------------------------------------
DIGEST_DIR="${DIGEST_DIR:-$REPO_ROOT/.claude/stakeholder/digest}"
AUDIT_DIR="${AUDIT_DIR:-$REPO_ROOT/.claude/audit}"
DISPUTES_DIR="${DISPUTES_DIR:-$REPO_ROOT/.claude/disputes}"
STAKEHOLDER_INBOX_DIR="${STAKEHOLDER_INBOX_DIR:-$REPO_ROOT/.claude/stakeholder/inbox}"
OVERSEER_DIR="${OVERSEER_DIR:-$REPO_ROOT/.claude/overseer}"

# ---------------------------------------------------------------------------
# Hilfsfunktionen
# ---------------------------------------------------------------------------
log()  { printf '[weekly-digest] %s\n' "$*" >&2; }
die()  { printf '[weekly-digest] ERROR: %s\n' "$*" >&2; exit 1; }

_truncate() {
  local s="$1" max="$2"
  if [ "${#s}" -gt "$max" ]; then printf '%s...' "${s:0:$((max-3))}"
  else printf '%s' "$s"; fi
}

# ---------------------------------------------------------------------------
# Week designation helpers
# ---------------------------------------------------------------------------
_iso_week() {
  # Returns YYYY-Wxx for a given date string YYYY-MM-DD (or today if empty)
  local d="${1:-}"
  if [ -n "${DIGEST_MOCK_DATE:-}" ] && [ -z "$d" ]; then
    d="$DIGEST_MOCK_DATE"
  fi
  if [ -z "$d" ]; then
    d="$(date -u +%Y-%m-%d)"
  fi
  python3 -c "
import sys
from datetime import datetime
d = datetime.strptime('$d', '%Y-%m-%d')
iso = d.isocalendar()
print(f'{iso[0]}-W{iso[1]:02d}')
"
}

_week_start() {
  # Returns ISO Monday of the current week (YYYY-MM-DD)
  local ref="${DIGEST_MOCK_DATE:-$(date -u +%Y-%m-%d)}"
  python3 -c "
from datetime import datetime, timedelta
d = datetime.strptime('$ref', '%Y-%m-%d')
monday = d - timedelta(days=d.weekday())
print(monday.strftime('%Y-%m-%d'))
"
}

_week_end() {
  # Returns ISO Sunday of the current week (YYYY-MM-DD)
  local ref="${DIGEST_MOCK_DATE:-$(date -u +%Y-%m-%d)}"
  python3 -c "
from datetime import datetime, timedelta
d = datetime.strptime('$ref', '%Y-%m-%d')
sunday = d - timedelta(days=d.weekday()) + timedelta(days=6)
print(sunday.strftime('%Y-%m-%d'))
"
}

_7days_ago() {
  local ref="${DIGEST_MOCK_DATE:-$(date -u +%Y-%m-%d)}"
  python3 -c "
from datetime import datetime, timedelta
d = datetime.strptime('$ref', '%Y-%m-%d')
print((d - timedelta(days=7)).strftime('%Y-%m-%d'))
"
}

_epoch_7days_ago() {
  python3 -c "
import time
from datetime import datetime, timedelta, timezone
import os
ref = os.environ.get('DIGEST_MOCK_DATE', '')
if ref:
    d = datetime.strptime(ref, '%Y-%m-%d').replace(tzinfo=timezone.utc)
else:
    d = datetime.now(timezone.utc)
cutoff = d - timedelta(days=7)
print(int(cutoff.timestamp()))
" 2>/dev/null || echo "0"
}

# ---------------------------------------------------------------------------
# Section 1+5: Cost Summary (7 days)
# ---------------------------------------------------------------------------
_cost_summary_7d() {
  # Returns key=value pairs: total=X top3=agent1:cost,agent2:cost,agent3:cost cap_events=N
  python3 - "$(_cost_cap_ledger_dir)/cost-ledger.jsonl" "${DIGEST_MOCK_DATE:-}" <<'PYEOF'
import sys, json, os
from datetime import datetime, timezone, timedelta
from collections import defaultdict

ledger_file = sys.argv[1]
mock_date   = sys.argv[2] if len(sys.argv) > 2 else ''

if mock_date:
    now = datetime.strptime(mock_date, '%Y-%m-%d').replace(tzinfo=timezone.utc)
else:
    now = datetime.now(timezone.utc)

cutoff = now - timedelta(days=7)
cutoff_str = cutoff.strftime('%Y-%m-%d')

total = 0.0
agent_cost = defaultdict(float)

if os.path.exists(ledger_file):
    try:
        with open(ledger_file, 'r') as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                    ts = entry.get('ts', '')
                    date_str = ts[:10]
                    usd = float(entry.get('usd', 0))
                    agent = entry.get('agent', 'unknown')
                    if date_str >= cutoff_str:
                        total += usd
                        agent_cost[agent] += usd
                except (json.JSONDecodeError, ValueError):
                    continue
    except FileNotFoundError:
        pass

top3 = sorted(agent_cost.items(), key=lambda x: x[1], reverse=True)[:3]
top3_str = ','.join(f'{a}:{c:.2f}' for a, c in top3)

print(f'total={total:.2f} top3={top3_str}')
PYEOF
}

_cap_events_7d() {
  # Count COST_CAP_REACHED events in audit files for last 7 days
  local cutoff_date
  cutoff_date="$(_7days_ago)"
  local count=0

  if [ -d "$AUDIT_DIR" ]; then
    while IFS= read -r audit_file; do
      local fname
      fname="$(basename "$audit_file" .md)"
      # Only files within last 7 days
      if [[ "$fname" > "$cutoff_date" ]] || [[ "$fname" == "$cutoff_date" ]]; then
        local n
        n="$(grep -c 'COST_CAP_REACHED' "$audit_file" 2>/dev/null || echo 0)"
        count=$((count + n))
      fi
    done < <(find "$AUDIT_DIR" -maxdepth 1 -name '*.md' 2>/dev/null)
  fi
  printf '%d' "$count"
}

# ---------------------------------------------------------------------------
# Section 2: Merged PRs (7 days)
# ---------------------------------------------------------------------------
_merged_prs_section() {
  local start_date
  start_date="$(_7days_ago)"

  printf '## Gemerged-PRs (letzte 7 Tage)\n\n'

  # Try gh pr list first, fall back to git log
  local prs_output=""
  if command -v gh >/dev/null 2>&1; then
    prs_output="$(gh pr list --state merged \
      --search "merged:>=${start_date}" \
      --limit 100 \
      --json number,title,mergedAt \
      2>/dev/null || true)"
  fi

  if [ -n "$prs_output" ] && python3 -c "import json,sys; d=json.loads(sys.stdin.read()); sys.exit(0 if isinstance(d,list) else 1)" <<< "$prs_output" 2>/dev/null; then
    local count
    count="$(python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(len(d))" <<< "$prs_output" 2>/dev/null || echo 0)"

    if [ "$count" -eq 0 ]; then
      printf '_Keine PRs in den letzten 7 Tagen gemerged._\n\n'
      return
    fi

    python3 - <<PYEOF
import json, sys

prs = json.loads("""$prs_output""")
for pr in prs:
    num = pr.get('number', '?')
    title = pr.get('title', '(no title)')
    merged_at = pr.get('mergedAt', '')[:10]

    # Classify by conventional commit prefix
    prefix = title.split(':')[0].lower() if ':' in title else ''
    tag = 'chore'
    if prefix.startswith('feat'):
        tag = 'feat'
    elif prefix.startswith('fix'):
        tag = 'fix'
    elif prefix.startswith('refactor'):
        tag = 'refactor'
    elif prefix.startswith('docs'):
        tag = 'docs'
    elif prefix.startswith('test'):
        tag = 'test'

    print(f'- **#{num}** [{tag}] {title} _(merged {merged_at})_')

PYEOF
  else
    # Fallback: git log
    local git_prs
    git_prs="$(git -C "$REPO_ROOT" log --since="${start_date}" --merges \
      --first-parent main \
      --pretty=format:"%s" 2>/dev/null | head -50 || true)"

    if [ -z "$git_prs" ]; then
      printf '_Keine PRs in den letzten 7 Tagen gemerged._\n\n'
      return
    fi

    printf '%s\n' "$git_prs" | while IFS= read -r line; do
      [ -z "$line" ] && continue
      local tag="chore"
      case "$line" in
        feat:*|feat\(*) tag="feat" ;;
        fix:*|fix\(*)   tag="fix" ;;
        refactor:*)     tag="refactor" ;;
        docs:*)         tag="docs" ;;
        test:*)         tag="test" ;;
      esac
      printf '- [%s] %s\n' "$tag" "$(_truncate "$line" 100)"
    done
  fi

  printf '\n'
}

# ---------------------------------------------------------------------------
# Section 3: Abgelehnte Disputs (7 days)
# ---------------------------------------------------------------------------
_disputes_section() {
  local cutoff_epoch
  cutoff_epoch="$(_epoch_7days_ago)"

  printf '## Abgelehnte Disputs (letzte 7 Tage)\n\n'

  local rejected_count=0
  local unresolved_count=0
  local high_severity_count=0

  if [ -d "$DISPUTES_DIR" ]; then
    # Scan verdict files
    while IFS= read -r verdict_file; do
      local mtime
      mtime="$(stat -f %m "$verdict_file" 2>/dev/null || stat -c %Y "$verdict_file" 2>/dev/null || echo 0)"
      if [ "$mtime" -ge "$cutoff_epoch" ] 2>/dev/null; then
        local status
        status="$(grep -m1 '^status:' "$verdict_file" 2>/dev/null | awk '{print $2}' || true)"
        if [ "$status" = "reject" ]; then
          rejected_count=$((rejected_count + 1))
          local reason
          reason="$(grep -A2 '## Verdict' "$verdict_file" 2>/dev/null | tail -1 | head -c 120 || true)"
          local disp_id
          disp_id="$(basename "$(dirname "$verdict_file")")"
          local severity
          severity="$(grep -m1 '^severity:' "$verdict_file" 2>/dev/null | awk '{print $2}' || true)"
          if [ "$severity" = "high" ]; then
            high_severity_count=$((high_severity_count + 1))
          fi
          local sev="${severity:-normal}"
          local rsn="$(_truncate "${reason:-(no reason)}" 100)"
          printf '%s\n' "- **$disp_id** [$sev]: $rsn"
        fi
      fi
    done < <(find "$DISPUTES_DIR" -name "verdict.md" 2>/dev/null)

    # Unresolved in last 7d
    local unresolved_dir="$DISPUTES_DIR/unresolved"
    if [ -d "$unresolved_dir" ]; then
      while IFS= read -r f; do
        local mtime
        mtime="$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)"
        if [ "$mtime" -ge "$cutoff_epoch" ] 2>/dev/null; then
          unresolved_count=$((unresolved_count + 1))
        fi
      done < <(find "$unresolved_dir" -maxdepth 1 \( -type f -o -type d \) ! -path "$unresolved_dir" 2>/dev/null)
    fi
  fi

  if [ "$rejected_count" -eq 0 ]; then
    printf '_Keine abgelehnten Disputs in den letzten 7 Tagen._\n'
  fi
  printf '\n- Abgelehnt gesamt: **%d**\n' "$rejected_count"
  printf '- Ungelöst (letzte 7d): **%d**\n' "$unresolved_count"
  printf '\n'

  # Export for action items
  printf '%d' "$high_severity_count" > "/tmp/weekly_digest_hs_$$"
}

# ---------------------------------------------------------------------------
# Section 4: Offene Stakeholder-Items
# ---------------------------------------------------------------------------
_stakeholder_section() {
  local cutoff_epoch
  cutoff_epoch="$(_epoch_7days_ago)"
  local now_epoch
  now_epoch="$(date -u +%s 2>/dev/null || python3 -c 'import time; print(int(time.time()))')"
  local stale_threshold=86400  # 24h

  printf '## Offene Stakeholder-Items\n\n'

  local items_found=0
  local stale_count=0

  # Check .claude/stakeholder/inbox/
  if [ -d "$STAKEHOLDER_INBOX_DIR" ]; then
    while IFS= read -r f; do
      [ -f "$f" ] || continue
      local fname mtime age slug
      fname="$(basename "$f")"
      mtime="$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)"
      age=$(( now_epoch - mtime ))
      slug="${fname%.md}"
      local age_h=$(( age / 3600 ))
      local stale_marker=""
      if [ "$age" -gt "$stale_threshold" ]; then
        stale_count=$((stale_count + 1))
        stale_marker=" ⚠ (${age_h}h alt)"
      fi
      printf '- `%s` [stakeholder/inbox]%s\n' "$slug" "$stale_marker"
      items_found=$((items_found + 1))
    done < <(find "$STAKEHOLDER_INBOX_DIR" -maxdepth 1 -type f -name "*.md" 2>/dev/null | sort)
  fi

  # Check .claude/overseer/inbox/ for 01-stakeholder-* items
  local overseer_inbox="$OVERSEER_DIR/inbox"
  if [ -d "$overseer_inbox" ]; then
    while IFS= read -r f; do
      [ -f "$f" ] || continue
      local fname mtime age slug
      fname="$(basename "$f")"
      mtime="$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)"
      age=$(( now_epoch - mtime ))
      slug="${fname%.md}"
      local age_h=$(( age / 3600 ))
      local stale_marker=""
      if [ "$age" -gt "$stale_threshold" ]; then
        stale_count=$((stale_count + 1))
        stale_marker=" ⚠ (${age_h}h alt)"
      fi
      printf '- `%s` [overseer/inbox]%s\n' "$slug" "$stale_marker"
      items_found=$((items_found + 1))
    done < <(find "$overseer_inbox" -maxdepth 1 -type f -name "01-stakeholder-*" 2>/dev/null | sort)
  fi

  if [ "$items_found" -eq 0 ]; then
    printf '_Keine offenen Stakeholder-Items._\n'
  fi

  printf '\n- Gesamt: **%d** | Stale (>24h): **%d**\n\n' "$items_found" "$stale_count"

  # Export stale count for action items
  printf '%d' "$stale_count" > "/tmp/weekly_digest_stale_$$"
}

# ---------------------------------------------------------------------------
# Section 5: Cost-Summary (full)
# ---------------------------------------------------------------------------
_cost_full_section() {
  local cost_line
  cost_line="$(_cost_summary_7d)"
  local total top3
  total="$(printf '%s' "$cost_line" | grep -oE 'total=[0-9.]+' | cut -d= -f2)"
  top3="$(printf '%s' "$cost_line" | grep -oE 'top3=[^ ]*' | cut -d= -f2)"
  total="${total:-0.00}"

  local cap_events
  cap_events="$(_cap_events_7d)"

  printf '## Cost-Summary (letzte 7 Tage)\n\n'
  printf '| Metrik | Wert |\n'
  printf '|--------|------|\n'
  printf '| Gesamtkosten | $%s |\n' "$total"
  printf '| Cost-Cap-Events | %d |\n' "$cap_events"
  printf '\n'

  if [ -n "$top3" ] && [ "$top3" != "=" ]; then
    printf '**Top-3 Agents (nach Kosten):**\n\n'
    printf '%s\n' "$top3" | tr ',' '\n' | while IFS=: read -r agent cost; do
      [ -z "$agent" ] && continue
      printf '%s\n' "- \`$agent\`: \$${cost:-0.00}"
    done
    printf '\n'
  fi

  # Export total and cap_events for notification
  printf '%s' "$total" > "/tmp/weekly_digest_cost_$$"
  printf '%d' "$cap_events" > "/tmp/weekly_digest_cap_$$"
}

# ---------------------------------------------------------------------------
# Section 6: Action-Items
# ---------------------------------------------------------------------------
_action_items_section() {
  printf '## Action-Items für Wochenend-Rückkehr\n\n'
  printf '> Was du dringend reviewen solltest:\n\n'

  local has_items=0

  # 1. High-severity rejected disputes
  local hs_count=0
  if [ -f "/tmp/weekly_digest_hs_$$" ]; then
    hs_count="$(cat "/tmp/weekly_digest_hs_$$")"
  fi
  if [ "$hs_count" -gt 0 ]; then
    printf '%s\n' "- **Abgelehnte Disputs (severity: high):** $hs_count — Zweiten Blick werfen!"
    has_items=1
  fi

  # 2. Pending stakeholder items > 24h
  local stale_count=0
  if [ -f "/tmp/weekly_digest_stale_$$" ]; then
    stale_count="$(cat "/tmp/weekly_digest_stale_$$")"
  fi
  if [ "$stale_count" -gt 0 ]; then
    printf '%s\n' "- **Stale Stakeholder-Items (>24h):** $stale_count — Manuelles Review empfohlen."
    has_items=1
  fi

  # 3. PANIC marker
  local panic_file="$OVERSEER_DIR/PANIC"
  if [ -f "$panic_file" ] || [ -d "$panic_file" ]; then
    printf '%s\n' "- **PANIC-Marker aktiv!** — Sofort prüfen: \`$panic_file\`"
    has_items=1
  fi
  # Also check audit for recent PANIC events
  local panic_in_audit=0
  local cutoff_date
  cutoff_date="$(_7days_ago)"
  if [ -d "$AUDIT_DIR" ]; then
    while IFS= read -r af; do
      local fname
      fname="$(basename "$af" .md)"
      if [[ "$fname" > "$cutoff_date" ]] || [[ "$fname" == "$cutoff_date" ]]; then
        if grep -q 'PANIC' "$af" 2>/dev/null; then
          panic_in_audit=$((panic_in_audit + 1))
        fi
      fi
    done < <(find "$AUDIT_DIR" -maxdepth 1 -name '*.md' 2>/dev/null)
  fi
  if [ "$panic_in_audit" -gt 0 ]; then
    printf '%s\n' "- **PANIC-Events im Audit (letzte 7d):** $panic_in_audit Einträge."
    has_items=1
  fi

  # 4. Failed items > 5 in 7d
  local failed_dir="$OVERSEER_DIR/failed"
  local failed_7d=0
  if [ -d "$failed_dir" ]; then
    local cutoff_epoch
    cutoff_epoch="$(_epoch_7days_ago)"
    while IFS= read -r f; do
      local mtime
      mtime="$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)"
      if [ "$mtime" -ge "$cutoff_epoch" ] 2>/dev/null; then
        failed_7d=$((failed_7d + 1))
      fi
    done < <(find "$failed_dir" -maxdepth 1 -type f 2>/dev/null)
  fi
  if [ "$failed_7d" -gt 5 ]; then
    printf '%s\n' "- **Fehlgeschlagene Items (letzte 7d):** $failed_7d > 5 — Pattern-Review."
    has_items=1
  fi

  if [ "$has_items" -eq 0 ]; then
    printf '_Keine dringenden Action-Items. Alles grün._\n'
  fi

  printf '\n'
}

# ---------------------------------------------------------------------------
# Generate Digest
# ---------------------------------------------------------------------------
generate_digest() {
  local week_id start_date end_date
  week_id="$(_iso_week)"
  start_date="$(_week_start)"
  end_date="$(_week_end)"

  log "Generating weekly digest for $week_id ($start_date – $end_date) ..."

  local content=""

  # Header
  content+="# Wochen-Digest — Woche ${week_id} (${start_date} bis ${end_date})"$'\n\n'

  # Merged PRs
  local prs_section
  prs_section="$(_merged_prs_section)"
  content+="$prs_section"$'\n'

  # Disputes
  local disputes_section
  disputes_section="$(_disputes_section)"
  content+="$disputes_section"$'\n'

  # Stakeholder items
  local stakeholder_section
  stakeholder_section="$(_stakeholder_section)"
  content+="$stakeholder_section"$'\n'

  # Cost summary (full)
  local cost_section
  cost_section="$(_cost_full_section)"
  content+="$cost_section"$'\n'

  # Action items
  local action_section
  action_section="$(_action_items_section)"
  content+="$action_section"$'\n'

  # Footer: audit-grep hint
  content+="---"$'\n\n'
  content+="> **Audit-Suche:** \`bash .claude/scripts/audit-grep.sh \"<keyword>\"\`"$'\n'

  printf '%s' "$content"
}

# ---------------------------------------------------------------------------
# Run (once)
# ---------------------------------------------------------------------------
run_once() {
  local dry_run="${1:-0}"

  local week_id
  week_id="$(_iso_week)"

  local digest_content
  digest_content="$(generate_digest)"

  if [ "$dry_run" = "1" ]; then
    printf '%s\n' "$digest_content"
    log "dry-run: no file written, no notification sent"
    # Cleanup temp files
    rm -f "/tmp/weekly_digest_hs_$$" "/tmp/weekly_digest_stale_$$" \
      "/tmp/weekly_digest_cost_$$" "/tmp/weekly_digest_cap_$$"
    return 0
  fi

  # Write file
  mkdir -p "$DIGEST_DIR"
  local digest_file="$DIGEST_DIR/${week_id}.md"
  printf '%s\n' "$digest_content" > "$digest_file"
  log "Digest written → $digest_file"

  # Build notification summary
  local total_cost="0.00"
  local cap_events=0
  if [ -f "/tmp/weekly_digest_cost_$$" ]; then
    total_cost="$(cat "/tmp/weekly_digest_cost_$$")"
  fi
  if [ -f "/tmp/weekly_digest_cap_$$" ]; then
    cap_events="$(cat "/tmp/weekly_digest_cap_$$")"
  fi

  # Count decisions and open items
  local decisions_count stale_count
  decisions_count="$(grep -c '^- \*\*#' "$digest_file" 2>/dev/null || echo 0)"
  stale_count=0
  if [ -f "/tmp/weekly_digest_stale_$$" ]; then
    stale_count="$(cat "/tmp/weekly_digest_stale_$$")"
  fi

  local summary_title
  summary_title="Week summary ready: ${week_id}"
  local summary_body
  summary_body="$decisions_count decisions, $stale_count open | \$${total_cost} total | ${cap_events} cap events"
  summary_body="$(_truncate "$summary_body" 200)"

  # Top-3 agents line
  local cost_line top3_body
  cost_line="$(_cost_summary_7d)"
  top3_body="$(printf '%s' "$cost_line" | grep -oE 'top3=[^ ]*' | cut -d= -f2 | tr ',' ' | ')"
  [ -z "$top3_body" ] && top3_body="No agent data"

  # Send notification
  if [ -x "$NOTIFY_SH" ]; then
    local action_json
    action_json="$(python3 -c "
import json
print(json.dumps([{\"action\": \"http\", \"label\": \"Open digest\", \"url\": \"file://$digest_file\"}]))
" 2>/dev/null || echo '[]')"

    REPO_ROOT="$REPO_ROOT" "$NOTIFY_SH" info weekly-digest \
      "$summary_title" \
      "$summary_body" \
      "$action_json" 2>/dev/null || true
    log "Notification sent"
  fi

  # Audit record
  local audit_lib="$SCRIPT_DIR/lib/audit.sh"
  if [ -r "$audit_lib" ]; then
    # shellcheck disable=SC1090
    source "$audit_lib" 2>/dev/null || true
    if command -v audit_record >/dev/null 2>&1; then
      audit_record "weekly-digest" "info" "DIGEST_GENERATED" \
        "week=$week_id file=$digest_file cost=$total_cost" 2>/dev/null || true
    fi
  fi

  # Cleanup temp files
  rm -f "/tmp/weekly_digest_hs_$$" "/tmp/weekly_digest_stale_$$" \
    "/tmp/weekly_digest_cost_$$" "/tmp/weekly_digest_cap_$$"
}

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
MODE="once"
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --once)    MODE="once" ;;
    --dry-run) DRY_RUN=1 ;;
    *)
      printf 'Usage: %s [--once|--dry-run]\n' "$(basename "$0")" >&2
      exit 1
      ;;
  esac
done

run_once "$DRY_RUN"
