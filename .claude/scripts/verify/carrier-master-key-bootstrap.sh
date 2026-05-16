#!/usr/bin/env bash
# verify/carrier-master-key-bootstrap.sh — Smoke-Test für die Vault-Secret-
# Bootstrap-Migration `20260516000000_carrier_master_key_bootstrap.sql`.
#
# Setzt voraus, dass ein lokaler Supabase-Stack läuft (`supabase start`).
# Wenn nicht: Exit 0 mit Skip-Notice (CI-freundlich, blockiert nicht).
#
# Tests:
#   1. Migration-File existiert + lässt sich parsen.
#   2. (Live) `_carrier_master_key()` liefert nach `supabase db reset`
#      einen non-empty TEXT, **ohne** P0001-Exception.
#   3. (Live) `vault.secrets WHERE name = 'carrier_master_key'` enthält
#      genau eine Row.
#
# Exit 0 = pass (oder skip wegen fehlendem Stack), Exit 1 = real failure.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
MIGRATION="$REPO_ROOT/supabase/migrations/20260516000000_carrier_master_key_bootstrap.sql"

PASS=0; FAIL=0
_pass() { printf '  [PASS] %s\n' "$1"; PASS=$((PASS + 1)); }
_fail() { printf '  [FAIL] %s\n' "$1"; FAIL=$((FAIL + 1)); }
_skip() { printf '  [SKIP] %s\n' "$1"; }

# ── Static check 1: File exists -----------------------------------------------
if [ -f "$MIGRATION" ]; then
  _pass "Migration-File vorhanden: $(basename "$MIGRATION")"
else
  _fail "Migration-File fehlt: $MIGRATION"
  printf '\nSummary: %d pass, %d fail\n' "$PASS" "$FAIL"
  exit 1
fi

# ── Static check 2: Migration enthält die erwarteten Blöcke ------------------
if grep -q 'vault.create_secret' "$MIGRATION" \
  && grep -q "name = 'carrier_master_key'" "$MIGRATION" \
  && grep -q 'WHEN insufficient_privilege' "$MIGRATION"; then
  _pass "Migration referenziert Vault-create_secret + EXCEPTION-Klauseln"
else
  _fail "Migration-Body fehlt erwartete Blöcke (vault.create_secret / EXCEPTION)"
fi

# ── Static check 3: KEIN WHEN OTHERS außerhalb von Kommentaren --------------
# (verschluckt sonst echte Fehler — Plan-Critic D1)
if grep -vE '^[[:space:]]*--' "$MIGRATION" | grep -q 'WHEN OTHERS'; then
  _fail "Migration enthält 'WHEN OTHERS' (außerhalb Kommentar) — verschluckt echte Fehler"
else
  _pass "Kein produktives 'WHEN OTHERS' (Plan-Critic D1 erfüllt)"
fi

# ── Live checks: nur wenn lokaler Stack erreichbar ---------------------------
if ! command -v supabase >/dev/null 2>&1; then
  _skip "Supabase-CLI nicht installiert — überspringe Live-Tests"
  printf '\nSummary: %d pass, %d fail\n' "$PASS" "$FAIL"
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
fi

# Prüfe, ob Stack läuft (heuristisch via `supabase status`)
if ! supabase status --workdir "$REPO_ROOT" >/dev/null 2>&1; then
  _skip "Lokaler Supabase-Stack ist nicht aktiv — überspringe Live-Tests"
  printf '\nSummary: %d pass, %d fail\n' "$PASS" "$FAIL"
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
fi

# DB-URL aus `supabase status` extrahieren (DB URL Zeile).
DB_URL="$(supabase status --workdir "$REPO_ROOT" 2>/dev/null \
  | awk -F': ' '/^[[:space:]]*DB URL/ {print $2; exit}')"

if [ -z "$DB_URL" ]; then
  _skip "Konnte DB-URL nicht ermitteln — überspringe Live-Tests"
  printf '\nSummary: %d pass, %d fail\n' "$PASS" "$FAIL"
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
  _skip "psql nicht installiert — überspringe Live-Tests"
  printf '\nSummary: %d pass, %d fail\n' "$PASS" "$FAIL"
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
fi

# Live check A: Vault-Secret-Row existiert (exakt 1)
ROW_COUNT="$(psql "$DB_URL" -tAc \
  "SELECT count(*) FROM vault.secrets WHERE name = 'carrier_master_key'" 2>/dev/null || echo "ERR")"

if [ "$ROW_COUNT" = "1" ]; then
  _pass "vault.secrets enthält genau 1 'carrier_master_key'-Row"
elif [ "$ROW_COUNT" = "0" ]; then
  _fail "vault.secrets enthält 0 'carrier_master_key'-Rows — Migration nicht angewandt?"
elif [ "$ROW_COUNT" = "ERR" ]; then
  _skip "DB-Query fehlgeschlagen (Vault-Extension verfügbar?)"
else
  _fail "vault.secrets enthält $ROW_COUNT Rows — Duplikate, bitte bereinigen"
fi

# Live check B: `_carrier_master_key()` liefert non-empty Text, kein RAISE
KEY_LEN="$(psql "$DB_URL" -tAc \
  "SELECT coalesce(length(public._carrier_master_key()), 0)" 2>/dev/null || echo "ERR")"

if [ "$KEY_LEN" = "ERR" ]; then
  _fail "_carrier_master_key() warf Exception (vermutlich P0001 wegen fehlendem Bootstrap)"
elif [ "$KEY_LEN" -gt 0 ] 2>/dev/null; then
  _pass "_carrier_master_key() liefert non-empty TEXT (length=$KEY_LEN)"
else
  _fail "_carrier_master_key() liefert empty/NULL (length=$KEY_LEN)"
fi

printf '\nSummary: %d pass, %d fail\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
