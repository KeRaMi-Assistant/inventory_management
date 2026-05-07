-- ─── Sprint 7: Carrier-API-Credentials für tracking-poll ────────────────
--
-- Speichert pro (workspace, carrier) einen verschlüsselten API-Key, mit dem
-- die Edge Function `tracking-poll` die Sendungsverfolgungs-APIs der Carrier
-- (DHL, DPD, UPS) abfragt. Analog zu mailbox_credentials:
--   * Klartext-Keys liegen NIE in der DB (pgp_sym_encrypt mit Vault-Master-Key).
--   * Owner/Admin dürfen via SECURITY-DEFINER-RPC Keys setzen + maskiert lesen.
--   * Nur service_role darf den Klartext auslesen (Edge Function).
--
-- Tabelle ist workspace-scoped, weil mehrere Workspaces unabhängig
-- voneinander Carrier-Konten haben können.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ── Vault-Helper: Master-Key auslesen ───────────────────────────────────
-- Erwartet einen Vault-Secret namens `carrier_master_key`. Setup:
--   SELECT vault.create_secret(
--     encode(extensions.gen_random_bytes(32), 'hex'),
--     'carrier_master_key',
--     'Master-Schlüssel für Carrier-API-Keys (Sprint 7)');
--
-- Fallback auf `app.carrier_master_key` damit lokale Tests ohne Vault
-- (supabase db reset) durchlaufen.
CREATE OR REPLACE FUNCTION public._carrier_master_key()
RETURNS TEXT
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, vault
AS $$
DECLARE
  k TEXT;
BEGIN
  BEGIN
    SELECT decrypted_secret
      INTO k
      FROM vault.decrypted_secrets
     WHERE name = 'carrier_master_key'
     LIMIT 1;
  EXCEPTION WHEN OTHERS THEN
    k := NULL;
  END;
  IF k IS NULL OR length(k) = 0 THEN
    k := current_setting('app.carrier_master_key', true);
  END IF;
  IF k IS NULL OR length(k) = 0 THEN
    RAISE EXCEPTION 'carrier_master_key fehlt: Vault-Secret oder app.carrier_master_key setzen.';
  END IF;
  RETURN k;
END;
$$;

REVOKE EXECUTE ON FUNCTION public._carrier_master_key() FROM PUBLIC;

-- ── workspace_carrier_credentials ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.workspace_carrier_credentials (
  workspace_id        UUID        NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
  carrier_id          TEXT        NOT NULL CHECK (carrier_id IN ('dhl','dpd','ups')),
  api_key_encrypted   BYTEA       NOT NULL,
  -- Letzte 4 Zeichen zur Anzeige `••••<last4>` ohne Decrypt-Roundtrip.
  api_key_last4       TEXT        NOT NULL CHECK (length(api_key_last4) BETWEEN 1 AND 4),
  enabled             BOOLEAN     NOT NULL DEFAULT TRUE,
  last_polled_at      TIMESTAMPTZ,
  last_error          TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (workspace_id, carrier_id)
);
CREATE INDEX IF NOT EXISTS workspace_carrier_credentials_ws_idx
  ON public.workspace_carrier_credentials(workspace_id) WHERE enabled = TRUE;
ALTER TABLE public.workspace_carrier_credentials ENABLE ROW LEVEL SECURITY;
-- Bewusst KEINE Policies: nur SECURITY-DEFINER-RPCs unten kommen ran.
-- Owner/Admin lesen via list_carrier_credentials() (gibt Klartext NICHT raus).

-- ── RPC: Key setzen ─────────────────────────────────────────────────────
-- Nur Owner/Admin oder service_role. Validiert Carrier-ID + Key-Länge.
CREATE OR REPLACE FUNCTION public.set_carrier_api_key(
  _workspace_id UUID,
  _carrier_id   TEXT,
  _api_key      TEXT
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  trimmed TEXT;
  last4   TEXT;
BEGIN
  IF _api_key IS NULL OR length(trim(_api_key)) < 8 THEN
    RAISE EXCEPTION 'API-Key muss mindestens 8 Zeichen haben.';
  END IF;
  IF _carrier_id NOT IN ('dhl','dpd','ups') THEN
    RAISE EXCEPTION 'Unbekannter Carrier: %', _carrier_id;
  END IF;
  IF auth.role() <> 'service_role'
     AND NOT public.has_workspace_role(_workspace_id, auth.uid(), ARRAY['owner','admin']) THEN
    RAISE EXCEPTION 'Keine Berechtigung für Workspace %.', _workspace_id;
  END IF;

  trimmed := trim(_api_key);
  last4 := right(trimmed, 4);

  INSERT INTO public.workspace_carrier_credentials AS wcc
    (workspace_id, carrier_id, api_key_encrypted, api_key_last4, enabled, updated_at)
  VALUES (
    _workspace_id,
    _carrier_id,
    extensions.pgp_sym_encrypt(trimmed, public._carrier_master_key()),
    last4,
    TRUE,
    NOW()
  )
  ON CONFLICT (workspace_id, carrier_id) DO UPDATE
    SET api_key_encrypted = EXCLUDED.api_key_encrypted,
        api_key_last4     = EXCLUDED.api_key_last4,
        enabled           = TRUE,
        last_error        = NULL,
        updated_at        = NOW();
END;
$$;

REVOKE EXECUTE ON FUNCTION public.set_carrier_api_key(UUID, TEXT, TEXT) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.set_carrier_api_key(UUID, TEXT, TEXT) TO authenticated;

-- ── RPC: Key löschen ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.delete_carrier_api_key(
  _workspace_id UUID,
  _carrier_id   TEXT
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.role() <> 'service_role'
     AND NOT public.has_workspace_role(_workspace_id, auth.uid(), ARRAY['owner','admin']) THEN
    RAISE EXCEPTION 'Keine Berechtigung für Workspace %.', _workspace_id;
  END IF;
  DELETE FROM public.workspace_carrier_credentials
   WHERE workspace_id = _workspace_id
     AND carrier_id   = _carrier_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.delete_carrier_api_key(UUID, TEXT) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.delete_carrier_api_key(UUID, TEXT) TO authenticated;

-- ── RPC: Liste mit maskierten Keys (für UI) ─────────────────────────────
-- Liefert NIE den Klartext. Nur Owner/Admin lesen, Member/Viewer sehen
-- die Liste nicht (analog zu mailbox_credentials, die Member auch nicht
-- sehen sollen).
CREATE OR REPLACE FUNCTION public.list_carrier_credentials(
  _workspace_id UUID
) RETURNS TABLE (
  carrier_id     TEXT,
  api_key_last4  TEXT,
  enabled        BOOLEAN,
  last_polled_at TIMESTAMPTZ,
  last_error     TEXT,
  updated_at     TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.role() <> 'service_role'
     AND NOT public.has_workspace_role(_workspace_id, auth.uid(), ARRAY['owner','admin']) THEN
    RAISE EXCEPTION 'Keine Berechtigung für Workspace %.', _workspace_id;
  END IF;
  RETURN QUERY
    SELECT wcc.carrier_id,
           wcc.api_key_last4,
           wcc.enabled,
           wcc.last_polled_at,
           wcc.last_error,
           wcc.updated_at
      FROM public.workspace_carrier_credentials wcc
     WHERE wcc.workspace_id = _workspace_id
     ORDER BY wcc.carrier_id ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_carrier_credentials(UUID) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.list_carrier_credentials(UUID) TO authenticated;

-- ── RPC: Key entschlüsselt für Edge Function ────────────────────────────
-- Nur service_role. Liefert (api_key_clear, enabled) — die Edge Function
-- iteriert pro Workspace + Carrier separat.
CREATE OR REPLACE FUNCTION public.get_carrier_api_key(
  _workspace_id UUID,
  _carrier_id   TEXT
) RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  ciphertext BYTEA;
  is_enabled BOOLEAN;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'Nur service_role darf get_carrier_api_key aufrufen.';
  END IF;
  SELECT api_key_encrypted, enabled
    INTO ciphertext, is_enabled
    FROM public.workspace_carrier_credentials
   WHERE workspace_id = _workspace_id
     AND carrier_id   = _carrier_id;
  IF ciphertext IS NULL OR is_enabled IS NOT TRUE THEN
    RETURN NULL;
  END IF;
  RETURN extensions.pgp_sym_decrypt(ciphertext, public._carrier_master_key());
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_carrier_api_key(UUID, TEXT) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_carrier_api_key(UUID, TEXT) TO service_role;

-- ── updated_at-Trigger ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.workspace_carrier_credentials_touch()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS workspace_carrier_credentials_set_updated_at
  ON public.workspace_carrier_credentials;
CREATE TRIGGER workspace_carrier_credentials_set_updated_at
  BEFORE UPDATE ON public.workspace_carrier_credentials
  FOR EACH ROW
  EXECUTE FUNCTION public.workspace_carrier_credentials_touch();
