-- Sprint 6 Follow-up: persistente Dismiss-Liste pro Workspace.
--
-- Bisheriges Verhalten: "Verwerfen" markiert eine pending_deal_suggestions-
-- Zeile als resolved. Sobald aber eine NEUE Mail zur selben Bestellung
-- reinkommt (z.B. Update "Paket zugestellt"), legt inbox-parse eine neue
-- Suggestion an — die landet wieder im UI, obwohl der User sie schon
-- weggewischt hat.
--
-- Lösung: stabile Dismiss-Identität pro (workspace, shop_key, order_id).
-- Wenn die Bestellung keine order_id hat (selten, aber möglich z.B. bei
-- x-kom-Versand-Mails), nehmen wir die parsed_message_id als Fallback.
--
-- `received_at` bleibt am Eintrag, damit der Cleanup-Job alte Dismissals
-- gemeinsam mit den zugehörigen parsed_messages entsorgt (100 Tage).

CREATE TABLE IF NOT EXISTS public.inbox_dismissals (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id      UUID NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
  shop_key          TEXT,
  order_id          TEXT,
  parsed_message_id UUID REFERENCES public.parsed_messages(id) ON DELETE CASCADE,
  received_at       TIMESTAMPTZ NOT NULL,
  dismissed_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT inbox_dismissals_key_check CHECK (
    (shop_key IS NOT NULL AND order_id IS NOT NULL)
    OR parsed_message_id IS NOT NULL
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS inbox_dismissals_order_uniq
  ON public.inbox_dismissals(workspace_id, shop_key, order_id)
  WHERE shop_key IS NOT NULL AND order_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS inbox_dismissals_msg_uniq
  ON public.inbox_dismissals(workspace_id, parsed_message_id)
  WHERE parsed_message_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS inbox_dismissals_ws_idx
  ON public.inbox_dismissals(workspace_id, received_at DESC);

ALTER TABLE public.inbox_dismissals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS inbox_dismissals_ws_read ON public.inbox_dismissals;
CREATE POLICY inbox_dismissals_ws_read ON public.inbox_dismissals FOR SELECT
  USING (public.is_workspace_member(workspace_id, auth.uid()));

DROP POLICY IF EXISTS inbox_dismissals_ws_write ON public.inbox_dismissals;
CREATE POLICY inbox_dismissals_ws_write ON public.inbox_dismissals FOR ALL
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']))
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));

-- Cleanup-Hook erweitern: Dismissals deren Mail-Datum älter als die
-- DB-Retention ist, fliegen mit raus. Ergänzt die parsed_messages /
-- pending_deal_suggestions-Cleanups (siehe 20260507000000 / _retention_100).
CREATE OR REPLACE FUNCTION public.cleanup_inbox_history()
RETURNS VOID LANGUAGE sql AS $$
  DELETE FROM public.parsed_messages
   WHERE created_at < NOW() - INTERVAL '100 days';

  DELETE FROM public.pending_deal_suggestions
   WHERE created_at < NOW() - INTERVAL '100 days'
     AND resolved_at IS NULL;

  DELETE FROM public.inbox_dismissals
   WHERE received_at < NOW() - INTERVAL '100 days';
$$;
