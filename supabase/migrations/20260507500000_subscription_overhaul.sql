-- Sprint 6 Follow-up: Plan-Struktur überarbeiten.
--
-- - "enterprise" wird durch "ultimate" als regulärer Top-Tier ersetzt.
--   Bestehende Profile mit plan='enterprise' werden auf 'ultimate'
--   migriert (kein Datenverlust, gleiche Quotas).
-- - CHECK-Constraint enthält ab jetzt 'ultimate' statt 'enterprise'.
--
-- Plan-Quotas (Mailbox-Anzahl, Inbox-Sichtbarkeit) sind clientseitig
-- in lib/models/pricing_plan.dart hinterlegt — DB enforced nur den
-- Plan-Namen, die Limits werden in der App validiert.

ALTER TABLE public.billing_profiles
  DROP CONSTRAINT IF EXISTS billing_profiles_plan_check;

UPDATE public.billing_profiles
   SET plan = 'ultimate'
 WHERE plan = 'enterprise';

ALTER TABLE public.billing_profiles
  ADD CONSTRAINT billing_profiles_plan_check
  CHECK (plan IN ('free','starter','pro','business','ultimate'));
