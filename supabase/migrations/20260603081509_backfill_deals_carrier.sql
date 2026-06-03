-- T8 (Plan 2026-06-03_tracking_algorithmic_rebuild.md §3.1-Backfill / §5b, R3):
-- Einmaliger, idempotenter Carrier-Backfill für Legacy-Deals.
--
-- Warum: deals.carrier (T1) ist neu. Bestehende Deals haben carrier=NULL.
-- Der Poller liest ADAPTERS[deal.carrier] ?? detectAdapter(tracking) — bei
-- NULL fällt er auf detectAdapter zurück, das bare \d{14} fälschlich auf
-- DHL routen kann (DPD-Kollision, Critique C1-#5/C2-#1). Darum hier ein
-- Backfill aus der Tracking-FORM (Heuristik) — analog detectAdapter im
-- Poller, aber direkt in SQL.
--
-- Backfill-Grenze (Bug-Hunter #6): parsed_messages-Bodies werden nach 30d
-- via cleanup_inbox_history gelöscht → für ältere Deals ist keine
-- Re-Detection aus dem Body mehr möglich. Wir leiten den Carrier daher rein
-- aus der Tracking-Form ab. Trackings, deren Form keiner Branch entspricht
-- (insb. die VAT-Form ^[A-Z]{2}\d{9}$ — exakt 2 Buchstaben + 9 Ziffern),
-- bleiben bewusst carrier=NULL → der Poller fällt für sie auf detectAdapter
-- zurück. Das ist korrekt: eine VAT-IdNr ist kein Tracking und darf nie auf
-- einen Carrier geroutet werden.
--
-- Form-Heuristik (lowercase, passt zum CHECK aus T1):
--   ^TB[ACM]\d{12}$         → amazon  (Amazon Logistics, detection-only)
--   ^05\d{12}$              → dpd     (DPD 14-stellig mit 05-Prefix)
--   ^J[A-Z]{2,3}\d{10,21}$  → dhl     (DHL JJD/JVGL)
--   ^[A-Z]{2}\d{9}[A-Z]{2}$ → dhl     (DHL S10, 2L+9D+2L = 13 Zeichen)
--   ^\d{20}$                → dhl     (DHL 20-stellige Sendungsnummer)
--   ^\d{12,14}$             → dhl     (DHL Identcode/Leitcode-Form)
-- Die VAT-Form ^[A-Z]{2}\d{9}$ matcht KEINE Branch → bleibt NULL (korrekt).
--
-- Idempotenz: WHERE carrier IS NULL → ein zweiter Run lässt bereits
-- gesetzte Werte unberührt; ELSE carrier behält den bestehenden (NULL)
-- Wert, falls keine Form-Branch greift.
--
-- Trigger-Hinweis: deals_enqueue_tracking_poll_trg ist AFTER UPDATE OF
-- tracking — dieser UPDATE schreibt NUR carrier, nicht tracking → der
-- Trigger feuert NICHT (kein Backfill-Poll-Sturm). Verifiziert gegen die
-- Trigger-Definition in 20260603081506_tracking_poll_event_trigger.sql.

UPDATE public.deals
   SET carrier = CASE
         WHEN tracking ~ '^TB[ACM][0-9]{12}$'           THEN 'amazon'
         WHEN tracking ~ '^05[0-9]{12}$'                THEN 'dpd'
         WHEN tracking ~ '^J[A-Z]{2,3}[0-9]{10,21}$'    THEN 'dhl'
         WHEN tracking ~ '^[A-Z]{2}[0-9]{9}[A-Z]{2}$'   THEN 'dhl'
         WHEN tracking ~ '^[0-9]{20}$'                  THEN 'dhl'
         WHEN tracking ~ '^[0-9]{12,14}$'               THEN 'dhl'
         ELSE carrier
       END
 WHERE carrier IS NULL
   AND tracking IS NOT NULL;
