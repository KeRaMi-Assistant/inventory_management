-- ─── deals.ticket_id FK auf tickets + Backfill + Sync-Trigger ─────────────
--
-- Verknüpft jeden Deal mit einem Row in der neuen `tickets`-Tabelle. Die
-- alte TEXT-Spalte `deals.ticket_number` bleibt erhalten, damit
-- existierender Lese-Code (Provider, Listen, Reports) ohne Änderung
-- weiterläuft — sie wird ab jetzt per Trigger aus `tickets.ticket_number`
-- gespiegelt (Postgres erlaubt keine echten GENERATED-ALWAYS-Spalten, die
-- auf andere Tabellen referenzieren, also approximieren wir das
-- Verhalten via Trigger).
--
-- ON DELETE SET NULL: Tickets werden in der Regel per `archived_at` weich
-- entfernt. Falls doch ein hartes DELETE durchläuft, soll der Deal nicht
-- mit-gelöscht werden — wir setzen nur den FK auf NULL.

ALTER TABLE public.deals
  ADD COLUMN IF NOT EXISTS ticket_id BIGINT
  REFERENCES public.tickets(id) ON DELETE SET NULL;

-- Backfill: jeden Deal mit Ticket-Nummer auf den passenden tickets-Row
-- mappen. Voraussetzung: die vorherige Migration hat genau ein Ticket pro
-- (workspace_id, ticket_number) angelegt — der Join ist deterministisch.
UPDATE public.deals d
   SET ticket_id = t.id
  FROM public.tickets t
 WHERE d.workspace_id  = t.workspace_id
   AND d.ticket_number = t.ticket_number
   AND d.ticket_id IS NULL;

CREATE INDEX IF NOT EXISTS deals_ticket_id_idx
  ON public.deals(ticket_id) WHERE ticket_id IS NOT NULL;

-- ─── Sync-Trigger: deals.ticket_number aus tickets gespiegelt ────────────
--
-- Sobald `ticket_id` gesetzt oder geändert wird, wird `ticket_number`
-- aus der referenzierten Ticket-Zeile aufgefüllt. Bleibt `ticket_id`
-- NULL (Deal ohne Ticket), bleibt `ticket_number` unverändert — die
-- Anwendung kann inkrementell auf `ticket_id` migrieren ohne die alte
-- Schreibebene aufzugeben.

CREATE OR REPLACE FUNCTION public.deals_sync_ticket_number()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.ticket_id IS NOT NULL THEN
    -- Tenant-Isolation: das verlinkte Ticket MUSS im selben Workspace
    -- liegen. FKs respektieren keine RLS, deshalb erzwingen wir den
    -- Workspace-Match explizit hier — verhindert dangling Cross-Tenant-
    -- Referenzen, falls jemand eine fremde ticket_id reinschreibt.
    SELECT t.ticket_number
      INTO NEW.ticket_number
      FROM public.tickets t
     WHERE t.id = NEW.ticket_id
       AND t.workspace_id = NEW.workspace_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION
        'ticket_id % does not belong to deal workspace %',
        NEW.ticket_id, NEW.workspace_id
        USING ERRCODE = '23514';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS deals_sync_ticket_number_trg ON public.deals;
CREATE TRIGGER deals_sync_ticket_number_trg
  BEFORE INSERT OR UPDATE OF ticket_id ON public.deals
  FOR EACH ROW EXECUTE FUNCTION public.deals_sync_ticket_number();
