-- T5 (Plan 2026-06-03_tracking_algorithmic_rebuild.md §3.3 / §4 / §5b):
-- Event-Trigger "Poll sofort bei (erstem) Tracking" + Edge-Config-Infra.
--
-- Mechanismus (Plan §3.3): ein AFTER-Trigger auf public.deals feuert bei
-- Erst-Zuweisung ODER echter Änderung von deals.tracking einen
-- net.http_post an die tracking-poll-Edge-Function (single-deal-Pfad,
-- {deal_id}). Das ist der EINZIGE source-agnostische Chokepoint (Inbox-
-- Auto-Assign, manuelle Eingabe, Re-Parse — alle schreiben am Ende
-- deals.tracking). Der Single-Deal-Pfad umgeht den Hour-Guard (kein
-- daily-sweep) und nutzt den isCron-Pfad (Bearer CRON_SECRET) der
-- Edge-Function → kein verify_jwt-401 (config.toml: verify_jwt=false).
--
-- Sicherheits-Muster (gespiegelt aus 20260508000000_workspace_carrier_
-- credentials.sql + 20260516000000_carrier_master_key_bootstrap.sql):
-- Vault + SECURITY DEFINER + REVOKE. Sensible Secrets liegen NUR im Vault,
-- nie als Klartext-Row.
--
-- Idempotenz: alle DDL via IF NOT EXISTS / CREATE OR REPLACE / DROP …
-- IF EXISTS; Vault-Reads in BEGIN/EXCEPTION → grün auf Vault-/pg_net-losem
-- Lokal-Stack (supabase db reset).

-- ─── private-Schema + edge_config-Tabelle ────────────────────────────────
-- Trägt nicht-sensible Edge-Function-Config (z.B. tracking_poll_url). Der
-- sensible cron_secret liegt NICHT hier, sondern ausschließlich im Vault
-- (siehe public._edge_config unten). RLS ist enabled mit 0 Policies →
-- default-deny: keine Rolle kommt via PostgREST/SQL an die Rows (außer
-- SECURITY-DEFINER-Funktionen mit owner-Rechten).
CREATE SCHEMA IF NOT EXISTS private;

CREATE TABLE IF NOT EXISTS private.edge_config (
  key        text        PRIMARY KEY,
  value      text        NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE private.edge_config ENABLE ROW LEVEL SECURITY;
-- Bewusst KEINE Policies → default-deny. Zugriff nur über die
-- SECURITY-DEFINER-Funktion public._edge_config() (läuft als owner).

-- [Council-Fix Security] Default-deny zusätzlich auf GRANT-Ebene härten:
-- weder anon noch authenticated dürfen das private-Schema betreten oder
-- seine Tabellen lesen. RLS allein reicht, aber Defense-in-Depth.
REVOKE ALL ON private.edge_config FROM PUBLIC;
REVOKE ALL ON private.edge_config FROM anon, authenticated;
REVOKE USAGE ON SCHEMA private FROM anon, authenticated;
REVOKE ALL ON ALL TABLES IN SCHEMA private FROM anon, authenticated;
-- Auch künftig neu angelegte Objekte im private-Schema bleiben gesperrt.
ALTER DEFAULT PRIVILEGES IN SCHEMA private REVOKE ALL ON TABLES FROM anon, authenticated;

-- ┌────────────────────────────────────────────────────────────────────┐
-- │ SICHERHEITS-WARNUNG:                                                 │
-- │   Das Schema `private` NIEMALS zur PostgREST-Konfiguration           │
-- │   `db-schemas` (exposed schemas) hinzufügen. Es enthält Edge-        │
-- │   Function-Config, die keine Client-Rolle je sehen darf. Exposed     │
-- │   bleiben ausschließlich `public` (+ ggf. `graphql_public`).         │
-- └────────────────────────────────────────────────────────────────────┘

-- ─── _edge_config(): SECURITY-DEFINER-Reader ─────────────────────────────
-- Liefert einen Config-Wert. Sensible Keys (cron_secret) kommen
-- [Council-Fix] AUSSCHLIESSLICH aus dem Vault — KEIN Table-/GUC-Fallback,
-- sonst landete der Secret als Klartext-Row in private.edge_config (in
-- DB-Backups lesbar, schwächer als Vault). Nicht-sensible Keys
-- (tracking_poll_url) dürfen den Fallback-Pfad Table → GUC nutzen.
--
-- Internes Key-Mapping: aufrufseitig 'cron_secret' → Vault-Secret-Name
-- 'edge_cron_secret' (Naming-Konvention, Plan §7 Setup-Schritt B).
--
-- STABLE: liest nur, mutiert nichts. SECURITY DEFINER: läuft als
-- Migrations-Owner, kommt damit an private.edge_config + vault vorbei an
-- RLS/REVOKE. Vault-Read in BEGIN/EXCEPTION → raised NIE (Vault fehlt
-- lokal) → NULL, Trigger skippt dann den Enqueue (kein harter Fehler).
CREATE OR REPLACE FUNCTION public._edge_config(_key text)
RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, private, vault
AS $$
DECLARE
  v text;
BEGIN
  -- ── Sensible Keys: NUR Vault, kein Fallback. ──
  IF _key = 'cron_secret' THEN
    BEGIN
      SELECT decrypted_secret
        INTO v
        FROM vault.decrypted_secrets
       WHERE name = 'edge_cron_secret'
       LIMIT 1;
    EXCEPTION WHEN OTHERS THEN
      v := NULL;   -- Vault fehlt/loswert → NULL (Trigger skippt Enqueue)
    END;
    IF v IS NULL OR length(v) = 0 THEN
      RETURN NULL;
    END IF;
    RETURN v;
  END IF;

  -- ── Nicht-sensible Keys: Table-Fallback, dann GUC-Fallback. ──
  BEGIN
    SELECT value INTO v FROM private.edge_config WHERE key = _key LIMIT 1;
  EXCEPTION WHEN OTHERS THEN
    v := NULL;
  END;
  IF v IS NOT NULL AND length(v) > 0 THEN
    RETURN v;
  END IF;

  -- GUC-Fallback (z.B. lokale Tests via ALTER DATABASE … SET app.<key>).
  v := current_setting('app.' || _key, true);
  IF v IS NOT NULL AND length(v) > 0 THEN
    RETURN v;
  END IF;

  RETURN NULL;
END;
$$;

-- [Council-Fix Security] PFLICHT: weder PUBLIC noch anon/authenticated dürfen
-- _edge_config per RPC callen (sonst Secret-Abgriff via _edge_config('cron_secret')).
-- WICHTIG: REVOKE … FROM PUBLIC allein reicht NICHT. Supabase setzt via
-- pg_default_acl (Owner postgres/supabase_admin im public-Schema) für JEDE neu
-- angelegte public-Funktion automatisch ein EXPLIZITES `GRANT EXECUTE TO anon,
-- authenticated, service_role`. Diese expliziten Role-Grants werden von einem
-- REVOKE … FROM PUBLIC NICHT entfernt (verifiziert via pg_proc.proacl). Darum
-- zusätzlich explizit von anon + authenticated revoken — sonst kann
-- authenticated den Vault-cron_secret per RPC abgreifen (§6 Security-Gate).
-- service_role behält EXECUTE (Backend-Pfad), aber das Trigger-Enqueue läuft
-- ohnehin SECURITY DEFINER, nicht über service_role-RPC.
REVOKE EXECUTE ON FUNCTION public._edge_config(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public._edge_config(text) FROM anon, authenticated;

-- ─── set_suppress_tracking_poll(): Bulk-Drossel-Einhängepunkt ────────────
-- [Council-Fix] Vorsorge für künftige Bulk-Re-Parse-Drosselung: setzt das
-- transaktionslokale GUC app.suppress_tracking_poll='on'. Der Trigger
-- (deals_enqueue_tracking_poll) prüft dieses GUC und skippt den Sofort-
-- Enqueue; dann übernimmt der Daily-Sweep statt N Einzel-Polls.
--
-- Heute schreibt der Re-Parse-Pfad deals.tracking gar nicht direkt (T3),
-- das Flood-Risiko ist also niedrig — das RPC ist reine Vorsorge.
-- SET LOCAL gilt nur bis Transaktions-Ende; daher MUSS der Aufrufer es in
-- derselben Transaktion wie die Bulk-UPDATEs ausführen.
CREATE OR REPLACE FUNCTION public.set_suppress_tracking_poll()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- transaktionslokal: kein Effekt über die aufrufende Transaktion hinaus
  PERFORM set_config('app.suppress_tracking_poll', 'on', true);
END;
$$;

-- Nur service_role (Backend / Re-Parse-Pfad) darf die Bulk-Drossel setzen.
-- anon/authenticated explizit revoken (Supabase-Default-Grant entfernen),
-- service_role explizit granten.
REVOKE EXECUTE ON FUNCTION public.set_suppress_tracking_poll() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.set_suppress_tracking_poll() FROM anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.set_suppress_tracking_poll() TO service_role;

-- ─── deals_enqueue_tracking_poll(): Trigger-Funktion ─────────────────────
-- Feuert net.http_post an tracking-poll bei Erst-Zuweisung / echter
-- Änderung von deals.tracking (Plan §3.3, exakter Body).
--
-- KEIN live_status_updated_at-Stempel hier (Bug-Hunter #3): ein Stempel
-- würde den 30s-Retrack-Cooldown auch für DIESEN enqueued Single-Deal-Poll
-- auslösen und ihn selbst blocken. Der seltene Doppel-Poll (Trigger +
-- gleichzeitiger manueller Retrack) ist benign (idempotenter Carrier-Read;
-- ein evtl. 429 wird Client-seitig als RetrackResult.rateLimited
-- geschluckt).
CREATE OR REPLACE FUNCTION public.deals_enqueue_tracking_poll()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, net, vault, extensions
AS $$
DECLARE
  v_url    text;
  v_secret text;
BEGIN
  -- Kein Tracking → nichts zu pollen.
  IF NEW.tracking IS NULL OR btrim(NEW.tracking) = '' THEN
    RETURN NEW;
  END IF;

  -- Unveränderter Tracking-Wert (Status-/Note-Edit) → kein Enqueue.
  IF TG_OP = 'UPDATE' AND NOT (NEW.tracking IS DISTINCT FROM OLD.tracking) THEN
    RETURN NEW;
  END IF;

  -- [Council-Fix] Bulk-Re-Parse-Drossel: "Sendungsnummern neu prüfen" über
  -- N Deals würde sonst N Sofort-Polls auslösen. Der Re-Parse-Pfad setzt in
  -- seiner Transaktion SET LOCAL app.suppress_tracking_poll='on' (via
  -- public.set_suppress_tracking_poll()); dann übernimmt der Daily-Sweep.
  IF current_setting('app.suppress_tracking_poll', true) = 'on' THEN
    RETURN NEW;
  END IF;

  v_url    := public._edge_config('tracking_poll_url');
  v_secret := public._edge_config('cron_secret');

  -- Edge-Config unvollständig (z.B. frisch resettete DB ohne Vault-Secret):
  -- Detection/Speicherung ist schon passiert; der Daily-Sweep zieht den
  -- Live-Status nach. KEIN net.http_post.
  IF v_url IS NULL OR v_secret IS NULL THEN
    RAISE NOTICE 'tracking-poll enqueue skipped (edge config missing) deal %', NEW.id;
    RETURN NEW;
  END IF;

  -- net.http_post in BEGIN/EXCEPTION (LOAD-BEARING): ein Fehler hier
  -- (pg_net nicht installiert, Netz-Timeout, …) darf den Deal-Write NIE
  -- rollbacken. Das Tracking ist bereits gespeichert; der Daily-Sweep
  -- holt den Live-Status nach.
  BEGIN
    PERFORM net.http_post(
      url     := v_url,
      headers := jsonb_build_object(
                   'Authorization', 'Bearer ' || v_secret,
                   'Content-Type',  'application/json'),
      body    := jsonb_build_object('deal_id', NEW.id),  -- single-deal → kein Hour-Guard
      timeout_milliseconds := 60000);
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'net.http_post failed for deal %: %', NEW.id, SQLERRM;
  END;

  RETURN NEW;
END;
$$;

-- [Council-Fix Security] kein direkter RPC-Aufruf durch Clients (würde sonst
-- net.http_post mit beliebiger NEW-Row triggern). Zusätzlich zu PUBLIC auch die
-- expliziten Supabase-Default-Grants (anon/authenticated) revoken.
REVOKE EXECUTE ON FUNCTION public.deals_enqueue_tracking_poll() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.deals_enqueue_tracking_poll() FROM anon, authenticated;

-- ─── Trigger ─────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS deals_enqueue_tracking_poll_trg ON public.deals;
CREATE TRIGGER deals_enqueue_tracking_poll_trg
  AFTER INSERT OR UPDATE OF tracking ON public.deals
  FOR EACH ROW EXECUTE FUNCTION public.deals_enqueue_tracking_poll();

-- ─── Idempotenter Vault-NOTICE-Bootstrap ─────────────────────────────────
-- Anders als der carrier_master_key (auto-bootstrapped mit random bytes)
-- wird edge_cron_secret NICHT auto-generiert: er MUSS exakt dem CRON_SECRET
-- der Edge-Function entsprechen (Plan §7 Setup-Schritt B,
-- vault.create_secret('<CRON_SECRET>','edge_cron_secret', …)). Hier nur ein
-- NOTICE, falls er fehlt — kein Abbruch, db reset bleibt grün.
DO $$
DECLARE
  existing_count integer;
BEGIN
  BEGIN
    SELECT count(*)
      INTO existing_count
      FROM vault.secrets
     WHERE name = 'edge_cron_secret';

    IF existing_count >= 1 THEN
      RAISE NOTICE 'Vault-Secret edge_cron_secret vorhanden (count=%), Event-Trigger aktiv.', existing_count;
    ELSE
      RAISE NOTICE 'Vault-Secret edge_cron_secret FEHLT — Event-Trigger enqueued nichts, bis es gesetzt ist (Setup §7-B: vault.create_secret(<CRON_SECRET>, ''edge_cron_secret'', …)).';
    END IF;
  EXCEPTION
    WHEN invalid_schema_name THEN
      RAISE NOTICE 'Vault-Schema fehlt (lokaler Stack ohne Supabase-Vault) — Event-Trigger skippt Enqueue, bis edge_cron_secret gesetzt ist.';
    WHEN undefined_table THEN
      RAISE NOTICE 'vault.secrets-Tabelle fehlt (Vault nicht installiert) — Event-Trigger skippt Enqueue, bis edge_cron_secret gesetzt ist.';
    WHEN undefined_function THEN
      RAISE NOTICE 'vault-Funktionen fehlen (Vault nicht installiert) — Event-Trigger skippt Enqueue, bis edge_cron_secret gesetzt ist.';
  END;
END
$$;
