-- T5 (Plan 2026-05-13_strict_tracking_extraction.md): Strict-Tracking-Schema.
-- Adds tracking_confidence + tracking_needs_review columns,
-- mailbox_accounts.last_reparse_at, index for review-filter,
-- one-time re-classification (skip 'manual' confidence).
--
-- RLS-Hinweis: Geerbte Workspace-UPDATE-Policies aus
-- 20260504000500_data_workspace_scope.sql decken deals.tracking_confidence /
-- tracking_needs_review automatisch ab (PG-RLS arbeitet auf Row-Granularität,
-- nicht Column-Granularität). pending_deal_suggestions ist service_role-only
-- (siehe 20260507000000_inbox.sql) — Client schreibt das Feld NIE direkt.
-- Kein neuer Policy-Block notwendig.

-- 1) deals: tracking_confidence + tracking_needs_review
ALTER TABLE public.deals
  ADD COLUMN IF NOT EXISTS tracking_confidence text
    CHECK (tracking_confidence IN ('strong', 'manual', 'none'));

ALTER TABLE public.deals
  ADD COLUMN IF NOT EXISTS tracking_needs_review boolean
    NOT NULL DEFAULT false;

-- 2) pending_deal_suggestions: tracking_confidence (only strong | none)
ALTER TABLE public.pending_deal_suggestions
  ADD COLUMN IF NOT EXISTS tracking_confidence text
    CHECK (tracking_confidence IN ('strong', 'none'));

-- 3) mailbox_accounts: last_reparse_at (rate-limit for re-parse trigger)
ALTER TABLE public.mailbox_accounts
  ADD COLUMN IF NOT EXISTS last_reparse_at timestamptz;

-- 4) Index for "needs review" filter on deals
CREATE INDEX IF NOT EXISTS deals_needs_tracking_review_idx
  ON public.deals (workspace_id, tracking_needs_review)
  WHERE tracking_needs_review = true;

-- 5) ONE-TIME Re-Klassifizierung (Pre-Launch — Council-Finding #5 Mitigation):
--    Alle existierenden Trackings als 'needs_review' markieren.
--    OUTER guard:
--      - NUR wenn tracking_confidence noch NULL ist (idempotency)
--      - UND tracking_confidence ist NICHT 'manual' (User-Eingaben respektieren)
UPDATE public.deals
SET tracking_needs_review = true,
    tracking_confidence = 'none'
WHERE tracking IS NOT NULL
  AND tracking <> ''
  AND tracking_confidence IS NULL
  AND COALESCE(tracking_confidence, '') <> 'manual';

-- 6) Audit / Comment for posterity
COMMENT ON COLUMN public.deals.tracking_confidence IS
  'T5/2026-05-13: confidence of tracking extraction. strong=validated carrier+pattern, manual=user-typed, none=unknown/needs review';
COMMENT ON COLUMN public.deals.tracking_needs_review IS
  'T5/2026-05-13: true when tracking was set by an older (weak) detection. Filter for review UI.';
COMMENT ON COLUMN public.mailbox_accounts.last_reparse_at IS
  'T5/2026-05-13: timestamp of last user-triggered re-parse (rate-limit, 5 min cooldown).';
