-- ─── Auto-Archive-Trigger für tickets ──────────────────────────────────────
--
-- Tickets werden NICHT manuell als "fertig" markiert. Stattdessen leitet
-- die DB den Lifecycle aus den verlinkten Datensätzen ab und schreibt
-- `archived_at` + `archived_reason` automatisch:
--
--   reason = 'all_done'       → alle Deals des Tickets haben status='Done'
--   reason = 'all_shipped'    → alle Deals haben (shipped_at IS NOT NULL
--                               OR status='Done'), aber nicht alle 'Done'
--   reason = 'inventory_sold' → alle inventory_items zum Ticket sind in
--                               Status ('Verkauft','Versandt')
--   reason = 'manual'         → User-Code-Path (nicht hier vergeben)
--
-- Idempotent: ein bereits archiviertes Ticket wird nie erneut beschrieben
-- (`WHERE archived_at IS NULL` im UPDATE schützt zusätzlich gegen Races).
--
-- SECURITY DEFINER + festes search_path:
--   Der Trigger muss `tickets` schreiben dürfen, auch wenn der auslösende
--   User auf der Tabelle nur read-Rechte hat (oder die RLS-Policy gerade
--   einen Edge-Case nicht abdeckt). Wir pinnen `search_path` auf
--   `public, pg_temp`, damit niemand per `SET search_path` eigene
--   Funktionen unterschieben und die SECURITY-DEFINER-Hülle missbrauchen
--   kann (Standard-Härtung).

-- ─── Trigger 1: AFTER UPDATE auf deals ─────────────────────────────────────
--
-- Feuert, wenn `status`, `shipped_at`, `ticket_id` oder `deleted_at`
-- geändert werden. Nur diese Spalten beeinflussen den Lifecycle —
-- alles andere lassen wir bewusst draußen, um Trigger-Overhead bei
-- Routine-Updates (Notiz, Tracking-String, ...) zu vermeiden.

CREATE OR REPLACE FUNCTION public.tg_check_ticket_archive_from_deal()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_ticket_ids BIGINT[];
  v_tid        BIGINT;
  v_archived   TIMESTAMPTZ;
  v_total      INT;
  v_done       INT;
  v_done_or_shipped INT;
  v_reason     TEXT;
BEGIN
  -- Wenn ein Deal von einem Ticket auf ein anderes verschoben wird, müssen
  -- BEIDE Tickets neu bewertet werden — das alte (Deal weg) und das neue
  -- (Deal hinzu). Sonst bleibt Ticket A "fast vollständig" und wird nie
  -- archiviert, obwohl der einzige offene Deal jetzt zu Ticket B gehört.
  v_ticket_ids := ARRAY[]::BIGINT[];
  IF NEW.ticket_id IS NOT NULL THEN
    v_ticket_ids := v_ticket_ids || NEW.ticket_id;
  END IF;
  IF OLD.ticket_id IS NOT NULL
     AND OLD.ticket_id IS DISTINCT FROM NEW.ticket_id THEN
    v_ticket_ids := v_ticket_ids || OLD.ticket_id;
  END IF;

  IF array_length(v_ticket_ids, 1) IS NULL THEN
    RETURN NEW;
  END IF;

  FOREACH v_tid IN ARRAY v_ticket_ids LOOP
    -- Idempotenz-Pre-Check: spart die Aggregation, wenn das Ticket
    -- ohnehin schon abgeschlossen ist.
    SELECT archived_at INTO v_archived
      FROM public.tickets WHERE id = v_tid;
    IF v_archived IS NOT NULL THEN
      CONTINUE;
    END IF;

    -- Lifecycle-Stufen aller (nicht soft-deleted) Deals des Tickets zählen.
    -- Soft-deleted Deals sollen den Abschluss nicht blockieren.
    SELECT COUNT(*),
           COUNT(*) FILTER (WHERE status = 'Done'),
           COUNT(*) FILTER (WHERE status = 'Done' OR shipped_at IS NOT NULL)
      INTO v_total, v_done, v_done_or_shipped
      FROM public.deals
     WHERE ticket_id = v_tid
       AND deleted_at IS NULL;

    -- Edge-Case: Ticket hat (mehr) keine Deals. Nicht archivieren —
    -- "leer" ist nicht dasselbe wie "abgeschlossen".
    IF v_total = 0 THEN
      CONTINUE;
    END IF;

    -- 'all_done' hat Priorität: stärkere Aussage als 'all_shipped'.
    IF v_done = v_total THEN
      v_reason := 'all_done';
    ELSIF v_done_or_shipped = v_total THEN
      v_reason := 'all_shipped';
    ELSE
      CONTINUE;  -- noch offene Deals → noch nicht archivierbar.
    END IF;

    UPDATE public.tickets
       SET archived_at     = NOW(),
           archived_reason = v_reason
     WHERE id = v_tid
       AND archived_at IS NULL;
  END LOOP;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS deals_check_ticket_archive_trg ON public.deals;
CREATE TRIGGER deals_check_ticket_archive_trg
  AFTER UPDATE OF status, shipped_at, ticket_id, deleted_at ON public.deals
  FOR EACH ROW
  EXECUTE FUNCTION public.tg_check_ticket_archive_from_deal();

-- ─── Trigger 2: AFTER UPDATE auf inventory_items ───────────────────────────
--
-- Inventory-Items hängen (noch) nicht per FK an `tickets`, sondern nur
-- per TEXT-Spalte `ticket_number`. Wir resolven das Ticket deshalb über
-- (workspace_id, ticket_number) — der Unique-Index auf der tickets-Tabelle
-- macht das deterministisch. Sobald inventory_items.ticket_id existiert,
-- kann diese Funktion analog zu Trigger 1 vereinfacht werden.

CREATE OR REPLACE FUNCTION public.tg_check_ticket_archive_from_inventory()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_ws        UUID;
  v_tnum      TEXT;
  v_ticket_id BIGINT;
  v_archived  TIMESTAMPTZ;
  v_total     INT;
  v_sold      INT;
BEGIN
  -- COALESCE(NEW, OLD): wenn ticket_number gerade entfernt wurde
  -- (NEW IS NULL), prüfen wir trotzdem das alte Ticket — vielleicht ist
  -- es jetzt komplett, weil dieses Item es bisher offen gehalten hat.
  v_ws   := COALESCE(NEW.workspace_id, OLD.workspace_id);
  v_tnum := COALESCE(NEW.ticket_number, OLD.ticket_number);

  IF v_ws IS NULL OR v_tnum IS NULL OR length(trim(v_tnum)) = 0 THEN
    RETURN NEW;
  END IF;

  SELECT id, archived_at
    INTO v_ticket_id, v_archived
    FROM public.tickets
   WHERE workspace_id  = v_ws
     AND ticket_number = v_tnum;

  -- Kein Ticket-Row vorhanden → nichts zu tun (Item hat eine ticket_number,
  -- aber das Ticket wurde z.B. noch nicht angelegt). Bereits archiviert →
  -- idempotent verlassen.
  IF v_ticket_id IS NULL OR v_archived IS NOT NULL THEN
    RETURN NEW;
  END IF;

  SELECT COUNT(*),
         COUNT(*) FILTER (WHERE status IN ('Verkauft','Versandt'))
    INTO v_total, v_sold
    FROM public.inventory_items
   WHERE workspace_id  = v_ws
     AND ticket_number = v_tnum
     AND deleted_at IS NULL;

  IF v_total = 0 OR v_sold < v_total THEN
    RETURN NEW;
  END IF;

  UPDATE public.tickets
     SET archived_at     = NOW(),
         archived_reason = 'inventory_sold'
   WHERE id = v_ticket_id
     AND archived_at IS NULL;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS inventory_check_ticket_archive_trg ON public.inventory_items;
CREATE TRIGGER inventory_check_ticket_archive_trg
  AFTER UPDATE OF status, ticket_number, workspace_id, deleted_at
  ON public.inventory_items
  FOR EACH ROW
  EXECUTE FUNCTION public.tg_check_ticket_archive_from_inventory();

-- ─── Demo / Manual-Test (auskommentiert, dient als Doku) ───────────────────
--
-- Trigger 1 (Deal-Pfad):
--   begin;
--     -- ws_uuid := <eine existierende workspace_id>
--     insert into public.tickets (workspace_id, ticket_number)
--       values ('<ws_uuid>', 'TRG-DEMO-1') returning id;  -- z.B. id = 42
--     update public.deals set ticket_id = 42 where id in (101, 102);
--     update public.deals set shipped_at = now() where id in (101, 102);
--     -- Erwartung:
--     select archived_at, archived_reason from public.tickets where id = 42;
--     -- → archived_at IS NOT NULL, archived_reason = 'all_shipped'
--   rollback;
--
-- Trigger 2 (Inventory-Pfad):
--   begin;
--     insert into public.tickets (workspace_id, ticket_number)
--       values ('<ws_uuid>', 'TRG-DEMO-2');
--     -- inventory_items mit ticket_number='TRG-DEMO-2' anlegen, dann:
--     update public.inventory_items
--        set status = 'Verkauft'
--      where workspace_id = '<ws_uuid>' and ticket_number = 'TRG-DEMO-2';
--     -- Erwartung:
--     select archived_at, archived_reason from public.tickets
--       where workspace_id = '<ws_uuid>' and ticket_number = 'TRG-DEMO-2';
--     -- → archived_at IS NOT NULL, archived_reason = 'inventory_sold'
--   rollback;
--
-- Idempotenz-Test:
--   Wenn ein Deal des bereits archivierten Tickets erneut auf 'Done' geht,
--   bleibt `archived_at` unverändert (UPDATE-WHERE-Schutz). Lässt sich per
--   `select archived_at` vor und nach einem No-Op-Update verifizieren.
