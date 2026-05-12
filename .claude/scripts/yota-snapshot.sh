#!/usr/bin/env bash
# yota-snapshot.sh — Read-only Snapshot des Autonomous Council Swarm State.
#
# Aggregiert in <2s aus:
#   .claude/overseer/health.json
#   .claude/overseer/state/workers/*.pid
#   .claude/overseer/state/failure-counter.json
#   .claude/overseer/oauth-status.json
#   .claude/overseer/cost-ledger.jsonl
#   .claude/overseer/{PANIC,STOP,AUTH_EXPIRED,COST_CAP_REACHED,ANALYZER_PAUSE}
#   .claude/overseer/inbox/, done/, failed/
#   .claude/stakeholder/inbox/
#   .claude/backlog/inbox/, in-progress/
#   .claude/disputes/<id>/verdict.md
#   .claude/audit/<today>.md
#   .claude/audit/briefings/*.md
#   gh pr list --state merged
#
# Usage:
#   yota-snapshot.sh           — JSON auf stdout (default).
#   yota-snapshot.sh --human   — Markdown-formatierte Übersicht.
#
# Exit: 0 immer (auch wenn Files fehlen — leerer State ist gültig).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

# Override-bare Pfade (für Verify-Sandbox)
OVERSEER_DIR="${OVERSEER_DIR:-$REPO_ROOT/.claude/overseer}"
STAKEHOLDER_DIR="${STAKEHOLDER_DIR:-$REPO_ROOT/.claude/stakeholder}"
BACKLOG_DIR="${BACKLOG_DIR:-$REPO_ROOT/.claude/backlog}"
DISPUTES_DIR="${DISPUTES_DIR:-$REPO_ROOT/.claude/disputes}"
AUDIT_DIR="${AUDIT_DIR:-$REPO_ROOT/.claude/audit}"
BRIEFING_DIR="${BRIEFING_DIR:-$AUDIT_DIR/briefings}"

COST_CAP_TODAY="${COST_CAP_TODAY:-20}"
COST_CAP_WEEK="${COST_CAP_WEEK:-100}"

MODE="json"
for arg in "$@"; do
  case "$arg" in
    --human) MODE="human" ;;
    --json)  MODE="json" ;;
    -h|--help)
      printf 'Usage: %s [--human|--json]\n' "$(basename "$0")" >&2
      exit 0
      ;;
    *)
      printf 'Unknown arg: %s\n' "$arg" >&2
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Aggregator (Python für Klarheit + jq-freie Umgebung)
# ---------------------------------------------------------------------------
SNAPSHOT_JSON="$(
  OVERSEER_DIR="$OVERSEER_DIR" \
  STAKEHOLDER_DIR="$STAKEHOLDER_DIR" \
  BACKLOG_DIR="$BACKLOG_DIR" \
  DISPUTES_DIR="$DISPUTES_DIR" \
  AUDIT_DIR="$AUDIT_DIR" \
  BRIEFING_DIR="$BRIEFING_DIR" \
  COST_CAP_TODAY="$COST_CAP_TODAY" \
  COST_CAP_WEEK="$COST_CAP_WEEK" \
  python3 <<'PYEOF'
import json, os, sys
from datetime import datetime, timezone, timedelta
from pathlib import Path

OVS  = Path(os.environ['OVERSEER_DIR'])
STK  = Path(os.environ['STAKEHOLDER_DIR'])
BKL  = Path(os.environ['BACKLOG_DIR'])
DSP  = Path(os.environ['DISPUTES_DIR'])
AUD  = Path(os.environ['AUDIT_DIR'])
BRF  = Path(os.environ['BRIEFING_DIR'])
CAP_T = float(os.environ.get('COST_CAP_TODAY', '20'))
CAP_W = float(os.environ.get('COST_CAP_WEEK', '100'))

now = datetime.now(timezone.utc)
today_str = now.strftime('%Y-%m-%d')
yesterday_str = (now - timedelta(days=1)).strftime('%Y-%m-%d')
cutoff_week_str = (now - timedelta(days=6)).strftime('%Y-%m-%d')
cutoff_24h = (now - timedelta(hours=24)).timestamp()

def safe_json(p):
    try:
        return json.loads(p.read_text())
    except Exception:
        return None

def count_files(d, pattern='*'):
    if not d.exists() or not d.is_dir():
        return 0
    try:
        return sum(1 for x in d.glob(pattern) if x.is_file())
    except Exception:
        return 0

def count_mtime_24h(d, pattern='*'):
    if not d.exists() or not d.is_dir():
        return 0
    n = 0
    try:
        for x in d.glob(pattern):
            if x.is_file() and x.stat().st_mtime >= cutoff_24h:
                n += 1
    except Exception:
        pass
    return n

# ---- Status / Markers ----
panic_marker = OVS / 'PANIC'
stop_marker  = OVS / 'STOP'
auth_marker  = OVS / 'AUTH_EXPIRED'
cost_marker  = OVS / 'COST_CAP_REACHED'
analyzer_pause = OVS / 'ANALYZER_PAUSE'

panic_reason = None
if panic_marker.exists():
    try:
        panic_reason = panic_marker.read_text().strip().splitlines()[0][:200]
    except Exception:
        panic_reason = 'panic marker present'

# ---- Workers ----
workers_dir = OVS / 'state' / 'workers'
worker_details = []
if workers_dir.exists():
    for pid_file in sorted(workers_dir.glob('*.pid')):
        info = safe_json(pid_file) or {}
        pid = info.get('pid') or pid_file.stem
        started = info.get('started') or info.get('start_ts') or ''
        slug = info.get('slug') or info.get('item') or pid_file.stem
        item_path = info.get('item_path') or info.get('item') or ''
        age_min = None
        if started:
            try:
                t0 = datetime.fromisoformat(started.replace('Z', '+00:00'))
                age_min = int((now - t0).total_seconds() // 60)
            except Exception:
                age_min = None
        # Process alive?
        alive = True
        try:
            pid_int = int(pid)
            os.kill(pid_int, 0)
        except (ValueError, ProcessLookupError, PermissionError):
            alive = False
        except Exception:
            alive = True
        if alive:
            worker_details.append({
                'slug': slug,
                'pid': pid,
                'started': started,
                'age_min': age_min,
                'item_path': item_path,
            })

# Worker max (env override OVERSEER_MAX_WORKERS, default 2, hard-cap 3)
try:
    max_workers = int(os.environ.get('OVERSEER_MAX_WORKERS', '2'))
except ValueError:
    max_workers = 2
max_workers = min(max(max_workers, 1), 3)

# ---- Inbox counts ----
inbox = {
    'stakeholder': count_files(STK / 'inbox'),
    'backlog':     count_files(OVS / 'inbox') + count_files(BKL / 'inbox'),
    'in_progress': count_files(OVS / 'in_progress') + count_files(BKL / 'in-progress'),
    'done_today':  count_mtime_24h(OVS / 'done') + count_mtime_24h(BKL / 'done'),
    'failed_today': count_mtime_24h(OVS / 'failed') + count_mtime_24h(BKL / 'failed'),
    'blocked_pre_ship': count_files(OVS / 'inbox', '00-followup-*') + count_files(BKL / 'inbox', '00-followup-*'),
}

# ---- Cost ----
ledger = OVS / 'cost-ledger.jsonl'
cost_today = cost_yesterday = cost_week = 0.0
if ledger.exists():
    try:
        with ledger.open() as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    e = json.loads(line)
                except Exception:
                    continue
                ts = e.get('ts', '')
                d = ts[:10]
                try:
                    usd = float(e.get('usd', 0))
                except Exception:
                    usd = 0.0
                if d == today_str:    cost_today    += usd
                if d == yesterday_str: cost_yesterday += usd
                if d >= cutoff_week_str: cost_week += usd
    except Exception:
        pass

# ---- Disputes ----
disp_in_progress = 0
disp_decided_today = 0
disp_unresolved = 0
if DSP.exists():
    # in_progress: dirs with status.md or open marker, no verdict.md
    for d in DSP.iterdir():
        if not d.is_dir():
            continue
        name = d.name
        if name == 'unresolved':
            try:
                disp_unresolved = sum(1 for _ in d.iterdir())
            except Exception:
                disp_unresolved = 0
            continue
        verdict = d / 'verdict.md'
        if verdict.exists():
            try:
                if verdict.stat().st_mtime >= cutoff_24h:
                    disp_decided_today += 1
            except Exception:
                pass
        else:
            disp_in_progress += 1

# ---- Auth ----
oauth_status_file = OVS / 'oauth-status.json'
auth = {'gh': 'unknown', 'anthropic': 'unknown', 'supabase': 'unknown'}
oauth = safe_json(oauth_status_file) or {}
if isinstance(oauth, dict):
    auth['gh']        = oauth.get('gh', auth['gh'])
    auth['anthropic'] = oauth.get('anthropic', oauth.get('claude', auth['anthropic']))
    auth['supabase']  = oauth.get('supabase', auth['supabase'])
if auth_marker.exists():
    auth['anthropic'] = 'expired'

# ---- Alerts (today + yesterday audit) ----
alerts = []
for d in (today_str, yesterday_str):
    f = AUD / f'{d}.md'
    if not f.exists():
        continue
    try:
        for line in f.read_text(errors='ignore').splitlines():
            for kw in ('SELF_MOD', 'COST_CAP', 'PANIC', 'AUTH_EXPIRED', 'HARD-STOP'):
                if kw in line:
                    snippet = line.strip()
                    if len(snippet) > 160:
                        snippet = snippet[:157] + '...'
                    alerts.append(snippet)
                    break
            if len(alerts) >= 10:
                break
    except Exception:
        pass
    if len(alerts) >= 10:
        break

if stop_marker.exists():    alerts.append('STOP marker present')
if cost_marker.exists():    alerts.append('COST_CAP_REACHED marker present')
if analyzer_pause.exists(): alerts.append('ANALYZER_PAUSE marker present')

# ---- Status string ----
if panic_marker.exists():
    status = 'panic'
elif stop_marker.exists() or auth_marker.exists() or cost_marker.exists():
    status = 'paused'
elif worker_details:
    status = 'active'
else:
    status = 'idle'

# ---- Last briefing ----
last_briefing = None
if BRF.exists():
    try:
        files = sorted([f for f in BRF.glob('*.md') if f.is_file()],
                       key=lambda p: p.stat().st_mtime, reverse=True)
        if files:
            f = files[0]
            last_briefing = f'{f.stem} ({f})'
    except Exception:
        pass

# ---- Merged PRs (gh) ----
merged_prs = []
import subprocess
try:
    r = subprocess.run(
        ['gh', 'pr', 'list', '--state', 'merged', '--limit', '10',
         '--json', 'number,title,mergedAt'],
        capture_output=True, text=True, timeout=4,
    )
    if r.returncode == 0 and r.stdout.strip():
        data = json.loads(r.stdout)
        for pr in data:
            ma = pr.get('mergedAt', '')
            try:
                t = datetime.fromisoformat(ma.replace('Z', '+00:00'))
                if (now - t).total_seconds() <= 86400:
                    merged_prs.append({
                        'num': pr.get('number'),
                        'title': pr.get('title', ''),
                        'merged_at': ma,
                    })
            except Exception:
                pass
except Exception:
    pass

snapshot = {
    'ts': now.strftime('%Y-%m-%dT%H:%M:%SZ'),
    'status': status,
    'panic_reason': panic_reason,
    'workers': {
        'active': len(worker_details),
        'max': max_workers,
        'details': worker_details,
    },
    'inbox': inbox,
    'cost': {
        'today_usd':     round(cost_today, 2),
        'yesterday_usd': round(cost_yesterday, 2),
        'week_usd':      round(cost_week, 2),
        'cap_today':     CAP_T,
        'cap_week':      CAP_W,
    },
    'disputes': {
        'in_progress':   disp_in_progress,
        'decided_today': disp_decided_today,
        'unresolved_open': disp_unresolved,
    },
    'auth': auth,
    'alerts': alerts,
    'last_briefing': last_briefing,
    'last_merged_prs_24h': merged_prs,
}

print(json.dumps(snapshot, indent=2))
PYEOF
)"

if [ "$MODE" = "json" ]; then
  printf '%s\n' "$SNAPSHOT_JSON"
  exit 0
fi

# ---------------------------------------------------------------------------
# Human / Markdown render
# ---------------------------------------------------------------------------
SNAPSHOT_TMP="$(mktemp)"
trap 'rm -f "$SNAPSHOT_TMP"' EXIT
printf '%s' "$SNAPSHOT_JSON" > "$SNAPSHOT_TMP"
YOTA_SNAPSHOT_FILE="$SNAPSHOT_TMP" python3 <<'PYEOF'
import json, os
with open(os.environ['YOTA_SNAPSHOT_FILE']) as f:
    s = json.load(f)

status = s['status']
emoji = {'active': '▶', 'idle': '·', 'paused': '⏸', 'panic': '⛔'}.get(status, '?')

print(f"**Status:** {status} {emoji} — {s['workers']['active']}/{s['workers']['max']} worker.")

if s['panic_reason']:
    print(f"**Panic:** {s['panic_reason']}")

for w in s['workers']['details']:
    age = f"{w['age_min']} min" if w.get('age_min') is not None else 'unknown age'
    print(f"- `{w['slug']}` (pid {w['pid']}, {age})")

inb = s['inbox']
print(f"**Inbox:** {inb['stakeholder']} stakeholder, {inb['backlog']} backlog, "
      f"{inb['in_progress']} in-progress.")

c = s['cost']
print(f"**Heute:** {inb['done_today']} done, {inb['failed_today']} failed, "
      f"{s['disputes']['decided_today']} disput entschieden "
      f"(${c['today_usd']} von ${c['cap_today']} cap).")

print(f"**Week:** ${c['week_usd']} von ${c['cap_week']} cap. "
      f"**Yesterday:** ${c['yesterday_usd']}.")

a = s['auth']
auth_bits = [f"{k}={v}" for k, v in a.items()]
print(f"**Auth:** {', '.join(auth_bits)}.")

if s['alerts']:
    print('**Alerts:**')
    for al in s['alerts'][:5]:
        print(f'- {al}')
else:
    print('**Alerts:** keine.')

if s['last_briefing']:
    print(f"**Letztes briefing:** {s['last_briefing']}")

if s['last_merged_prs_24h']:
    print('**PRs merged (24h):**')
    for pr in s['last_merged_prs_24h'][:5]:
        print(f"- #{pr['num']} {pr['title']}")
PYEOF
