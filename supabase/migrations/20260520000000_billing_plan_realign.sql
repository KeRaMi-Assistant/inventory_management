-- ─── T0: Billing-Plan-Realign — 6-Tier-Schema (Blocker 1) ────────────────
--
-- Vorgeschichte:
--   * 20260504000300_billing_profiles.sql:20  setzt CHECK auf
--     ('free','starter','pro','business','enterprise').
--   * 20260507500000_subscription_overhaul.sql:21 ersetzt 'enterprise'
--     durch 'ultimate' → CHECK = ('free','starter','pro','business','ultimate').
--   * lib/models/billing_profile.dart:10-43 erwartet aber das neue 6-Tier-
--     Schema: free | solo | solo_pro | team | business | enterprise.
--
-- Heute ist der Dart-Code nicht in der Lage, einen 'solo'-Plan in die DB
-- zu schreiben — der CHECK lehnt ab. BillingService.setPlan(BillingPlan.solo)
-- würde 23514 werfen. Diese Migration korrigiert das.
--
-- Plan, Reihenfolge:
--   1) CHECK droppen.
--   2) Bestehende Datenwerte über UPDATE migrieren (starter→solo,
--      pro→solo_pro, ultimate→enterprise).
--   3) Neuen CHECK setzen, der nur die 6 finalen Werte erlaubt.
--
-- Die Legacy-Werte ('starter','pro','ultimate') werden bewusst NICHT mehr
-- als gültig akzeptiert — der Realign schließt sie hart aus. Falls in der
-- Zukunft eine alte Zeile durchrutscht, fängt das CASE-Mapping in
-- workspace_limit_for_plan (Migration T3) sie als Safety-Net ab.

ALTER TABLE public.billing_profiles
  DROP CONSTRAINT IF EXISTS billing_profiles_plan_check;

-- Daten-Migration: Legacy-Werte → neue 6-Tier-Werte. Idempotent: zweiter
-- Lauf trifft 0 Zeilen, weil die UPDATE-WHERE-Klauseln dann leer sind.
UPDATE public.billing_profiles SET plan = 'solo'       WHERE plan = 'starter';
UPDATE public.billing_profiles SET plan = 'solo_pro'   WHERE plan = 'pro';
UPDATE public.billing_profiles SET plan = 'enterprise' WHERE plan = 'ultimate';

ALTER TABLE public.billing_profiles
  ADD CONSTRAINT billing_profiles_plan_check
  CHECK (plan IN ('free','solo','solo_pro','team','business','enterprise'));

COMMENT ON CONSTRAINT billing_profiles_plan_check ON public.billing_profiles IS
  '6-Tier-Schema, synchron mit BillingPlan.apiName in lib/models/billing_profile.dart.';
