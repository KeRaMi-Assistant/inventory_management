-- ─── Inbox: "Alle als gelesen markieren" ─────────────────────────────────
--
-- Plan: plans/2026-05-07_inbox_mark_all_read.md (Tasks T1 + T11)
--
-- Diese Migration legt eine pro-User-Lese-Status-Tabelle für die Inbox an.
-- "gelesen" ist NICHT "verworfen" und NICHT "akzeptiert":
--   * Akzeptieren  → pending_deal_suggestions.resolved_at
--   * Verwerfen    → parsed_messages.status='dismissed' + inbox_dismissals
--   * Gelesen      → inbox_reads (diese Tabelle, nur UI-Indicator)
--
-- Designentscheidungen (siehe Plan):
--   * Composite-PK (workspace_id, parsed_message_id, read_by) → Idempotenz
--     für Bulk-Mark via INSERT ... ON CONFLICT DO NOTHING.
--   * Pro-User-State: jeder Workspace-Member hat seinen eigenen Lese-Status.
--   * ON DELETE CASCADE auf parsed_message_id → cleanup_inbox_history()
--     räumt automatisch mit auf, keine Anpassung dort nötig.
--   * RLS: read_by = auth.uid() Constraint → kein Cross-User-Zugriff im
--     selben Workspace. Member-Check via Helper aus 20260504000300.

-- ── Tabelle ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.inbox_reads (
  workspace_id      UUID        NOT NULL REFERENCES public.workspaces(id)        ON DELETE CASCADE,
  parsed_message_id UUID        NOT NULL REFERENCES public.parsed_messages(id)   ON DELETE CASCADE,
  read_by           UUID        NOT NULL REFERENCES auth.users(id)               ON DELETE CASCADE,
  read_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (workspace_id, parsed_message_id, read_by)
);

-- ── Indexe ───────────────────────────────────────────────────────────────
-- Lookup-Pfad: "alle gelesenen Einträge des aktuellen Users im Workspace"
-- (entspricht dem Provider-Refresh-Query loadInboxReads()).
CREATE INDEX IF NOT EXISTS inbox_reads_ws_user_idx
  ON public.inbox_reads(workspace_id, read_by);

-- FK-Index für den Cleanup-Pfad (parsed_messages CASCADE-Löschungen).
CREATE INDEX IF NOT EXISTS inbox_reads_parsed_message_idx
  ON public.inbox_reads(parsed_message_id);

-- ── RLS ──────────────────────────────────────────────────────────────────
ALTER TABLE public.inbox_reads ENABLE ROW LEVEL SECURITY;

-- Default-Deny ist durch ENABLE RLS ohne Policies bereits gegeben. Wir
-- definieren explizit eine SELECT- und eine ALL-Policy, beide mit dem
-- harten Constraint read_by = auth.uid() — niemand sieht oder schreibt
-- fremde Read-Marker, auch nicht innerhalb desselben Workspaces.

DROP POLICY IF EXISTS inbox_reads_self_read ON public.inbox_reads;
CREATE POLICY inbox_reads_self_read ON public.inbox_reads FOR SELECT
  USING (
    read_by = auth.uid()
    AND public.is_workspace_member(workspace_id, auth.uid())
  );

DROP POLICY IF EXISTS inbox_reads_self_write ON public.inbox_reads;
CREATE POLICY inbox_reads_self_write ON public.inbox_reads FOR ALL
  USING (
    read_by = auth.uid()
    AND public.has_workspace_role(workspace_id, auth.uid(),
        ARRAY['owner','admin','member'])
  )
  WITH CHECK (
    read_by = auth.uid()
    AND public.has_workspace_role(workspace_id, auth.uid(),
        ARRAY['owner','admin','member'])
  );

-- Hinweis: 'viewer' ist bewusst ausgeschlossen — Read-Markieren ist eine
-- aktive Schreib-Aktion und passt nicht zur Read-only-Semantik.

-- ── Bulk-Mark RPC ────────────────────────────────────────────────────────
-- SECURITY DEFINER, weil wir parsed_messages quer-lesen müssen, ohne dass
-- der Caller eine direkte SELECT-Permission auf jede einzelne Row braucht
-- (RLS auf parsed_messages erlaubt zwar SELECT für Member, aber wir wollen
-- den Member-Check zentral hier machen, damit der RPC self-contained ist
-- und Klartext-Fehlermeldung liefert).
--
-- Filter:
--   * status IN ('matched','unclassified','suggested','pending')
--     → 'failed' und 'dismissed' werden NICHT als "ungelesen" gewertet.
--   * received_at >= NOW() - 30d
--     → korrespondiert mit cleanup_inbox_history() (30-Tage-Retention).
--     Hinweis: parsed_messages erlaubt erweiterte Retention (siehe
--     20260507600000 / 20260507700000), aber für den Lese-Status reicht
--     das 30-Tage-Fenster — ältere Einträge werden ohnehin nicht im
--     Inbox-UI angezeigt (siehe inbox_provider).

CREATE OR REPLACE FUNCTION public.mark_all_inbox_read(_workspace_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  inserted_count INTEGER;
BEGIN
  IF _workspace_id IS NULL THEN
    RAISE EXCEPTION 'workspace_id darf nicht NULL sein.';
  END IF;

  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Nicht authentifiziert.';
  END IF;

  IF NOT public.is_workspace_member(_workspace_id, auth.uid()) THEN
    RAISE EXCEPTION 'Keine Berechtigung für Workspace %.', _workspace_id;
  END IF;

  WITH ins AS (
    INSERT INTO public.inbox_reads (workspace_id, parsed_message_id, read_by)
    SELECT pm.workspace_id, pm.id, auth.uid()
      FROM public.parsed_messages pm
     WHERE pm.workspace_id = _workspace_id
       AND pm.status IN ('matched','unclassified','suggested','pending')
       AND pm.received_at >= NOW() - INTERVAL '30 days'
    ON CONFLICT DO NOTHING
    RETURNING 1
  )
  SELECT COUNT(*) INTO inserted_count FROM ins;

  RETURN COALESCE(inserted_count, 0);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_all_inbox_read(UUID) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.mark_all_inbox_read(UUID) TO authenticated;

-- ── Verifikations-Sequenz (manuell, lokal) ───────────────────────────────
-- KEINE Test-Daten in dieser Migration — die folgende Sequenz ist nur
-- Doku, wie ein Migration-Smoke-Test aussehen würde (T11 im Plan).
--
-- Voraussetzung: `supabase db reset` lief grün durch und du bist mit einem
-- authentifizierten User im Studio / per supabase-js eingeloggt, der in
-- mindestens einem Workspace owner/admin/member ist.
--
-- 1) Workspace vorhanden? (z.B. erster User hat durch
--    provision_personal_workspace() einen "Personal"-Workspace.)
--      SELECT id FROM public.workspaces LIMIT 1;
--      -> :ws_id
--
-- 2) Test-Mailbox-Account anlegen (oder vorhandenen nutzen):
--      INSERT INTO public.mailbox_accounts
--        (workspace_id, user_id, label, imap_host, username)
--      VALUES (:ws_id, auth.uid(), 'TestBox', 'imap.example.com', 'tester')
--      RETURNING id;
--      -> :acc_id
--
-- 3) Test-parsed_message einfügen (direkt, da User-RLS keine Inserts
--    erlaubt -- im Studio mit service_role oder per psql lokal):
--      INSERT INTO public.parsed_messages
--        (workspace_id, account_id, message_uid, message_hash,
--         from_address, subject, received_at, status)
--      VALUES (:ws_id, :acc_id, 1, 'hash-1', 'a@b.tld', 'Testmail',
--              NOW(), 'unclassified')
--      RETURNING id;
--      -> :pm_id
--
-- 4) RPC aufrufen (als authentifizierter User, NICHT service_role):
--      SELECT public.mark_all_inbox_read(:ws_id);
--      -> erwartet: 1 (genau ein neuer Read-Eintrag)
--
-- 5) Verify:
--      SELECT * FROM public.inbox_reads
--        WHERE workspace_id = :ws_id AND read_by = auth.uid();
--      -> eine Row mit parsed_message_id = :pm_id
--
-- 6) Idempotenz: zweiter Call:
--      SELECT public.mark_all_inbox_read(:ws_id);
--      -> erwartet: 0 (ON CONFLICT DO NOTHING)
--
-- 7) Cross-Workspace-Schutz:
--      SELECT public.mark_all_inbox_read('00000000-0000-0000-0000-000000000000'::uuid);
--      -> erwartet: ERROR "Keine Berechtigung für Workspace ...".
--
-- 8) CASCADE-Cleanup:
--      DELETE FROM public.parsed_messages WHERE id = :pm_id;
--      SELECT count(*) FROM public.inbox_reads WHERE parsed_message_id = :pm_id;
--      -> erwartet: 0 (durch ON DELETE CASCADE).
--
-- 9) Status-Filter ('failed' und 'dismissed' werden ignoriert): wenn man
--    in Schritt 3 status='failed' setzt, liefert der RPC 0 Inserts.
