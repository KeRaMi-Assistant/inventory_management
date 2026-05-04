-- ─── Team-Modus-Fundament: Workspaces, Members, Audit-Log ─────────────────
--
-- Aktuell hängen alle Daten direkt an `auth.users.id`. Für den Team-Modus
-- brauchen wir eine Indirektion über `workspaces`. Dieser Schritt legt nur
-- das Schema und einen impliziten "Personal Workspace" pro existierendem
-- User an — die Daten-Tabellen bleiben unverändert. RLS-Policies werden
-- erst in einer Folgemigration umgestellt, sobald die UI Workspaces
-- auswählen kann; so brechen heutige Deals/Items nicht.
--
-- Rollen:
--   * owner   — Workspace-Anlegender. Darf alles, inkl. löschen.
--   * admin   — Darf einladen, Daten ändern.
--   * member  — Darf Daten lesen + bearbeiten, aber nicht einladen.
--   * viewer  — Read-only. Für Steuerberater / externe Reviewer.

-- pgcrypto stellt `gen_random_bytes` für sichere Invite-Tokens bereit.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ── workspaces ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.workspaces (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT        NOT NULL CHECK (length(name) BETWEEN 1 AND 80),
  owner_id    UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at  TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS workspaces_owner_idx
  ON public.workspaces(owner_id) WHERE deleted_at IS NULL;
ALTER TABLE public.workspaces ENABLE ROW LEVEL SECURITY;

-- ── workspace_members ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.workspace_members (
  workspace_id UUID NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
  user_id      UUID NOT NULL REFERENCES auth.users(id)         ON DELETE CASCADE,
  role         TEXT NOT NULL CHECK (role IN ('owner','admin','member','viewer')),
  invited_by   UUID         REFERENCES auth.users(id)          ON DELETE SET NULL,
  joined_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (workspace_id, user_id)
);
CREATE INDEX IF NOT EXISTS workspace_members_user_idx
  ON public.workspace_members(user_id);
ALTER TABLE public.workspace_members ENABLE ROW LEVEL SECURITY;

-- ── workspace_invites ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.workspace_invites (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
  email        TEXT NOT NULL,
  role         TEXT NOT NULL CHECK (role IN ('admin','member','viewer')),
  invited_by   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token        TEXT NOT NULL UNIQUE DEFAULT encode(extensions.gen_random_bytes(24), 'hex'),
  expires_at   TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '14 days',
  accepted_at  TIMESTAMPTZ,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS workspace_invites_email_idx
  ON public.workspace_invites(lower(email)) WHERE accepted_at IS NULL;
ALTER TABLE public.workspace_invites ENABLE ROW LEVEL SECURITY;

-- ── audit_log (workspace-scoped) ────────────────────────────────────────
-- Bleibt parallel zur bestehenden activity_log-Tabelle: activity_log ist
-- ein User-Heatmap-Stream (für die Aktivitäts-UI), audit_log ist die
-- Compliance-Spur für Team-Aktionen ("wer hat was wann geändert").
CREATE TABLE IF NOT EXISTS public.audit_log (
  id           BIGSERIAL    PRIMARY KEY,
  workspace_id UUID         NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
  actor_id     UUID         NOT NULL REFERENCES auth.users(id)         ON DELETE SET NULL,
  entity_type  TEXT         NOT NULL,
  entity_id    TEXT,
  action       TEXT         NOT NULL CHECK (action IN ('create','update','delete','restore','invite','accept','revoke','role_change')),
  diff         JSONB,
  created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS audit_log_workspace_created_idx
  ON public.audit_log(workspace_id, created_at DESC);
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

-- ── RLS-Policies ────────────────────────────────────────────────────────

-- Workspaces: Mitglieder dürfen lesen, Owner darf schreiben.
DROP POLICY IF EXISTS workspaces_member_read ON public.workspaces;
CREATE POLICY workspaces_member_read ON public.workspaces
  FOR SELECT USING (
    deleted_at IS NULL AND (
      owner_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM public.workspace_members m
        WHERE m.workspace_id = id AND m.user_id = auth.uid()
      )
    )
  );

DROP POLICY IF EXISTS workspaces_owner_write ON public.workspaces;
CREATE POLICY workspaces_owner_write ON public.workspaces
  FOR ALL USING (owner_id = auth.uid()) WITH CHECK (owner_id = auth.uid());

-- Members: Mitglieder dürfen die Liste der Mitarbeiter im eigenen Workspace
-- sehen. Schreiben darf nur Owner/Admin (durch Trigger geprüft, hier
-- vereinfacht: auth.uid muss owner sein).
DROP POLICY IF EXISTS members_self_read ON public.workspace_members;
CREATE POLICY members_self_read ON public.workspace_members
  FOR SELECT USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.workspace_members me
      WHERE me.workspace_id = workspace_id AND me.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS members_owner_write ON public.workspace_members;
CREATE POLICY members_owner_write ON public.workspace_members
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.workspaces w
      WHERE w.id = workspace_id AND w.owner_id = auth.uid()
    )
  ) WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.workspaces w
      WHERE w.id = workspace_id AND w.owner_id = auth.uid()
    )
  );

-- Invites: nur Workspace-Mitglieder mit role in (owner,admin) sehen
-- Einladungen ihres Workspaces. Eingeladene User sehen ihre offenen Invites
-- über den separaten /invites-Endpoint (Edge Function), nicht hierüber.
DROP POLICY IF EXISTS invites_owner_admin ON public.workspace_invites;
CREATE POLICY invites_owner_admin ON public.workspace_invites
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.workspace_members m
      WHERE m.workspace_id = workspace_id
        AND m.user_id = auth.uid()
        AND m.role IN ('owner','admin')
    )
  ) WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.workspace_members m
      WHERE m.workspace_id = workspace_id
        AND m.user_id = auth.uid()
        AND m.role IN ('owner','admin')
    )
  );

-- Audit-Log: Mitglieder dürfen den Audit-Trail des Workspaces lesen, aber
-- nicht direkt schreiben (Server-Trigger oder Edge Function schreibt).
DROP POLICY IF EXISTS audit_member_read ON public.audit_log;
CREATE POLICY audit_member_read ON public.audit_log
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.workspace_members m
      WHERE m.workspace_id = workspace_id AND m.user_id = auth.uid()
    )
  );

-- ── Auto-Provisioning: Personal Workspace pro User ──────────────────────
-- Trigger, der bei Anlage eines neuen auth.users-Eintrags einen Workspace
-- mit dem User als Owner anlegt. Stellt sicher, dass jeder neue User direkt
-- einen workspace_id hat, gegen den später alle Daten umgestellt werden.

CREATE OR REPLACE FUNCTION public.provision_personal_workspace()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  ws_id UUID;
BEGIN
  INSERT INTO public.workspaces (name, owner_id)
  VALUES ('Personal', NEW.id)
  RETURNING id INTO ws_id;

  INSERT INTO public.workspace_members (workspace_id, user_id, role, invited_by, joined_at)
  VALUES (ws_id, NEW.id, 'owner', NEW.id, NOW());

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_provision_personal_workspace ON auth.users;
CREATE TRIGGER trg_provision_personal_workspace
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.provision_personal_workspace();

-- ── Backfill für bereits existierende User ──────────────────────────────
-- Legt Personal-Workspaces für alle User an, die noch keinen besitzen.
INSERT INTO public.workspaces (name, owner_id)
SELECT 'Personal', u.id
FROM auth.users u
WHERE NOT EXISTS (
  SELECT 1 FROM public.workspaces w WHERE w.owner_id = u.id
);

INSERT INTO public.workspace_members (workspace_id, user_id, role, invited_by, joined_at)
SELECT w.id, w.owner_id, 'owner', w.owner_id, NOW()
FROM public.workspaces w
WHERE NOT EXISTS (
  SELECT 1 FROM public.workspace_members m
  WHERE m.workspace_id = w.id AND m.user_id = w.owner_id
);
