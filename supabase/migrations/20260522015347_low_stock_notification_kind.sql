-- Epic D / Task D2 — Low-Stock-Push: notifications_sent für 'low_stock' öffnen.
-- Plan: plans/2026-05-20_warenverwaltung-feature-parity.md
--   §"Low-Stock-Push — nachgeschärft (Committee-Finding 7)"
--   §"Down-Migrations / Reversibilität (Committee-Empfehlung 3)"
--
-- 1) ref_kind-CHECK-Constraint erweitern: 'low_stock' wird zusätzlich erlaubt.
-- 2) Additive, dauerhaft nullable workspace_id-Spalte für Workspace-Scoped-
--    Dedup des low_stock-Alerts. KEINE PK-Änderung (wäre invasiv) — der PK
--    bleibt (user_id, ref_kind, ref_id).
--
-- Referenz-Original: 20260503001000_push_notifications.sql (Zeile 56).
-- Der CHECK ist dort INLINE in CREATE TABLE definiert; Postgres vergibt den
-- Auto-Namen `notifications_sent_ref_kind_check` (verifiziert via pg_constraint).

-- ── 1. ref_kind-CHECK erweitern ─────────────────────────────────────────────
-- ALT: CHECK (ref_kind IN ('mhd','delivery','payment'))
-- NEU: CHECK (ref_kind IN ('mhd','delivery','payment','low_stock'))
ALTER TABLE public.notifications_sent
  DROP CONSTRAINT notifications_sent_ref_kind_check;

ALTER TABLE public.notifications_sent
  ADD CONSTRAINT notifications_sent_ref_kind_check
  CHECK (ref_kind IN ('mhd', 'delivery', 'payment', 'low_stock'));

-- ── 2. workspace_id-Spalte (additiv, nullable) ──────────────────────────────
-- Damit der low_stock-Dedup pro Workspace sauber greift: ein low_stock-Alert
-- aggregiert strikt GROUP BY (workspace_id, product_id) und trägt genau eine
-- workspace_id. Die Spalte ist additiv-nullable — der PK bleibt unverändert
-- (user_id, ref_kind, ref_id), eine PK-Erweiterung wäre invasiv.
ALTER TABLE public.notifications_sent
  ADD COLUMN IF NOT EXISTS workspace_id UUID
  REFERENCES public.workspaces(id) ON DELETE CASCADE;

COMMENT ON COLUMN public.notifications_sent.workspace_id IS
  'Workspace-Scoped-Dedup für ref_kind=''low_stock''-Alerts. Nullable: '
  'bestehende ref_kinds (mhd/delivery/payment) sind user-scoped und lassen '
  'die Spalte leer. Kein PK-Bestandteil (PK bleibt user_id,ref_kind,ref_id).';

-- Index für Workspace-gefilterte Dedup-Lookups des low_stock-Pfads.
CREATE INDEX IF NOT EXISTS notifications_sent_workspace_kind_idx
  ON public.notifications_sent(workspace_id, ref_kind);

-- ── DOWN-Migration (NICHT automatisch ausgeführt — Referenz/Dokumentation) ──
--
-- Der ref_kind-CHECK-Tausch ist laut Plan bewusst als "IRREVERSIBEL AB MERGE"
-- dokumentiert: Sobald produktive 'low_stock'-Rows existieren, würde ein
-- Re-Down des CHECKs (zurück auf 3 Werte) genau diese Rows verletzen und die
-- Migration brechen. Ein sauberer Down ist daher NUR möglich, solange noch
-- keine 'low_stock'-Row geschrieben wurde.
--
-- Der workspace_id-Spalten-Teil ist dagegen sauber reversibel (DROP COLUMN).
--
-- -- (a) workspace_id-Teil — reversibel:
-- DROP INDEX IF EXISTS public.notifications_sent_workspace_kind_idx;
-- ALTER TABLE public.notifications_sent DROP COLUMN IF EXISTS workspace_id;
--
-- -- (b) ref_kind-CHECK-Teil — IRREVERSIBEL, sobald low_stock-Rows existieren.
-- --     Würde mit bestehenden 'low_stock'-Rows fehlschlagen:
-- ALTER TABLE public.notifications_sent
--   DROP CONSTRAINT notifications_sent_ref_kind_check;
-- ALTER TABLE public.notifications_sent
--   ADD CONSTRAINT notifications_sent_ref_kind_check
--   CHECK (ref_kind IN ('mhd', 'delivery', 'payment'));
