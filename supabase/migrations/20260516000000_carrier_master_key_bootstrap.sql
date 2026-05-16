-- ─── Carrier-Master-Key Vault-Bootstrap ────────────────────────────────
--
-- Warum:
--   Sprint-7-Migration `20260508000000_workspace_carrier_credentials.sql`
--   führt `public._carrier_master_key()` ein. Diese Function liest den
--   Master-Schlüssel, mit dem `workspace_carrier_credentials.api_key_encrypted`
--   (BYTEA, pgp_sym_encrypt) ent-/verschlüsselt wird, primär aus dem
--   Supabase-Vault-Secret namens `carrier_master_key` und fällt sonst auf
--   `current_setting('app.carrier_master_key', true)` zurück. Existiert
--   weder Vault-Secret noch GUC, wirft die Function `RAISE EXCEPTION` und
--   blockiert sämtliche Carrier-API-Key-Flows (DHL, DPD, UPS).
--
--   Plan-Referenz: `plans/2026-05-16_dhl_tracking_activation.md` §D1.
--
-- Wann:
--   Post-Sprint-7. Diese Migration läuft idempotent — sowohl bei
--   frischem `supabase db reset` als auch in bestehenden Prod-Umgebungen,
--   ohne bereits gesetzte Vault-Secrets zu überschreiben oder zu
--   duplizieren.
--
-- Wie idempotent:
--   1. EXISTS-Check via `count(*)` auf `vault.secrets WHERE name =
--      'carrier_master_key'` (`vault.secrets.name` ist **nicht** unique-
--      constrained, daher Count-Check statt INSERT-ON-CONFLICT).
--   2. count = 1  → NOTICE + skip.
--   3. count = 0  → `vault.create_secret(<32 random bytes hex>, ...)`.
--   4. count > 1  → WARNING (Migration bleibt grün), manuelle Bereinigung
--      durch Operator nötig.
--
-- Was passiert, wenn Vault fehlt (Self-Hosting, Vault-Extension nicht
-- installiert, fehlende Privilegien): innerer BEGIN/EXCEPTION-Block
-- fängt spezifische SQLSTATE-Klassen (`invalid_schema_name` (3F000),
-- `undefined_table` (42P01), `undefined_function` (42883),
-- `insufficient_privilege` (42501)) ab und schreibt einen
-- klaren NOTICE — die Migration läuft grün durch. Der Operator muss in
-- diesem Fall manuell `ALTER DATABASE <db> SET app.carrier_master_key =
-- '<32-byte hex>'` setzen; `_carrier_master_key()` greift via Fallback.
-- KEIN `WHEN OTHERS` — sonst würden echte Fehler (Vault-DDL-Bugs,
-- Disk-Full, etc.) stillschweigend verschluckt.
--
-- Sicherheit:
--   Klartext-Schlüssel wird zur Migrations-Zeit per
--   `extensions.gen_random_bytes(32)` erzeugt (cryptographically secure)
--   und ausschließlich in `vault.secrets` abgelegt — vault-managed,
--   verschlüsselt at rest. Kein Schlüssel im Repo, kein Schlüssel in
--   Migrations-History, kein Schlüssel in Logs.

DO $$
DECLARE
  existing_count INTEGER;
BEGIN
  BEGIN
    SELECT count(*)
      INTO existing_count
      FROM vault.secrets
     WHERE name = 'carrier_master_key';

    IF existing_count > 1 THEN
      RAISE WARNING
        'Duplicate carrier_master_key Vault-Secret-Einträge gefunden (count=%), bitte manuell bereinigen',
        existing_count;
    ELSIF existing_count = 1 THEN
      RAISE NOTICE 'Carrier-Master-Key Vault-Secret bereits vorhanden, skip.';
    ELSE
      PERFORM vault.create_secret(
        encode(extensions.gen_random_bytes(32), 'hex'),
        'carrier_master_key',
        'Auto-bootstrapped by migration 20260516000000'
      );
      RAISE NOTICE 'Carrier-Master-Key Vault-Secret angelegt.';
    END IF;

  EXCEPTION
    WHEN invalid_schema_name THEN
      RAISE NOTICE
        'Vault-Schema fehlt (Self-Hosting ohne Supabase-Vault). Bitte app.carrier_master_key manuell via ALTER DATABASE setzen.';
    WHEN undefined_table THEN
      RAISE NOTICE
        'vault.secrets-Tabelle fehlt (Vault-Extension nicht installiert). Bitte app.carrier_master_key manuell via ALTER DATABASE setzen.';
    WHEN undefined_function THEN
      RAISE NOTICE
        'vault.create_secret()-Function fehlt (Vault-Extension nicht installiert). Bitte app.carrier_master_key manuell via ALTER DATABASE setzen.';
    WHEN insufficient_privilege THEN
      RAISE NOTICE
        'Migration ohne Vault-Privileg ausgeführt — Bootstrap übersprungen. Bitte app.carrier_master_key manuell setzen oder Migration als Superuser/postgres-Rolle erneut laufen lassen.';
  END;
END
$$;
