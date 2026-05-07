-- ─── tickets-Tabelle + RLS + Backfill aus deals.ticket_number ────────────
--
-- Bisher leben Tickets nur als TEXT-Spalte `deals.ticket_number`. Sobald
-- wir Lifecycle (archiviert / aktiv) und Audit (wer archiviert wann mit
-- welchem Grund) brauchen, skaliert das nicht. Diese Migration legt eine
-- echte `tickets`-Tabelle an, sichert sie per Workspace-RLS ab und
-- backfillt sie aus existierenden Deals. Die Folge-Migration
-- `20260509000100_deals_ticket_id_fk.sql` knüpft Deals dann per
-- `ticket_id` an diese Tabelle.
--
-- RLS-Pattern analog zu `20260504000500_data_workspace_scope.sql`:
--   read  = jedes Workspace-Mitglied (`is_workspace_member`)
--   write = owner/admin/member (`has_workspace_role`)

CREATE TABLE IF NOT EXISTS public.tickets (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  workspace_id    UUID NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
  ticket_number   TEXT NOT NULL,
  archived_at     TIMESTAMPTZ,
  archived_reason TEXT CHECK (archived_reason IN
    ('all_shipped','all_done','inventory_sold','manual')),
  archived_by     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (workspace_id, ticket_number),
  -- archived_at und archived_reason müssen zusammen gesetzt sein —
  -- sonst entsteht ein "halb-archiviert"-Zustand ohne Audit-Grund.
  CONSTRAINT tickets_archived_pair_chk
    CHECK ((archived_at IS NULL) = (archived_reason IS NULL))
);

CREATE INDEX IF NOT EXISTS tickets_workspace_archived_idx
  ON public.tickets(workspace_id, archived_at);

ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tickets_ws_read   ON public.tickets;
DROP POLICY IF EXISTS tickets_ws_insert ON public.tickets;
DROP POLICY IF EXISTS tickets_ws_update ON public.tickets;
DROP POLICY IF EXISTS tickets_ws_delete ON public.tickets;

CREATE POLICY tickets_ws_read ON public.tickets FOR SELECT
  USING (public.is_workspace_member(workspace_id, auth.uid()));

CREATE POLICY tickets_ws_insert ON public.tickets FOR INSERT
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));

CREATE POLICY tickets_ws_update ON public.tickets FOR UPDATE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']))
  WITH CHECK (public.has_workspace_role(workspace_id, auth.uid(),
              ARRAY['owner','admin','member']));

CREATE POLICY tickets_ws_delete ON public.tickets FOR DELETE
  USING (public.has_workspace_role(workspace_id, auth.uid(),
         ARRAY['owner','admin','member']));

-- ─── Backfill ────────────────────────────────────────────────────────────
-- Pro distinct (workspace_id, ticket_number) genau ein Ticket-Row.
-- Whitespace-only und NULL-Werte filtern wir raus, sonst entstünden
-- "Geister-Tickets" ohne Nummer. `created_at` erbt die früheste Zeit aus
-- den Deals, damit die Reihenfolge in Listen plausibel bleibt.

INSERT INTO public.tickets (workspace_id, ticket_number, created_at)
SELECT d.workspace_id,
       d.ticket_number,
       MIN(d.created_at) AS created_at
  FROM public.deals d
 WHERE d.ticket_number IS NOT NULL
   AND length(trim(d.ticket_number)) > 0
 GROUP BY d.workspace_id, d.ticket_number
ON CONFLICT (workspace_id, ticket_number) DO NOTHING;
