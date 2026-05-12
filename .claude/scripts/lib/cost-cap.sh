#!/usr/bin/env bash
# cost-cap.sh — Cost-Cap-Library (Teil 1: Ledger-Append)
#
# Sourceable Bash-Library. Stellt cost_record <agent> <usd> bereit.
#
# WICHTIG: Diese Datei ist in der Self-Mod-Blocklist — darf durch Agenten
# im Headless-Mode nicht überschrieben werden.
#
# Nutzung:
#   source .claude/scripts/lib/cost-cap.sh
#   cost_record "my-agent" "0.05"

set -euo pipefail

# --- Pfad-Resolution --------------------------------------------------------
# LEDGER_DIR kann via Env überschrieben werden (für Tests in mktemp-Sandbox).
_cost_cap_ledger_dir() {
  if [ -n "${COST_CAP_LEDGER_DIR:-}" ]; then
    printf '%s' "$COST_CAP_LEDGER_DIR"
  else
    local root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
    printf '%s/.claude/overseer' "$root"
  fi
}

# --- cost_record <agent> <usd> ----------------------------------------------
# Appendet einen JSONL-Eintrag atomar (flock) in cost-ledger.jsonl.
#
# Exit-Codes:
#   0  — Eintrag erfolgreich geschrieben.
#   1  — Ungültige Argumente (<agent> leer oder <usd> kein positives Decimal).
#   3  — flock-Timeout (> 5 Sekunden).
cost_record() {
  local agent="${1:-}"
  local usd="${2:-}"

  # --- Validierung -----------------------------------------------------------
  if [ -z "$agent" ]; then
    printf 'cost_record: <agent> darf nicht leer sein\n' >&2
    return 1
  fi

  # usd muss positive Zahl sein: ganze Zahl oder Decimal (kein negativer Wert)
  if ! printf '%s' "$usd" | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
    printf 'cost_record: <usd> muss eine positive Zahl sein, erhalten: "%s"\n' "$usd" >&2
    return 1
  fi

  # --- Verzeichnis sicherstellen ---------------------------------------------
  local ledger_dir
  ledger_dir="$(_cost_cap_ledger_dir)"
  mkdir -p "$ledger_dir"

  local ledger_file="$ledger_dir/cost-ledger.jsonl"
  local lock_file="$ledger_dir/.cost-ledger.lock"

  # --- Timestamp + PID -------------------------------------------------------
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local pid="$$"

  # --- Atomares Append via flock (Linux) oder lockf (macOS/BSD) -------------
  # Hash-Chain-Berechnung findet INNERHALB des flock statt, um Race auf
  # prev_hash zu verhindern. flock schützt bereits vor parallelen Schreibern.
  if command -v flock >/dev/null 2>&1; then
    (
      exec 200>"$lock_file"
      if ! flock -x -w 5 200; then
        printf 'cost_record: flock-Timeout auf "%s"\n' "$lock_file" >&2
        exit 3
      fi
      # Hash-Chain innerhalb des Locks berechnen und atomar appenden
      python3 - "$ledger_file" "$ts" "$agent" "$usd" "$pid" <<'PYEOF'
import sys, json, hashlib

ledger_file = sys.argv[1]
ts          = sys.argv[2]
agent       = sys.argv[3]
usd         = sys.argv[4]
pid         = sys.argv[5]

def sha256(s: str) -> str:
    return hashlib.sha256(s.encode('utf-8')).hexdigest()

zero_hash = '0' * 64

# Compute prev_hash: SHA256 of the full last line (including newline)
prev_hash = zero_hash
try:
    with open(ledger_file, 'r') as f:
        lines = [l for l in f.readlines() if l.strip()]
    if lines:
        prev_hash = sha256(lines[-1])
except FileNotFoundError:
    pass

# Compute entry_hash over deterministic concat
entry_data = f"{ts}|{agent}|{usd}|{pid}|{prev_hash}"
entry_hash = sha256(entry_data)

# Escape agent for JSON
agent_json = json.dumps(agent)[1:-1]  # strip surrounding quotes

line = (f'{{"ts":"{ts}","agent":"{agent_json}",'
        f'"usd":{usd},"pid":{pid},'
        f'"prev_hash":"{prev_hash}","entry_hash":"{entry_hash}"}}\n')

with open(ledger_file, 'a') as f:
    f.write(line)
PYEOF
    )
  elif command -v lockf >/dev/null 2>&1; then
    # lockf -t 5: wartet bis zu 5 Sekunden; exit != 0 bei Timeout
    # On macOS/BSD, run hash-chain computation inside lockf subprocess
    if ! lockf -t 5 "$lock_file" python3 - "$ledger_file" "$ts" "$agent" "$usd" "$pid" <<'PYEOF'; then
import sys, json, hashlib

ledger_file = sys.argv[1]
ts          = sys.argv[2]
agent       = sys.argv[3]
usd         = sys.argv[4]
pid         = sys.argv[5]

def sha256(s: str) -> str:
    return hashlib.sha256(s.encode('utf-8')).hexdigest()

zero_hash = '0' * 64

prev_hash = zero_hash
try:
    with open(ledger_file, 'r') as f:
        lines = [l for l in f.readlines() if l.strip()]
    if lines:
        prev_hash = sha256(lines[-1])
except FileNotFoundError:
    pass

entry_data = f"{ts}|{agent}|{usd}|{pid}|{prev_hash}"
entry_hash = sha256(entry_data)

agent_json = json.dumps(agent)[1:-1]

line = (f'{{"ts":"{ts}","agent":"{agent_json}",'
        f'"usd":{usd},"pid":{pid},'
        f'"prev_hash":"{prev_hash}","entry_hash":"{entry_hash}"}}\n')

with open(ledger_file, 'a') as f:
    f.write(line)
PYEOF
      printf 'cost_record: lockf-Timeout auf "%s"\n' "$lock_file" >&2
      return 3
    fi
  else
    printf 'cost_record: kein flock/lockf verfügbar\n' >&2
    return 3
  fi
  local rc=$?
  return $rc
}

# --- cost_record_full <agent> <usd> <input_tokens> <cached_tokens> <output_tokens> ---
# Extended variant of cost_record that also stores token counts in the ledger.
# Backwards-compat: falls back to cost_record if token args are omitted/zero.
#
# JSONL-Entry-Format (extended):
#   {"ts":"...", "agent":"...", "usd":0.42, "pid":12345,
#    "input_tokens":1234, "cached_input_tokens":1000, "output_tokens":567,
#    "prev_hash":"...", "entry_hash":"..."}
#
# Hash-chain: entry_data includes token fields so hash is over all fields.
cost_record_full() {
  local agent="${1:-}"
  local usd="${2:-}"
  local input_tokens="${3:-0}"
  local cached_tokens="${4:-0}"
  local output_tokens="${5:-0}"

  # --- Validierung -----------------------------------------------------------
  if [ -z "$agent" ]; then
    printf 'cost_record_full: <agent> darf nicht leer sein\n' >&2
    return 1
  fi
  if ! printf '%s' "$usd" | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
    printf 'cost_record_full: <usd> muss eine positive Zahl sein, erhalten: "%s"\n' "$usd" >&2
    return 1
  fi
  # Validate token counts are non-negative integers (default 0 if empty).
  input_tokens="${input_tokens:-0}"
  cached_tokens="${cached_tokens:-0}"
  output_tokens="${output_tokens:-0}"
  if ! printf '%s' "$input_tokens" | grep -qE '^[0-9]+$'; then input_tokens=0; fi
  if ! printf '%s' "$cached_tokens" | grep -qE '^[0-9]+$'; then cached_tokens=0; fi
  if ! printf '%s' "$output_tokens" | grep -qE '^[0-9]+$'; then output_tokens=0; fi

  # --- Verzeichnis sicherstellen ---------------------------------------------
  local ledger_dir
  ledger_dir="$(_cost_cap_ledger_dir)"
  mkdir -p "$ledger_dir"

  local ledger_file="$ledger_dir/cost-ledger.jsonl"
  local lock_file="$ledger_dir/.cost-ledger.lock"

  local ts pid
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  pid="$$"

  if command -v flock >/dev/null 2>&1; then
    (
      exec 200>"$lock_file"
      if ! flock -x -w 5 200; then
        printf 'cost_record_full: flock-Timeout auf "%s"\n' "$lock_file" >&2
        exit 3
      fi
      python3 - "$ledger_file" "$ts" "$agent" "$usd" "$pid" \
                "$input_tokens" "$cached_tokens" "$output_tokens" <<'PYEOF'
import sys, json, hashlib

ledger_file    = sys.argv[1]
ts             = sys.argv[2]
agent          = sys.argv[3]
usd            = sys.argv[4]
pid            = sys.argv[5]
input_tokens   = int(sys.argv[6])
cached_tokens  = int(sys.argv[7])
output_tokens  = int(sys.argv[8])

def sha256(s: str) -> str:
    return hashlib.sha256(s.encode('utf-8')).hexdigest()

zero_hash = '0' * 64
prev_hash = zero_hash
try:
    with open(ledger_file, 'r') as f:
        lines = [l for l in f.readlines() if l.strip()]
    if lines:
        prev_hash = sha256(lines[-1])
except FileNotFoundError:
    pass

# entry_hash includes token fields for full integrity coverage
entry_data = (f"{ts}|{agent}|{usd}|{pid}|{prev_hash}"
              f"|{input_tokens}|{cached_tokens}|{output_tokens}")
entry_hash = sha256(entry_data)

agent_json = json.dumps(agent)[1:-1]

line = (f'{{"ts":"{ts}","agent":"{agent_json}",'
        f'"usd":{usd},"pid":{pid},'
        f'"input_tokens":{input_tokens},'
        f'"cached_input_tokens":{cached_tokens},'
        f'"output_tokens":{output_tokens},'
        f'"prev_hash":"{prev_hash}","entry_hash":"{entry_hash}"}}\n')

with open(ledger_file, 'a') as f:
    f.write(line)
PYEOF
    )
  elif command -v lockf >/dev/null 2>&1; then
    if ! lockf -t 5 "$lock_file" python3 - "$ledger_file" "$ts" "$agent" "$usd" "$pid" \
                "$input_tokens" "$cached_tokens" "$output_tokens" <<'PYEOF'; then
import sys, json, hashlib

ledger_file    = sys.argv[1]
ts             = sys.argv[2]
agent          = sys.argv[3]
usd            = sys.argv[4]
pid            = sys.argv[5]
input_tokens   = int(sys.argv[6])
cached_tokens  = int(sys.argv[7])
output_tokens  = int(sys.argv[8])

def sha256(s: str) -> str:
    return hashlib.sha256(s.encode('utf-8')).hexdigest()

zero_hash = '0' * 64
prev_hash = zero_hash
try:
    with open(ledger_file, 'r') as f:
        lines = [l for l in f.readlines() if l.strip()]
    if lines:
        prev_hash = sha256(lines[-1])
except FileNotFoundError:
    pass

entry_data = (f"{ts}|{agent}|{usd}|{pid}|{prev_hash}"
              f"|{input_tokens}|{cached_tokens}|{output_tokens}")
entry_hash = sha256(entry_data)

agent_json = json.dumps(agent)[1:-1]

line = (f'{{"ts":"{ts}","agent":"{agent_json}",'
        f'"usd":{usd},"pid":{pid},'
        f'"input_tokens":{input_tokens},'
        f'"cached_input_tokens":{cached_tokens},'
        f'"output_tokens":{output_tokens},'
        f'"prev_hash":"{prev_hash}","entry_hash":"{entry_hash}"}}\n')

with open(ledger_file, 'a') as f:
    f.write(line)
PYEOF
      printf 'cost_record_full: lockf-Timeout auf "%s"\n' "$lock_file" >&2
      return 3
    fi
  else
    printf 'cost_record_full: kein flock/lockf verfügbar\n' >&2
    return 3
  fi
  local rc=$?
  return $rc
}

# --- cost_today_usd ---------------------------------------------------------
# Summiert alle <usd>-Felder aus cost-ledger.jsonl mit ts-Datum == heute (UTC).
# Echo: Float mit 2 Dezimalstellen (z.B. "3.27"). Bei leerem/fehlendem Ledger: "0.00".
cost_today_usd() {
  local ledger_dir ledger_file
  ledger_dir="$(_cost_cap_ledger_dir)"
  ledger_file="$ledger_dir/cost-ledger.jsonl"

  if [ ! -f "$ledger_file" ]; then
    printf '0.00\n'
    return 0
  fi

  python3 - "$ledger_file" <<'PYEOF'
import sys, json
from datetime import datetime, timezone

ledger_file = sys.argv[1]
today = datetime.now(timezone.utc).strftime('%Y-%m-%d')
total = 0.0
try:
    with open(ledger_file, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
                ts = entry.get('ts', '')
                if ts.startswith(today):
                    total += float(entry.get('usd', 0))
            except (json.JSONDecodeError, ValueError):
                continue
except FileNotFoundError:
    pass
print(f'{total:.2f}')
PYEOF
}

# --- cost_week_usd ----------------------------------------------------------
# Summiert alle <usd>-Felder aus cost-ledger.jsonl der letzten 7 Tage (heute - 6).
# Echo: Float mit 2 Dezimalstellen. Bei leerem/fehlendem Ledger: "0.00".
cost_week_usd() {
  local ledger_dir ledger_file
  ledger_dir="$(_cost_cap_ledger_dir)"
  ledger_file="$ledger_dir/cost-ledger.jsonl"

  if [ ! -f "$ledger_file" ]; then
    printf '0.00\n'
    return 0
  fi

  python3 - "$ledger_file" <<'PYEOF'
import sys, json
from datetime import datetime, timezone, timedelta

ledger_file = sys.argv[1]
now = datetime.now(timezone.utc)
cutoff = (now - timedelta(days=6)).strftime('%Y-%m-%d')
total = 0.0
try:
    with open(ledger_file, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
                ts = entry.get('ts', '')
                # ts format: YYYY-MM-DDTHH:MM:SSZ — compare date prefix
                entry_date = ts[:10]
                if entry_date >= cutoff:
                    total += float(entry.get('usd', 0))
            except (json.JSONDecodeError, ValueError):
                continue
except FileNotFoundError:
    pass
print(f'{total:.2f}')
PYEOF
}

# --- cost_check_or_die <max_today> <max_week> --------------------------------
# Prüft ob Tages- oder Wochen-Budget überschritten. Schreibt Marker-File und
# beendet mit exit 2 bei Überschreitung.
#
# Exit-Codes:
#   0  — Budget OK.
#   1  — Ungültige Argumente.
#   2  — Cost-Cap überschritten (COST_CAP_REACHED Marker geschrieben).
cost_check_or_die() {
  local max_today="${1:-}"
  local max_week="${2:-}"

  # Argumente validieren — müssen Floats/Integers sein
  if ! printf '%s' "$max_today" | grep -qE '^[0-9]+(\.[0-9]+)?$' || \
     ! printf '%s' "$max_week"  | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
    printf '[cost-cap] ERROR: Ungültige Argumente — max_today="%s" max_week="%s" (erwartet: positive Zahlen)\n' \
      "$max_today" "$max_week" >&2
    return 1
  fi

  local today_usd week_usd
  today_usd="$(cost_today_usd)"
  week_usd="$(cost_week_usd)"

  # Float-Vergleich via python3
  local exceeded
  exceeded="$(python3 - "$today_usd" "$max_today" "$week_usd" "$max_week" <<'PYEOF'
import sys
today_usd  = float(sys.argv[1])
max_today  = float(sys.argv[2])
week_usd   = float(sys.argv[3])
max_week   = float(sys.argv[4])
print('1' if today_usd > max_today or week_usd > max_week else '0')
PYEOF
)"

  if [ "$exceeded" = "1" ]; then
    printf '[cost-cap] HARD-STOP: today=%sUSD/%sUSD week=%sUSD/%sUSD\n' \
      "$today_usd" "$max_today" "$week_usd" "$max_week" >&2

    # Marker-File schreiben
    local ledger_dir marker_file
    ledger_dir="$(_cost_cap_ledger_dir)"
    mkdir -p "$ledger_dir"
    marker_file="$ledger_dir/COST_CAP_REACHED"
    printf 'HARD-STOP at %s: today=%sUSD/%sUSD week=%sUSD/%sUSD\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      "$today_usd" "$max_today" "$week_usd" "$max_week" > "$marker_file"
    return 2
  fi

  return 0
}
