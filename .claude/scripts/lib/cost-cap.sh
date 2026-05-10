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

  # --- JSON-Zeile zusammenbauen ----------------------------------------------
  # Kein externes Tool (jq) nötig — Werte sind bereits validiert/kontrolliert.
  # agent wird escaped (einfache Strategie: Backslash + Anführungszeichen ersetzen).
  local agent_escaped
  agent_escaped="$(printf '%s' "$agent" | sed 's/\\/\\\\/g; s/"/\\"/g')"

  local json_line
  json_line="{\"ts\":\"${ts}\",\"agent\":\"${agent_escaped}\",\"usd\":${usd},\"pid\":${pid}}"

  # --- Atomares Append via flock (Linux) oder lockf (macOS/BSD) -------------
  # flock -x -w 5: exklusiver Lock, max 5 Sekunden Wartezeit.
  # lockf -t 5: macOS/BSD-Äquivalent.
  if command -v flock >/dev/null 2>&1; then
    (
      exec 200>"$lock_file"
      if ! flock -x -w 5 200; then
        printf 'cost_record: flock-Timeout auf "%s"\n' "$lock_file" >&2
        exit 3
      fi
      printf '%s\n' "$json_line" >> "$ledger_file"
    )
  elif command -v lockf >/dev/null 2>&1; then
    # lockf -t 5: wartet bis zu 5 Sekunden; exit != 0 bei Timeout
    if ! lockf -t 5 "$lock_file" sh -c "printf '%s\n' \"\$1\" >> \"\$2\"" -- "$json_line" "$ledger_file"; then
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
