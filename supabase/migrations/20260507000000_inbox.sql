-- ─── Sprint 6: Postfach-Integration (Order-Inbox) ────────────────────────
--
-- Drei Tabellen + RPCs:
--   mailbox_accounts          IMAP-Zugänge pro Workspace (ohne Passwort).
--   mailbox_credentials       Verschlüsseltes Passwort, nur service_role.
--   parsed_messages           Geparste Mails (nur Header + extrahiertes JSON).
--   pending_deal_suggestions  Vom Parser erkannte, noch nicht akzeptierte Deals.
--
-- Sicherheits-Modell:
--   1. IMAP-Passwörter liegen NIE im Klartext in der DB. Sie werden über
--      `pgp_sym_encrypt` mit einem Master-Key aus Supabase Vault verschlüsselt.
--      Nur der service_role-Pfad kann sie wieder entschlüsseln (Edge
--      Function inbox-poll).
--   2. RLS lässt User nur Datensätze ihrer Workspaces lesen.
--   3. parsed_messages speichert NIE den vollen Mail-Body — nur From, Subject,
--      Date, das normalisierte JSON-Extrakt und einen Hash für Dedup.
--   4. parsed_messages wird nach 30 Tagen automatisch gelöscht
--      (Cron-Job in pg_cron).

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ── Vault-Helper: Master-Key auslesen ───────────────────────────────────
-- Erwartet einen Vault-Secret namens `mailbox_master_key`. Setup:
--   SELECT vault.create_secret(
--     encode(extensions.gen_random_bytes(32), 'hex'),
--     'mailbox_master_key',
--     'Master-Schlüssel für IMAP-Passwörter (Sprint 6)');
--
-- Fallback auf `current_setting('app.mailbox_master_key', true)` damit
-- self-hosted Setups ohne Vault funktionieren.
CREATE OR REPLACE FUNCTION public._mailbox_master_key()
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
     WHERE name = 'mailbox_master_key'
     LIMIT 1;
  EXCEPTION WHEN OTHERS THEN
    k := NULL;
  END;
  IF k IS NULL OR length(k) = 0 THEN
    k := current_setting('app.mailbox_master_key', true);
  END IF;
  IF k IS NULL OR length(k) = 0 THEN
    RAISE EXCEPTION 'mailbox_master_key fehlt: Vault-Secret oder app.mailbox_master_key setzen.';
  END IF;
  RETURN k;
END;
$$;

REVOKE EXECUTE ON FUNCTION public._mailbox_master_key() FROM PUBLIC;
-- Nur SECURITY DEFINER aus den RPCs unten — kein direkter Aufruf nötig.

-- ── mailbox_accounts ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.mailbox_accounts (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id    UUID        NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
  user_id         UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  label           TEXT        NOT NULL CHECK (length(label) BETWEEN 1 AND 80),
  imap_host       TEXT        NOT NULL CHECK (length(imap_host) BETWEEN 3 AND 255),
  imap_port       INTEGER     NOT NULL DEFAULT 993 CHECK (imap_port BETWEEN 1 AND 65535),
  use_ssl         BOOLEAN     NOT NULL DEFAULT TRUE,
  username        TEXT        NOT NULL CHECK (length(username) BETWEEN 1 AND 255),
  folder          TEXT        NOT NULL DEFAULT 'INBOX' CHECK (length(folder) BETWEEN 1 AND 120),
  enabled         BOOLEAN     NOT NULL DEFAULT TRUE,
  last_uid        BIGINT,
  last_polled_at  TIMESTAMPTZ,
  last_error      TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS mailbox_accounts_ws_idx
  ON public.mailbox_accounts(workspace_id) WHERE enabled = TRUE;
CREATE INDEX IF NOT EXISTS mailbox_accounts_poll_idx
  ON public.mailbox_accounts(last_polled_at NULLS FIRST) WHERE enabled = TRUE;
ALTER TABLE public.mailbox_accounts ENABLE ROW LEVEL SECURITY;

-- ── mailbox_credentials ─────────────────────────────────────────────────
-- Eigene Tabelle, damit RLS streng halten kann: keine User-Reads erlaubt.
CREATE TABLE IF NOT EXISTS public.mailbox_credentials (
  account_id          UUID PRIMARY KEY REFERENCES public.mailbox_accounts(id) ON DELETE CASCADE,
  encrypted_password  BYTEA NOT NULL,
  rotated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.mailbox_credentials ENABLE ROW LEVEL SECURITY;
-- Bewusst KEINE Policies: nur SECURITY DEFINER-Funktionen unten kommen ran.

-- ── parsed_messages ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.parsed_messages (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id    UUID        NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
  account_id      UUID        NOT NULL REFERENCES public.mailbox_accounts(id) ON DELETE CASCADE,
  message_uid     BIGINT      NOT NULL,
  message_hash    TEXT        NOT NULL,
  from_address    TEXT,
  subject         TEXT,
  received_at     TIMESTAMPTZ NOT NULL,
  shop_key        TEXT,
  parsed_payload  JSONB,
  status          TEXT        NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','matched','suggested','unclassified','failed')),
  match_deal_id   BIGINT      REFERENCES public.deals(id) ON DELETE SET NULL,
  error           TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at    TIMESTAMPTZ
);
CREATE UNIQUE INDEX IF NOT EXISTS parsed_messages_uniq_uid
  ON public.parsed_messages(account_id, message_uid);
CREATE UNIQUE INDEX IF NOT EXISTS parsed_messages_uniq_hash
  ON public.parsed_messages(account_id, message_hash);
CREATE INDEX IF NOT EXISTS parsed_messages_ws_status_idx
  ON public.parsed_messages(workspace_id, status, received_at DESC);
CREATE INDEX IF NOT EXISTS parsed_messages_pending_idx
  ON public.parsed_messages(status) WHERE status = 'pending';
ALTER TABLE public.parsed_messages ENABLE ROW LEVEL SECURITY;

-- ── pending_deal_suggestions ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.pending_deal_suggestions (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id        UUID        NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
  parsed_message_id   UUID        NOT NULL REFERENCES public.parsed_messages(id) ON DELETE CASCADE,
  shop_key            TEXT        NOT NULL,
  shop_label          TEXT,
  order_id            TEXT,
  product             TEXT,
  quantity            INTEGER     NOT NULL DEFAULT 1 CHECK (quantity > 0),
  total               NUMERIC(12,2),
  currency            TEXT        NOT NULL DEFAULT 'EUR' CHECK (length(currency) = 3),
  tracking            TEXT,
  carrier             TEXT,
  eta                 DATE,
  raw                 JSONB,
  created_deal_id     BIGINT      REFERENCES public.deals(id) ON DELETE SET NULL,
  resolved_at         TIMESTAMPTZ,
  resolved_action     TEXT        CHECK (resolved_action IN ('accepted','rejected')),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS pending_deal_suggestions_ws_idx
  ON public.pending_deal_suggestions(workspace_id, created_at DESC)
  WHERE resolved_at IS NULL;
ALTER TABLE public.pending_deal_suggestions ENABLE ROW LEVEL SECURITY;

-- ── RLS-Policies ────────────────────────────────────────────────────────
DROP POLICY IF EXISTS mailbox_accounts_ws_read   ON public.mailbox_accounts;
DROP POLICY IF EXISTS mailbox_accounts_ws_write  ON public.mailbox_accounts;
CREATE POLICY mailbox_accounts_ws_read ON public.mailbox_accounts FOR SELECT
  USING (public.is_workspace_member(workspace_id, auth.uid()));
CREATE POLICY mailbox_accounts_ws_write ON public.mailbox_accounts FOR ALL
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin']))
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin']));

DROP POLICY IF EXISTS parsed_messages_ws_read ON public.parsed_messages;
CREATE POLICY parsed_messages_ws_read ON public.parsed_messages FOR SELECT
  USING (public.is_workspace_member(workspace_id, auth.uid()));
-- Inserts/Updates kommen vom service_role (Edge Function) — keine
-- User-Schreib-Policy nötig.

DROP POLICY IF EXISTS pending_deal_suggestions_ws_read   ON public.pending_deal_suggestions;
DROP POLICY IF EXISTS pending_deal_suggestions_ws_update ON public.pending_deal_suggestions;
CREATE POLICY pending_deal_suggestions_ws_read ON public.pending_deal_suggestions FOR SELECT
  USING (public.is_workspace_member(workspace_id, auth.uid()));
-- Update erlaubt: User darf "akzeptiert/abgelehnt" markieren (Resolve-Flow).
CREATE POLICY pending_deal_suggestions_ws_update ON public.pending_deal_suggestions FOR UPDATE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']))
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));

-- ── RPCs für Credential-Handling ────────────────────────────────────────
-- Nur authentifizierte User mit Owner/Admin-Rolle dürfen ein Passwort setzen
-- ODER der service_role direkt (Edge Function-Setup-Pfad).

CREATE OR REPLACE FUNCTION public.set_mailbox_password(
  _account_id UUID,
  _password   TEXT
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  ws UUID;
BEGIN
  IF _password IS NULL OR length(_password) < 1 THEN
    RAISE EXCEPTION 'Passwort darf nicht leer sein.';
  END IF;

  SELECT workspace_id INTO ws
    FROM public.mailbox_accounts WHERE id = _account_id;
  IF ws IS NULL THEN
    RAISE EXCEPTION 'Mailbox-Account nicht gefunden.';
  END IF;

  IF auth.role() <> 'service_role'
     AND NOT public.has_workspace_role(ws, auth.uid(), ARRAY['owner','admin']) THEN
    RAISE EXCEPTION 'Keine Berechtigung für Mailbox-Account %.', _account_id;
  END IF;

  INSERT INTO public.mailbox_credentials (account_id, encrypted_password, rotated_at)
  VALUES (
    _account_id,
    extensions.pgp_sym_encrypt(_password, public._mailbox_master_key()),
    NOW()
  )
  ON CONFLICT (account_id) DO UPDATE
    SET encrypted_password = EXCLUDED.encrypted_password,
        rotated_at         = NOW();
END;
$$;

REVOKE EXECUTE ON FUNCTION public.set_mailbox_password(UUID, TEXT) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.set_mailbox_password(UUID, TEXT) TO authenticated;

-- Gibt das Klartext-Passwort zurück. Nur service_role darf das aufrufen
-- (Edge Function inbox-poll).
CREATE OR REPLACE FUNCTION public.get_mailbox_password(_account_id UUID)
RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  ciphertext BYTEA;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'Nur service_role darf get_mailbox_password aufrufen.';
  END IF;

  SELECT encrypted_password INTO ciphertext
    FROM public.mailbox_credentials
   WHERE account_id = _account_id;
  IF ciphertext IS NULL THEN
    RETURN NULL;
  END IF;

  RETURN extensions.pgp_sym_decrypt(ciphertext, public._mailbox_master_key());
END;
$$;

REVOKE EXECUTE ON FUNCTION public.get_mailbox_password(UUID) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_mailbox_password(UUID) TO service_role;

-- ── updated_at-Trigger für mailbox_accounts ─────────────────────────────
CREATE OR REPLACE FUNCTION public.mailbox_accounts_touch_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS mailbox_accounts_set_updated_at ON public.mailbox_accounts;
CREATE TRIGGER mailbox_accounts_set_updated_at
  BEFORE UPDATE ON public.mailbox_accounts
  FOR EACH ROW
  EXECUTE FUNCTION public.mailbox_accounts_touch_updated_at();

-- ── Auto-Cleanup nach 30 Tagen ──────────────────────────────────────────
-- pg_cron läuft täglich 03:15 UTC und löscht alte parsed_messages +
-- ungelöste suggestions. Aktive Deals bleiben unberührt.
CREATE OR REPLACE FUNCTION public.cleanup_inbox_history()
RETURNS VOID LANGUAGE sql AS $$
  DELETE FROM public.parsed_messages
   WHERE created_at < NOW() - INTERVAL '30 days';

  DELETE FROM public.pending_deal_suggestions
   WHERE created_at < NOW() - INTERVAL '30 days'
     AND resolved_at IS NULL;
$$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cleanup_inbox_history_daily') THEN
    PERFORM cron.unschedule('cleanup_inbox_history_daily');
  END IF;
  PERFORM cron.schedule(
    'cleanup_inbox_history_daily',
    '15 3 * * *',
    $job$ SELECT public.cleanup_inbox_history(); $job$
  );
EXCEPTION WHEN OTHERS THEN
  -- Falls pg_cron nicht verfügbar (z.B. lokale Tests), still scheitern.
  RAISE NOTICE 'pg_cron nicht verfügbar, Cleanup-Job nicht eingeplant: %', SQLERRM;
END;
$$;
