-- ─── Task C4: Atomares Increment von quantity_received via SECURITY-DEFINER-RPC
--
-- Plan: plans/2026-05-20_warenverwaltung-feature-parity.md
--       Abschnitt "PO-Wareneingang — atomar (Committee-Finding 12)"
--       + Risiko 7 (Race auf quantity_received)
--
-- Warum RPC statt direktem UPDATE:
--   Der Supabase-Dart-Client erlaubt nur literal values in `.update({...})`.
--   Ein serverseitiges `quantity_received = quantity_received + x` ist über
--   den REST-Client nicht möglich — dafür muss eine RPC genutzt werden.
--   Diese RPC ist die einzige sichere Art, das atomare Increment (ohne
--   Read-modify-write) von Dart aus durchzuführen.
--
-- Sicherheitsdesign (per CLAUDE.md + Plan Security-Finding):
--   * SECURITY DEFINER — damit die RPC `purchase_order_items` schreiben
--     kann, ohne eine UPDATE-Policy für den User vorauszusetzen (der
--     Status-Trigger auf der Tabelle braucht SECURITY DEFINER für das
--     übergeordnete `purchase_orders`-Update — hier analog).
--   * SET search_path = public, pg_temp — Pflicht-Härtung.
--   * has_workspace_role-Check (Write-Level) im Body — der aufrufende
--     User muss owner/admin/member des Workspaces sein, dem die Position
--     gehört. Konsistent zur UPDATE-Policy von `purchase_order_items`:
--     da diese RPC SECURITY DEFINER ist, würde ein reiner Read-Level-
--     Check (is_workspace_member) die Write-Policy der Tabelle umgehen
--     und einem `viewer` einen Schreibzugriff erlauben.
--   * Über-Buchungs-Schranke im Body — quantity_received + p_qty darf
--     quantity_ordered nicht überschreiten (Schutz gegen direkte
--     RPC-Calls am UI-Stepper vorbei).
--   * GRANT EXECUTE NUR an `authenticated` (kein `anon`, kein `public`).
--
-- Die RPC macht:
--   UPDATE purchase_order_items
--      SET quantity_received = quantity_received + p_qty
--    WHERE id = p_item_id
--   und gibt die aktualisierte Row zurück.
--   Der Status-Trigger `purchase_order_items_status_trg` (angelegt in
--   20260522010918_purchase_orders.sql) feuert auf dieses UPDATE automatisch
--   und pflegt `purchase_orders.status` (partially_received / received).
--   Die App setzt den Status NICHT manuell.

CREATE OR REPLACE FUNCTION public.increment_po_item_received(
  p_item_id UUID,
  p_qty     INTEGER
)
RETURNS SETOF public.purchase_order_items
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_workspace_id     UUID;
  v_quantity_ordered  INTEGER;
  v_quantity_received INTEGER;
BEGIN
  -- 1. Workspace + Mengen der Position lesen (Workspace für Rollen-Check,
  --    Mengen für die Über-Buchungs-Schranke).
  SELECT workspace_id, quantity_ordered, quantity_received
    INTO v_workspace_id, v_quantity_ordered, v_quantity_received
    FROM public.purchase_order_items
   WHERE id = p_item_id
     AND deleted_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'purchase_order_item not found or deleted: %', p_item_id;
  END IF;

  -- 2. Rollen-Check (Write-Level): der aufrufende User muss owner/admin/
  --    member des Workspaces sein. Konsistent zur UPDATE-Policy von
  --    purchase_order_items — eine SECURITY-DEFINER-RPC darf die
  --    Write-Policy der Tabelle nicht aushebeln.
  IF NOT public.has_workspace_role(
           v_workspace_id, auth.uid(), ARRAY['owner','admin','member']) THEN
    RAISE EXCEPTION 'not a workspace member';
  END IF;

  -- 3. Mengenpüfung: p_qty muss positiv sein.
  IF p_qty <= 0 THEN
    RAISE EXCEPTION 'p_qty must be > 0, got %', p_qty;
  END IF;

  -- 3b. Über-Buchungs-Schranke: der Wareneingang darf die bestellte
  --     Menge nicht überschreiten. Schützt vor direkten RPC-Calls am
  --     UI-Stepper (der bereits clientseitig clamped) vorbei.
  IF v_quantity_received + p_qty > v_quantity_ordered THEN
    RAISE EXCEPTION 'goods receipt exceeds ordered quantity (received % + % > ordered %)',
      v_quantity_received, p_qty, v_quantity_ordered;
  END IF;

  -- 4. Atomares Increment — ein einziges UPDATE, kein Read-modify-write.
  --    Der Touch-Trigger (trg_touch_purchase_order_items) pflegt updated_at/
  --    version. Der Status-Trigger (purchase_order_items_status_trg) pflegt
  --    purchase_orders.status automatisch.
  UPDATE public.purchase_order_items
     SET quantity_received = quantity_received + p_qty
   WHERE id = p_item_id
     AND deleted_at IS NULL;

  -- 5. Aktualisierte Row zurückgeben.
  RETURN QUERY
    SELECT *
      FROM public.purchase_order_items
     WHERE id = p_item_id;
END;
$$;

-- Rechte: nur authentifizierte User dürfen die RPC aufrufen.
-- Der Rollen-Check (has_workspace_role, Write-Level) im Body stellt
-- sicher, dass nur owner/admin/member tatsächlich Daten verändern können.
REVOKE ALL ON FUNCTION public.increment_po_item_received(UUID, INTEGER)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.increment_po_item_received(UUID, INTEGER)
  TO authenticated;

-- ─── DOWN-Migration (kommentiert) ────────────────────────────────────────────
-- Zum Zurückrollen:
--   DROP FUNCTION IF EXISTS
--     public.increment_po_item_received(UUID, INTEGER);
