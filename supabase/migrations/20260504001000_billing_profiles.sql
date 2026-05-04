-- ─── Billing-Profile: Plan + Rechnungsadresse pro User ──────────────────
--
-- Pro User existiert genau eine `billing_profiles`-Zeile. Die Felder sind
-- bewusst NICHT NOT NULL, weil Free-User keine Rechnungsadresse pflegen
-- müssen. Ab dem ersten kostenpflichtigen Plan validiert die App
-- (clientseitig) die Pflichtfelder und blockiert den Upgrade-Flow, falls
-- die Daten unvollständig sind. Auf DB-Ebene halten wir das Schema
-- absichtlich offen, damit der Free-Pfad ohne zusätzliche Reibung
-- funktioniert.
--
-- Die Zeile wird per Trigger automatisch beim Anlegen eines neuen
-- Auth-Users erzeugt (analog zum Personal-Workspace-Trigger), damit der
-- Default-Plan `free` immer existiert.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.billing_profiles (
  user_id         UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  plan            TEXT        NOT NULL DEFAULT 'free'
                  CHECK (plan IN ('free','starter','pro','business','enterprise')),
  billing_cycle   TEXT        CHECK (billing_cycle IN ('monthly','yearly')),
  plan_started_at TIMESTAMPTZ,
  plan_renews_at  TIMESTAMPTZ,
  full_name       TEXT,
  company         TEXT,
  vat_id          TEXT,
  phone           TEXT,
  address_line1   TEXT,
  address_line2   TEXT,
  postal_code     TEXT,
  city            TEXT,
  region          TEXT,
  country         TEXT        NOT NULL DEFAULT 'DE'
                  CHECK (length(country) = 2),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS billing_profiles_plan_idx
  ON public.billing_profiles(plan);

ALTER TABLE public.billing_profiles ENABLE ROW LEVEL SECURITY;

-- ── RLS-Policies ────────────────────────────────────────────────────────
-- User darf nur die eigene Zeile sehen/ändern. Das Anlegen erledigt der
-- Trigger; ein manueller INSERT durch den User ist trotzdem zulässig
-- (idempotent durch ON CONFLICT in der App-Schicht).

DROP POLICY IF EXISTS billing_profiles_select_own ON public.billing_profiles;
CREATE POLICY billing_profiles_select_own
  ON public.billing_profiles
  FOR SELECT
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS billing_profiles_insert_own ON public.billing_profiles;
CREATE POLICY billing_profiles_insert_own
  ON public.billing_profiles
  FOR INSERT
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS billing_profiles_update_own ON public.billing_profiles;
CREATE POLICY billing_profiles_update_own
  ON public.billing_profiles
  FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- updated_at automatisch pflegen.
CREATE OR REPLACE FUNCTION public.billing_profiles_touch_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS billing_profiles_set_updated_at ON public.billing_profiles;
CREATE TRIGGER billing_profiles_set_updated_at
  BEFORE UPDATE ON public.billing_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.billing_profiles_touch_updated_at();

-- Auto-Anlage bei neuem Auth-User.
CREATE OR REPLACE FUNCTION public.create_billing_profile_for_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.billing_profiles (user_id)
       VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created_billing ON auth.users;
CREATE TRIGGER on_auth_user_created_billing
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.create_billing_profile_for_new_user();

-- Bestehende User nachziehen (idempotent).
INSERT INTO public.billing_profiles (user_id)
SELECT u.id FROM auth.users u
LEFT JOIN public.billing_profiles bp ON bp.user_id = u.id
WHERE bp.user_id IS NULL;
