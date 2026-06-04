-- Security-Fix (Audit 2026-06-04): _carrier_master_key() + get_carrier_api_key()
-- waren nur `REVOKE EXECUTE … FROM PUBLIC` geschützt. Bei Supabase vergibt
-- `pg_default_acl` jeder neuen public-Funktion automatisch ein EXPLIZITES
-- GRANT EXECUTE an anon/authenticated/service_role — ein PUBLIC-Revoke entfernt
-- das NICHT. Folge: jeder eingeloggte User konnte _carrier_master_key() (den
-- Master-Entschlüsselungs-Key ALLER Workspaces) bzw. get_carrier_api_key() per
-- RPC aufrufen → Cross-Tenant-Secret-Exposure. (Gleiche Leak-Klasse, die in
-- 20260603081506 für _edge_config bereits geschlossen wurde.)
--
-- Fix: EXECUTE explizit von anon + authenticated entziehen. service_role
-- (Edge-Functions / Backend) behält Zugriff. Idempotent (REVOKE ist no-op,
-- wenn schon entzogen). Funktioniert auch, wenn eine der Funktionen in einer
-- Umgebung fehlt (DO-Block fängt undefined_function ab).

DO $$
BEGIN
  BEGIN
    REVOKE EXECUTE ON FUNCTION public._carrier_master_key() FROM anon, authenticated;
  EXCEPTION WHEN undefined_function THEN
    RAISE NOTICE '_carrier_master_key() nicht vorhanden — übersprungen';
  END;

  BEGIN
    REVOKE EXECUTE ON FUNCTION public.get_carrier_api_key(uuid, text) FROM anon, authenticated;
  EXCEPTION WHEN undefined_function THEN
    RAISE NOTICE 'get_carrier_api_key(uuid,text) nicht vorhanden — übersprungen';
  END;
END $$;
