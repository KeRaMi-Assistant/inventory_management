---
slug: workspace_naming_multi_invites
date: 2026-05-20
owner: planner
status: committee-approved
review_status: "[Committee-Approved 2026-05-20]"
confidence: medium
estimated_effort_hours: 18
touches:
  - lib/models/workspace.dart
  - lib/models/billing_profile.dart
  - lib/services/workspace_service.dart
  - lib/providers/active_workspace_provider.dart
  - lib/providers/billing_provider.dart
  - lib/screens/settings_screen.dart
  - lib/screens/pricing_screen.dart
  - lib/screens/help_screen.dart
  - lib/widgets/workspace_switcher.dart
  - lib/widgets/create_workspace_dialog.dart
  - lib/widgets/invite_member_dialog.dart
  - lib/widgets/limit_reached_dialog.dart
  - lib/widgets/member_remove_confirm_dialog.dart
  - lib/widgets/invites_bell.dart
  - lib/utils/role_labels.dart
  - lib/l10n/app_de.arb
  - lib/l10n/app_en.arb
  - supabase/migrations/20260520000000_billing_plan_realign.sql
  - supabase/migrations/20260520000050_workspaces_rls_split.sql
  - supabase/migrations/20260520000150_workspace_is_personal.sql
  - supabase/migrations/20260520000200_workspace_create_rpc.sql
  - supabase/migrations/20260520000300_workspace_role_labels.sql
  - test/workspace_service_test.dart
  - test/workspace_limits_test.dart
  - test/widgets/invite_member_dialog_test.dart
  - test/widgets/create_workspace_dialog_test.dart
  - .claude/agents/_page-registry.md
  - docs/handbook/03-screens-walkthrough.md
  - docs/handbook/05-architecture.md
  - docs/handbook/06-database.md
---

# [Committee-Approved 2026-05-20] Workspace-Benennung, Multi-Workspace pro Plan, Team-Einladungen

> **Status:** Committee-Approved 2026-05-20 (5-Reviewer-Council mit 12 Blockern + 5 Verbesserungen).
> Alle Blocker sind in diesen Plan integriert. Vor Implementation-Phase MUSS
> `bash .claude/scripts/validate-plan.sh plans/2026-05-20_workspace_naming_multi_invites.md` exit 0 liefern.

## Ziel

Owner können beliebige Workspaces benennen, je nach gebuchtem Plan
zusätzliche Workspaces erstellen und Teammitglieder mit Rollen
**Editor** (Lesen + Schreiben) oder **Beobachter** (Read-only) einladen.
Personal-Workspace bleibt der unkündbare Default (markiert via neuer
`is_personal` BOOLEAN-Spalte); Limits werden server-seitig per RPC
durchgesetzt, direkter Client-INSERT auf `workspaces` ist RLS-blockiert.

## Scope

### In-Scope

- **DB-Realign:** `billing_profiles.plan` CHECK auf neues 6-Tier-Schema
  (`free|solo|solo_pro|team|business|enterprise`).
- **RLS-Härtung:** `workspaces_owner_write` (FOR ALL) wird gesplittet in
  UPDATE + DELETE; INSERT bleibt RLS-deny (geht nur via Trigger oder RPC).
- **Schema-Anreicherung:** `workspaces.is_personal BOOLEAN NOT NULL DEFAULT FALSE`
  + Backfill (älteste pro Owner = personal) + Trigger-Update.
- **Service- und RPC-Layer:** `create_workspace(_name TEXT)` mit
  serverseitiger Plan-Limit-Prüfung + Advisory-Lock gegen Race-Conditions.
- **Plan→Workspace-Limit-Tabelle:** Dart-Konstante + DB-Funktion
  `workspace_limit_for_plan(_plan TEXT)`.
- **Dart-Enum-Rename:** `WorkspaceRole.member` → `editor`,
  `WorkspaceRole.viewer` → `observer`; API-Wire-Mapping bleibt
  `member`/`viewer` (Backwards-compat per `apiName`/`fromApi`).
- **UI:** Workspace-Switcher in Settings/Team-Tab (Phone + Desktop),
  „Neuer Workspace"-Button (immer enabled; bei Limit → `LimitReachedDialog`),
  Rename-Dialog für Owner, Invite-Dialog mit Editor/Beobachter,
  optionales Admin nur bei Plan ≥ team und Owner-Rolle,
  Member-Remove-Confirm-Dialog (destruktiv).
- **Mobile-First-Refactor:** `CreateWorkspaceDialog` + `InviteMemberDialog`
  als `showModalBottomSheet(isScrollControlled: true)` mit
  `MediaQuery.viewInsetsOf` und `SafeArea`.
- **l10n DE+EN** für alle neuen User-Strings (42 Keys, siehe Tabelle unten).
- **Hilfe-Seite:** 3 neue FAQ-Einträge (Wie einladen / welche Rollen /
  wie viele Workspaces).
- **Page-Registry:** zwei neue Sub-Routes (Create-Workspace-Sheet,
  Invite-Member-Sheet) und ein neuer Confirm-Dialog (Member-Remove).
- **Tests:** Service-Unit (Mock-SupabaseClient), Widget (Invite-Dialog,
  Create-Dialog), Smoke (`smoke-team-create`, `smoke-team-invite`,
  `smoke-team-limit`).

### Out-of-Scope

- **SMTP-Mail-Versand der Invites.** Pre-Launch-Entscheidung: nur
  Token-Link in der UI anzeigen + „Link kopieren"-Button. Ein
  späteres Resend-/Postmark-Edge-Function-Backend wird in einem
  Folge-Plan adressiert (`plans/<future>_invite_email_dispatch.md`).
  Hint: `supabase.auth.admin.generateLink('invite')` als möglicher
  Bootstrap-Pfad notiert (siehe §Verbesserungen V5).
- **Workspace-Löschen via UI.** Soft-Delete-Spalte existiert bereits
  (`workspaces.deleted_at`), aber Delete-Flow ist eigene Story
  (Datenmigration, Re-Assign offene Deals, Confirm-Dialog). Hier
  nicht. Siehe R6 für den `deleted_at`-Schreibschutz-Trigger, der
  bewusst auf den Soft-Delete-Folge-Plan vertagt wird.
- **Owner-Transfer.** Nur eine TODO-Notiz im Help-Text; Logik kommt
  später.
- **Audit-Log-Einträge schreiben** für create/invite/role_change.
  Tabelle existiert (`audit_log`), aber Audit-Writes sind separater
  Plan.
- **Billing-Plan-Definition / Pricing-Texte.** Plan-Limits werden
  hier definiert, aber `pricing_screen.dart`-Marketing-Texte bleiben
  unverändert (nur Upsell-Hint-CTA wird auf existierenden Screen
  verlinkt).
- **`BillingService.setPlan` zu SECURITY DEFINER RPC umbauen.**
  Siehe Tech-Decision D6 / Blocker 3: REVOKE der `plan`-Spalten-
  UPDATE-Rechte wird in diesem Plan NICHT durchgeführt — das ist
  ein Stripe-Webhook-Folge-Plan. Risiko-Eintrag R10.
- **`deleted_at`-Mutation-Guard-Trigger.** Wird mit dem Soft-Delete-
  UI-Folge-Plan eingebaut (R6).

## Tech-Decisions

### D1: Editor/Beobachter — Dart-Enum-Rename, API-Wire bleibt member/viewer

**Entscheidung:** Das Dart-Enum heißt ab sofort `WorkspaceRole.editor`
und `WorkspaceRole.observer`. Die SQL-CHECK-Constraint und der
PostgREST-Wire bleiben unverändert (`member`/`viewer`) — Mapping
geschieht in `WorkspaceRole.apiName` / `WorkspaceRole.fromApi`.

**Begründung:**

- **Keine SQL-Datenmigration:** `workspace_members.role` CHECK bleibt
  `('owner','admin','member','viewer')`. RLS-Helper, SECURITY-DEFINER-
  RPCs (`accept_workspace_invite`), Trigger und Audit-Log-Texte
  bleiben funktional.
- **Konsistenz in Dart:** Bisher zeigte der Code `WorkspaceRole.member`,
  die UI schrieb aber „Mitglied" hin und der Council wollte „Editor".
  Das hatte zu drift-Risiken in `_roleLabel`-Mappings geführt
  (`lib/widgets/invites_bell.dart:170`, `lib/screens/settings_screen.dart:1787`).
  Mit dem Enum-Rename ist der Dart-Code Single-Source — Übersetzung
  Editor↔member lebt nur noch im `apiName`/`fromApi`-Mapping.
- **Backwards-compat:** `fromApi('member')` → `WorkspaceRole.editor`,
  `fromApi('viewer')` → `WorkspaceRole.observer`. Safe-fallback bei
  unbekanntem String → `observer` (least-privilege).
- **Help-FAQ-Text** streicht den ursprünglich geplanten Hinweis
  „intern heißen die Rollen member/viewer", weil der Dart-Layer das
  jetzt versteckt — User sieht nirgendwo mehr `member`.

**Touch-Liste für Enum-Rename (vollständig):**

- `lib/models/workspace.dart` — Enum + `apiName` + `fromApi` + `canManageMembers` + `canEdit` + `label` (label wird via l10n-Aliasing in der UI ersetzt; im Modell bleibt nur ein Debug-Label).
- `lib/widgets/invites_bell.dart:170-171` — Map auf neue Enum-Werte.
- `lib/screens/settings_screen.dart:1787-1832` — Map + Default-Wert.
- Alle weiteren Stellen findet `grep -rn 'WorkspaceRole\.\(member\|viewer\)' lib/` — laut Pre-Check sind das die zwei oben genannten Files.

**Verworfene Alternativen:**

- (a) **Pure UI-Aliasing** (Original-Plan): Dart-Enum bleibt
  `member`/`viewer`. Verworfen weil das Aliasing in jedem konsumierenden
  Widget separat passieren muss — drift-anfällig.
- (b) **Volle SQL-Migration** mit role-CHECK auf `('owner','admin','editor','observer')`:
  Existierende `accept_workspace_invite`-RPC + RLS-Helper `has_workspace_role(..., ARRAY['admin','member'])`
  müssten parallel migriert werden. Zu viel Surface für ein Pre-Launch-
  UI-Polish.

### D2: Workspace-Limits pro Plan

| Plan        | Limit | Begründung |
|-------------|-------|------------|
| free        | 1     | Nur Personal — kein Multi-Tenant-Anreiz für Free. |
| solo        | 1     | Solo = Einzelperson, kein Team. |
| solo_pro    | 2     | Soft-Upgrade: trennen privat/geschäftlich. |
| team        | 5     | Echter Team-Plan, Mandanten-Trennung möglich. |
| business    | 20    | Agenturen mit mehreren Kunden. |
| enterprise  | -1    | Unbegrenzt (Sentinel `-1`). |

Die Tabelle lebt **zweimal**:

1. **Dart-Konstante** `BillingPlan.workspaceLimit` in
   `lib/models/billing_profile.dart` (für UI-Gating, Upsell-Hint,
   Button-Disable).
2. **Postgres-Funktion** `workspace_limit_for_plan(_plan TEXT)` [NEW RPC]
   in der neuen Migration (für serverseitige Enforcement).

Beide MÜSSEN identisch sein. Drift-Schutz: Unit-Test
`workspace_limits_test.dart` enthält die Tabelle als Source-of-Truth-
Liste. Ein automatisierter SQL↔Dart-Cross-Test ist als Folge-Issue
notiert (V4).

### D3: Personal-Workspace ist NICHT umbenennbar — markiert via `is_personal`

**Entscheidung:** Neue Spalte `workspaces.is_personal BOOLEAN NOT NULL DEFAULT FALSE`.
Trigger `provision_personal_workspace` setzt sie auf `TRUE` für die
durch das Auto-Provisioning entstandene Zeile. Backfill via
`ROW_NUMBER() OVER (PARTITION BY owner_id ORDER BY created_at ASC)`.

UI verhält sich so:
- Rename des Personal-Workspace ist **erlaubt** (Owner darf), aber das
  UI zeigt vorher einen **Confirm-Dialog** mit dem Warntext aus
  `teamRenamePersonalWarn`.
- `WorkspaceSwitcher` zeigt einen kleinen Tooltip-Badge „Aktiv" und
  einen „Personal"-Indikator (Icon).

**Begründung gegenüber Original-Plan:** Original wollte den Personal-
WS via `created_at = MIN(created_at) per owner` erkennen. Das ist
nicht stabil, wenn ein User mehrere alte Workspaces hat. Eine
explizite Spalte ist robust und wird vom Council als R3-Mitigation
gefordert.

### D4: Invite-Mail-Versand — Pre-Launch: nur Link-Kopieren

**Entscheidung:** Nach erfolgreichem `createInvite` zeigt die UI einen
Bottom-Sheet mit Bestätigungs-Text, Token-Link, „Link kopieren"-Button
und Hinweis auf Folge-Version. Schema `https://<app-host>/invites/<token>`
basiert auf `AppLinks.baseUrl`.

**Folge-Plan-Hinweis (V5):** Sobald Edge-Function `send-invite-email`
existiert, kann der Bootstrap-Pfad
`supabase.auth.admin.generateLink({type: 'invite', email})` genutzt
werden, um den Magic-Link parallel zum manuellen Token-Link zu
erzeugen. UI bleibt gleich.

### D5: Server-Side Enforcement via SECURITY DEFINER RPC + Advisory-Lock

`createWorkspace` ist kein direkter INSERT, sondern RPC
`create_workspace(_name TEXT)` [NEW]. Damit:

- **Advisory-Lock** auf `hashtext('create_workspace:' || v_uid::text)`
  verhindert TOCTOU-Races zwischen Limit-Read und Insert (Blocker 4).
- Plan-Limit-Check in einem TX (kein Race zwischen Limit-Read und
  Insert).
- Auto-Insert in `workspace_members` mit role=`owner`.
- RLS bleibt für direkte INSERTs auf `workspaces` **deny** (siehe D7).

### D6: Direkter Client-INSERT auf `workspaces` ist RLS-blockiert (Blocker 2)

**Entscheidung:** `workspaces_owner_write` (FOR ALL) wird gedroppt
und gesplittet in:

- `workspaces_owner_update` (FOR UPDATE)
- `workspaces_owner_delete` (FOR DELETE)
- **KEINE** INSERT-Policy für `authenticated`.

INSERT-Pfade sind dadurch ausschließlich:

1. Trigger `provision_personal_workspace` (SECURITY DEFINER, bypassed RLS).
2. RPC `create_workspace` (SECURITY DEFINER, bypassed RLS).

**Begründung:** Existierende Policy `workspaces_owner_write FOR ALL`
(siehe `supabase/migrations/20260504000200_workspaces.sql:94-95`) hat
das `WITH CHECK (owner_id = auth.uid())` und würde einen Client-INSERT
mit eigenem `owner_id` durchlassen — die RPC mit Plan-Limit-Check
wäre umgehbar. Council-Security-Finding **verifiziert** = real.

### D7: `billing_profiles.plan` UPDATE-Rechte — Plan dokumentiert Risiko, REVOKE wird NICHT durchgeführt (Blocker 3)

**Entscheidung:** Option (b) wird gewählt: REVOKE der `UPDATE (plan, billing_cycle, plan_started_at, plan_renews_at)`-
Spalten-Rechte auf `billing_profiles` für `authenticated` wird **NICHT**
in diesem Plan umgesetzt.

**Begründung:**

- **Verifiziert:** `lib/services/billing_service.dart:50-71` enthält
  `setPlan(plan, cycle)` — das ist ein direkter UPDATE auf
  `billing_profiles` mit `plan`, `billing_cycle`, `plan_started_at`,
  `plan_renews_at`. Ein REVOKE würde den Pre-Launch-Upgrade-Flow
  brechen (Pricing-Screen → Plan ändern → 403).
- **Option (a)** (`setPlan` → SECURITY DEFINER RPC mit Stripe-Webhook-
  Echo) ist zu breit für diesen Plan: Stripe-Webhook-Pfad existiert
  nicht, Pre-Launch ohne echtes Billing.
- **Option (b)** (REVOKE weglassen, Risiko-Eintrag): Pre-Launch ohne
  echte Nutzer, kein echtes Geld → akzeptabel. Risiko ist in **R10**
  dokumentiert.

**Folge-Plan:** Sobald Stripe-Webhook existiert, wird `setPlan` zu
einer SECURITY DEFINER RPC umgebaut, die nur via Stripe-Event-ID
+ Webhook-Signatur ausgelöst wird. Erst dann ist der REVOKE sicher
ausführbar.

### D8: Billing-Plan-Realign (Blocker 1)

**Verifiziert:** Drei Quellen stehen heute in Konflikt:

- `supabase/migrations/20260504000300_billing_profiles.sql:20` ← CHECK
  `('free','starter','pro','business','enterprise')`.
- `supabase/migrations/20260507500000_subscription_overhaul.sql:21` ←
  CHECK `('free','starter','pro','business','ultimate')` (überschreibt).
- `lib/models/billing_profile.dart:10-43` ← Enum
  `free|solo|soloPro|team|business|enterprise`, `fromString` mappt
  Legacy → Neu.

→ Heute kann der Dart-Code keinen 'solo'-Plan in die DB schreiben,
weil der CHECK-Constraint ihn ablehnt. `setPlan(BillingPlan.solo)`
würde scheitern. Council-Bug-Hunter-Finding **verifiziert** = real.

**Entscheidung:** Neue Migration `20260520000000_billing_plan_realign.sql`
als T0 (vor allen anderen Migrationen):

```sql
ALTER TABLE public.billing_profiles
  DROP CONSTRAINT IF EXISTS billing_profiles_plan_check;

UPDATE public.billing_profiles SET plan = 'solo'       WHERE plan = 'starter';
UPDATE public.billing_profiles SET plan = 'solo_pro'   WHERE plan = 'pro';
UPDATE public.billing_profiles SET plan = 'enterprise' WHERE plan = 'ultimate';

ALTER TABLE public.billing_profiles
  ADD CONSTRAINT billing_profiles_plan_check
  CHECK (plan IN ('free','solo','solo_pro','team','business','enterprise'));
```

Damit ist der CHECK ab T0 synchron mit `BillingPlan.apiName`. Der
`workspace_limit_for_plan`-Lookup behält trotzdem die Legacy-Werte
(`starter`, `pro`, `ultimate`) als Safety-Net falls die UPDATE-
Statements aus irgendeinem Grund eine Zeile übersehen.

## Datenmodell

### Migration T0: `20260520000000_billing_plan_realign.sql` [NEW]

Siehe D8. Realigned `billing_profiles.plan` CHECK + Datenwerte auf
6-Tier-Schema. **Pflicht-Reihenfolge: läuft vor allen anderen
Migrations dieses Plans.**

### Migration T1: `20260520000050_workspaces_rls_split.sql` [NEW]

```sql
DROP POLICY IF EXISTS workspaces_owner_write ON public.workspaces;

CREATE POLICY workspaces_owner_update ON public.workspaces
  FOR UPDATE
  USING  (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY workspaces_owner_delete ON public.workspaces
  FOR DELETE
  USING  (owner_id = auth.uid());

-- KEINE INSERT-Policy für authenticated. INSERT nur via:
--   1) Trigger provision_personal_workspace (SECURITY DEFINER)
--   2) RPC create_workspace (SECURITY DEFINER, kommt in 20260520000200)
COMMENT ON TABLE public.workspaces IS
  'INSERT ist RLS-deny. Anlage nur via Trigger provision_personal_workspace oder RPC create_workspace.';
```

**Hinweis R6:** Der ursprünglich geplante `deleted_at`-Mutation-Guard-
Trigger (`workspaces_reject_deleted_at_mutation`) wird in diesem Plan
**NICHT** eingebaut — siehe R6.

### Migration T2: `20260520000150_workspace_is_personal.sql` [NEW]

```sql
ALTER TABLE public.workspaces
  ADD COLUMN IF NOT EXISTS is_personal BOOLEAN NOT NULL DEFAULT FALSE;

-- Backfill: älteste WS pro owner_id = is_personal
WITH ranked AS (
  SELECT id, owner_id,
         ROW_NUMBER() OVER (PARTITION BY owner_id ORDER BY created_at ASC) AS rn
    FROM public.workspaces
)
UPDATE public.workspaces w
   SET is_personal = TRUE
  FROM ranked r
 WHERE w.id = r.id AND r.rn = 1;

-- Trigger provision_personal_workspace erweitern (bestehender Trigger
-- aus 20260504000200_workspaces.sql:161 wird überschrieben — Funktion
-- bleibt gleich, nur INSERT bekommt is_personal = TRUE).
CREATE OR REPLACE FUNCTION public.provision_personal_workspace()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth AS $$
DECLARE
  v_ws_id UUID;
BEGIN
  INSERT INTO public.workspaces (name, owner_id, is_personal)
       VALUES ('Personal', NEW.id, TRUE)
    RETURNING id INTO v_ws_id;

  INSERT INTO public.workspace_members
         (workspace_id, user_id, role, invited_by, joined_at)
       VALUES
         (v_ws_id, NEW.id, 'owner', NEW.id, NOW());

  RETURN NEW;
END;
$$;
```

**Hinweis:** Trigger wird via `CREATE OR REPLACE FUNCTION` überschrieben.
Existierender `DROP TRIGGER … CREATE TRIGGER`-Block aus
`20260504000200_workspaces.sql:177-180` bleibt unverändert.

### Migration T3: `20260520000200_workspace_create_rpc.sql` [NEW]

```sql
-- workspace_limit_for_plan(plan): zentraler Lookup [NEW]
CREATE OR REPLACE FUNCTION public.workspace_limit_for_plan(_plan TEXT)
RETURNS INTEGER LANGUAGE sql IMMUTABLE
SET search_path = public AS $$
  SELECT CASE _plan
    WHEN 'free'        THEN 1
    WHEN 'solo'        THEN 1
    WHEN 'solo_pro'    THEN 2
    WHEN 'team'        THEN 5
    WHEN 'business'    THEN 20
    WHEN 'enterprise'  THEN -1   -- unlimited
    -- Legacy-Aliase (Safety-Net, eigentlich durch T0 realigned)
    WHEN 'starter'     THEN 1
    WHEN 'pro'         THEN 2
    WHEN 'ultimate'    THEN -1
    ELSE 1
  END;
$$;

GRANT EXECUTE ON FUNCTION public.workspace_limit_for_plan(TEXT) TO authenticated;

-- create_workspace(name): atomar mit Limit-Check + Advisory-Lock [NEW]
CREATE OR REPLACE FUNCTION public.create_workspace(_name TEXT)
RETURNS public.workspaces
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth AS $$
DECLARE
  v_uid        UUID := auth.uid();
  v_plan       TEXT;
  v_limit      INTEGER;
  v_count      INTEGER;
  v_clean      TEXT;
  v_workspace  public.workspaces%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  -- Advisory-Lock (Blocker 4): verhindert TOCTOU bei parallelen
  -- create_workspace-Calls desselben Users. Lock wird bei TX-Ende
  -- automatisch freigegeben.
  PERFORM pg_advisory_xact_lock(hashtext('create_workspace:' || v_uid::text));

  v_clean := btrim(coalesce(_name, ''));
  IF length(v_clean) < 1 OR length(v_clean) > 80 THEN
    RAISE EXCEPTION 'invalid_name';
  END IF;

  SELECT plan INTO v_plan
    FROM billing_profiles
   WHERE user_id = v_uid;
  IF v_plan IS NULL THEN v_plan := 'free'; END IF;

  v_limit := public.workspace_limit_for_plan(v_plan);

  SELECT COUNT(*) INTO v_count
    FROM workspaces
   WHERE owner_id = v_uid AND deleted_at IS NULL;

  IF v_limit >= 0 AND v_count >= v_limit THEN
    RAISE EXCEPTION 'workspace_limit_reached'
      USING HINT = format('plan=%s limit=%s count=%s', v_plan, v_limit, v_count);
  END IF;

  -- is_personal explizit FALSE (nur Trigger setzt TRUE).
  -- RETURNING * holt ALLE Spalten inkl. is_personal — wichtig für
  -- Dart-Model `Workspace.fromSupabase`.
  INSERT INTO workspaces (name, owner_id, is_personal)
       VALUES (v_clean, v_uid, FALSE)
    RETURNING * INTO v_workspace;

  INSERT INTO workspace_members
         (workspace_id, user_id, role, invited_by, joined_at)
       VALUES
         (v_workspace.id, v_uid, 'owner', v_uid, NOW());

  RETURN v_workspace;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_workspace(TEXT) TO authenticated;
```

### Migration T4 (OPTIONAL, NICHT in diesem Plan): `20260520000400_billing_revoke_plan_update.sql`

**Entscheidung:** WIRD NICHT COMMITTED. Siehe D7 + R10.

Inhalt nur als Doku (für Folge-Plan):

```sql
-- ❌ NICHT in diesem Plan — bricht BillingService.setPlan.
-- REVOKE UPDATE (plan, billing_cycle, plan_started_at, plan_renews_at)
--   ON public.billing_profiles FROM authenticated;
```

### Migration T5: `20260520000300_workspace_role_labels.sql` [NEW, Living-Doc]

```sql
COMMENT ON COLUMN public.workspace_members.role IS
  'owner|admin|member|viewer. API-Wire bleibt member/viewer; Dart-Enum heißt editor/observer (siehe lib/models/workspace.dart WorkspaceRole.apiName).';

COMMENT ON COLUMN public.workspaces.is_personal IS
  'TRUE für den Auto-Provisioned Personal-Workspace pro User. Wird nur vom Trigger provision_personal_workspace gesetzt; create_workspace setzt FALSE.';
```

**Begründung:** Kostet nichts, dokumentiert die D1-/D3-Entscheidung am
Schema selbst — Future-Maintainer sehen den Mapping-Hinweis direkt
im DB-Schema-Dump.

### RLS-Bestand verifizieren (nach Migrations T1+T2+T3)

- `workspaces_member_read`: alle Member dürfen lesen — Switcher sieht alle. ✓
- `workspaces_owner_update` (NEU): nur Owner darf rename — Rename funktioniert. ✓
- `workspaces_owner_delete` (NEU): nur Owner darf löschen — Soft-Delete-Folge-Plan kompatibel. ✓
- **INSERT auf workspaces:** RLS-deny für authenticated. Nur SECURITY DEFINER. ✓
- `members_owner_write`: nur Owner darf Members editieren — Rollen-Wechsel + Remove funktioniert. ✓
- `invites_owner_admin`: Owner+Admin dürfen Invites schreiben/lesen — Invite-Flow funktioniert. ✓

## API / Edge Functions

**Keine neue Edge Function in diesem Plan** (siehe D4). Nur drei
neue Postgres-Funktionen:

- `workspace_limit_for_plan(_plan TEXT) → INTEGER` (IMMUTABLE, EXECUTE für authenticated).
- `create_workspace(_name TEXT) → public.workspaces` (SECURITY DEFINER, EXECUTE für authenticated).
- `provision_personal_workspace()` → erweitert (setzt `is_personal=TRUE`).

## Service-API-Skeleton

### `lib/models/workspace.dart` — Enum-Rename + apiName-Mapping (Blocker 7)

```dart
enum WorkspaceRole {
  owner,
  admin,
  editor,    // war: member
  observer;  // war: viewer

  /// Wire-Format gegenüber Supabase. Bleibt aus Backwards-compat-
  /// Gründen `member`/`viewer` (SQL-CHECK + RLS-Helper-Constants).
  String get apiName => switch (this) {
        WorkspaceRole.owner    => 'owner',
        WorkspaceRole.admin    => 'admin',
        WorkspaceRole.editor   => 'member',
        WorkspaceRole.observer => 'viewer',
      };

  static WorkspaceRole fromApi(String s) => switch (s.toLowerCase()) {
        'owner'  => owner,
        'admin'  => admin,
        'member' => editor,
        'viewer' => observer,
        _        => observer,  // safe fallback (least privilege)
      };

  // Debug-Label (Tests / Logs); UI nutzt l10n via lib/utils/role_labels.dart.
  String get debugLabel => switch (this) {
        owner    => 'Owner',
        admin    => 'Admin',
        editor   => 'Editor',
        observer => 'Observer',
      };

  bool get canManageMembers => this == owner || this == admin;
  bool get canEdit          => this != observer;
}
```

`Workspace.fromSupabase` wird erweitert um `is_personal`:

```dart
final bool isPersonal;
// ...
factory Workspace.fromSupabase(Map<String, dynamic> row) => Workspace(
      id: row['id'] as String,
      name: row['name'] as String,
      ownerId: row['owner_id'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      isPersonal: (row['is_personal'] as bool?) ?? false,
      // ... handle, publicProfileEnabled, onboardedAt bleiben
    );
```

### `lib/services/workspace_service.dart` — neue Methode `createWorkspace` [NEW]

```dart
/// Erstellt einen neuen Workspace via RPC. Server prüft Plan-Limit.
/// Wirft [WorkspaceLimitException] bei `workspace_limit_reached`,
/// [ArgumentError] bei `invalid_name`, sonst PostgrestException.
Future<Workspace> createWorkspace(String name) async {
  try {
    final row = await _client.rpc(
      'create_workspace',
      params: {'_name': name},
    );
    if (row is Map) {
      return Workspace.fromSupabase(row.cast<String, dynamic>());
    }
    // PostgREST liefert bei `RETURNS row` ein Single-Element-Array.
    if (row is List && row.isNotEmpty) {
      return Workspace.fromSupabase(
        (row.first as Map).cast<String, dynamic>(),
      );
    }
    throw StateError('create_workspace returned unexpected shape: $row');
  } on PostgrestException catch (e) {
    if (e.message.contains('workspace_limit_reached')) {
      throw WorkspaceLimitException(hint: e.hint);
    }
    if (e.message.contains('invalid_name')) {
      throw ArgumentError.value(name, 'name', 'invalid_name');
    }
    rethrow;
  }
}

class WorkspaceLimitException implements Exception {
  final String? hint;
  WorkspaceLimitException({this.hint});
  @override
  String toString() => 'WorkspaceLimitException(hint: $hint)';
}
```

### `lib/providers/active_workspace_provider.dart` — `createAndSwitchTo` (Blocker 11)

```dart
/// Wrapper um Service + nach Erfolg in-memory anhängen + setActive.
/// Kein full reload — der RPC liefert schon das vollständige
/// Workspace-Objekt, und ein refetch würde nur Latenz hinzufügen.
Future<Workspace> createAndSwitchTo({
  required String name,
  required String currentUserId,
}) async {
  final ws = await _service.createWorkspace(name);
  _workspaces = [..._workspaces, ws];
  await setActive(ws, currentUserId);  // notifyListeners() triggert
  return ws;
}
```

### `BillingProvider` — Convenience-Getter

```dart
int get workspaceLimit => currentPlan.workspaceLimit;  // -1 = unlimited
```

### `BillingPlan.workspaceLimit` (D2)

```dart
/// Anzahl Workspaces, die ein User mit diesem Plan besitzen darf.
/// `-1` = unbegrenzt. MUSS synchron mit
/// `public.workspace_limit_for_plan` in Postgres sein (siehe
/// supabase/migrations/20260520000200_workspace_create_rpc.sql).
int get workspaceLimit => switch (this) {
      BillingPlan.free       => 1,
      BillingPlan.solo       => 1,
      BillingPlan.soloPro    => 2,
      BillingPlan.team       => 5,
      BillingPlan.business   => 20,
      BillingPlan.enterprise => -1,
    };
```

### `lib/utils/role_labels.dart` — Single-Source für l10n-Mapping (V1)

```dart
/// Single-Source für Role-Label-Mapping. Wird von SettingsScreen + InvitesBell
/// + InviteMemberDialog + jeder zukünftigen Stelle konsumiert, damit das
/// Editor/Beobachter-Aliasing nicht in jedem Widget einzeln dupliziert wird.
String roleLabel(WorkspaceRole r, AppLocalizations l10n) => switch (r) {
      WorkspaceRole.owner    => l10n.teamRoleOwner,
      WorkspaceRole.admin    => l10n.teamRoleAdmin,
      WorkspaceRole.editor   => l10n.teamRoleEditor,
      WorkspaceRole.observer => l10n.teamRoleObserver,
    };

String roleHint(WorkspaceRole r, AppLocalizations l10n) => switch (r) {
      WorkspaceRole.owner    => l10n.teamRoleOwnerHint,
      WorkspaceRole.admin    => l10n.teamRoleAdminHint,
      WorkspaceRole.editor   => l10n.teamRoleEditorHint,
      WorkspaceRole.observer => l10n.teamRoleObserverHint,
    };
```

## UI-Wireframe (textuell)

### Settings → Team-Tab (oberhalb existierender Member-Liste)

```
┌─────────────────────────────────────────────────────────────────┐
│ Workspaces                                                       │
│  ▸ Personal           (Owner · 1 Mitglied) · [aktiv-badge]       │
│  ▸ Acme GmbH          (Owner · 3 Mitglieder)                     │
│  ▸ Client X           (Editor · 5 Mitglieder)                    │
│  ⊕ Neuer Workspace                                                │
│    └─ IMMER enabled. Bei Tap + count>=limit → LimitReachedDialog  │
│       (Blocker 9 — Button bleibt anklickbar, Dialog erklärt).     │
└─────────────────────────────────────────────────────────────────┘

   Mitglieder
   ┌─────────────────────────────────────────┐
   │ • Kerem (Owner · seit 12.05.2026)       │
   │ • Anna  (Editor · seit 18.05.2026) [⚙]  │
   │ • Tom   (Beobachter · seit ... )    [⚙] │
   └─────────────────────────────────────────┘
   [⊕ Mitglied einladen]   ← nur sichtbar wenn canManageMembers
```

**Mobile (390×844):**

- Workspace-Switcher = volle Breite, vertikale Liste (Cards) statt
  Dropdown auf Phone.
- „Neuer Workspace"-Button = volle Breite, unter der Liste.
- Member-Rows: 48dp Touch-Targets. Trailing-Icon (Rolle ändern) →
  Bottom-Sheet mit Radio-Liste Editor / Beobachter / Admin.

### Create-Workspace-Sheet (`lib/widgets/create_workspace_dialog.dart`) — als Bottom-Sheet (Blocker 8)

```dart
showModalBottomSheet<Workspace?>(
  context: context,
  isScrollControlled: true,
  builder: (context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: const SafeArea(
      bottom: true,
      child: CreateWorkspaceSheet(),
    ),
  ),
);
```

```
┌──── Neuen Workspace anlegen ──────┐
│                                    │
│ Name                               │
│ [_______________________]          │
│ Validation: 1–80 Zeichen, Pflicht. │
│                                    │
│ Plan-Hinweis (Info-Banner):        │
│ „Plan {plan}: {used}/{limit}       │
│  Workspaces"                       │
│                                    │
│      [Abbrechen]    [Anlegen]      │
└────────────────────────────────────┘
```

Bei Erfolg → SnackBar `teamWorkspacesCreateSuccess`, Provider switched
aktiv auf den neuen WS. Bottom-Sheet schließt.

Bei `WorkspaceLimitException` → schließt das Sheet und öffnet
`LimitReachedDialog` (Blocker 9).

### Limit-Reached-Dialog (`lib/widgets/limit_reached_dialog.dart`) [NEW]

```dart
showDialog<void>(
  context: context,
  builder: (_) => AlertDialog(
    title: Text(l10n.teamWorkspacesLimitReachedTitle),
    content: Text(l10n.teamWorkspacesLimitReachedBody(plan, limit)),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(l10n.commonCancel),
      ),
      FilledButton(
        onPressed: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => const PricingScreen(),
          ));
        },
        child: Text(l10n.teamWorkspacesLimitReachedCta),
      ),
    ],
  ),
);
```

### Invite-Member-Sheet (`lib/widgets/invite_member_dialog.dart`) — als Bottom-Sheet (Blocker 8)

Analog `showModalBottomSheet(isScrollControlled: true)` mit
`MediaQuery.viewInsetsOf(context).bottom` + `SafeArea(bottom: true)`.

```
┌──── Mitglied einladen ────────────────┐
│ E-Mail                                │
│ [__________________________]          │
│ Validation: RFC 5322 minimal, sonst   │
│ teamInviteEmailInvalid.               │
│                                       │
│ Rolle                                 │
│ ( ) Editor      (kann Daten ändern)   │
│ ( ) Beobachter  (nur Lesen)           │
│ ( ) Admin       (nur Owner ab Team)   │  ← conditional
│                                       │
│      [Abbrechen]      [Einladen]      │
└───────────────────────────────────────┘

Erfolg → Bottom-Sheet (zweites Sheet, ersetzt erstes):
┌────────────────────────────────────────┐
│ Einladung erstellt                     │
│ Sende diesen Link an dein Teammitglied:│
│ https://app.kerami.de/invites/<token>  │
│        [Link kopieren]                 │
│ → Snack `teamInviteCopyLinkSnack`      │
│ Bei Clipboard-Failure (z.B. Web mit    │
│ verweigerter Permission):              │
│ → Snack `teamInviteCopyFailed`         │
│                                        │
│ Hinweis: E-Mail-Versand kommt mit der  │
│ nächsten Version.                      │
└────────────────────────────────────────┘
```

**Conditional Admin-Option:**

- Sichtbar nur wenn `currentRole == owner && billing.currentPlan.rank >= BillingPlan.team.rank`.
- Sonst nur Editor + Beobachter angezeigt.
- Falls Plan < Team UND User ist Owner → Admin-Option wird
  disabled angezeigt mit Tooltip `teamInviteAdminLockedTooltip`.

**Wire-Format-Hinweis:** Wenn User „Editor" wählt, sendet
`createInvite` `role: WorkspaceRole.editor.apiName` → das ist
weiterhin `'member'` (siehe Blocker 7).

### Member-Row-Action (Rollen-Wechsel)

Tap auf Member-Row (oder Settings-Icon) → Bottom-Sheet:

```
┌──── Rolle für „Anna" ────────┐
│ ( ) Editor                   │
│ ( ) Beobachter               │
│ ( ) Admin   (ab Plan Team)   │
│                              │
│ [Mitglied entfernen]         │ ← rot (AppTheme.error)
└──────────────────────────────┘
```

Tap auf „Mitglied entfernen" → öffnet `MemberRemoveConfirmDialog`
(siehe unten, Blocker 10) — nicht direkt löschen.

Während des Rollen-Wechsel-Calls (Service-Roundtrip): Bottom-Sheet
zeigt Spinner mit Text `teamMemberRoleChangeLoading`.

### Member-Remove-Confirm-Dialog (`lib/widgets/member_remove_confirm_dialog.dart`) [NEW, Blocker 10]

```dart
AlertDialog(
  title: Text(l10n.teamMemberRemoveConfirmTitle),
  content: Text(l10n.teamMemberRemoveConfirmBody(email)),
  actions: [
    TextButton(
      onPressed: () => Navigator.pop(context, false),
      child: Text(l10n.commonCancel),
    ),
    TextButton(
      style: TextButton.styleFrom(foregroundColor: AppTheme.error),
      onPressed: () => Navigator.pop(context, true),
      child: Text(l10n.teamMemberRemove),
    ),
  ],
)
```

Default-Focus = Cancel (Cupertino/Material-Defaults), destruktive
Aktion ist die zweite Choice.

## l10n-Keys-Liste (Blocker 12 — auf 42 Keys erweitert)

Ergänzungen in `lib/l10n/app_de.arb` UND `lib/l10n/app_en.arb`:

| Key | DE | EN |
|---|---|---|
| `teamRoleEditor` | Editor | Editor |
| `teamRoleObserver` | Beobachter | Observer |
| `teamRoleEditorHint` | Kann Daten lesen und bearbeiten. | Can read and edit data. |
| `teamRoleObserverHint` | Nur Leserechte. | Read-only access. |
| `teamRoleOwnerHint` | Kann alles im Workspace, inkl. löschen. | Full access including deletion. |
| `teamRoleAdminHint` | Kann einladen und Carrier-Keys pflegen. | Can invite and manage carrier keys. |
| `teamWorkspacesTitle` | Workspaces | Workspaces |
| `teamWorkspacesEmpty` | Du hast noch keinen Team-Workspace. | You have no team workspace yet. |
| `teamWorkspacesActiveLabel` | Aktiv | Active |
| `teamWorkspacesActiveBadgeTooltip` | Dieser Workspace ist aktuell aktiv. | This workspace is currently active. |
| `teamWorkspacesCreate` | Neuer Workspace | New workspace |
| `teamWorkspacesCreateTitle` | Neuen Workspace anlegen | Create new workspace |
| `teamWorkspacesCreateLabel` | Name | Name |
| `teamWorkspacesCreateHint` | z. B. Acme GmbH | e.g. Acme Ltd. |
| `teamWorkspacesCreateValidationLength` | 1–80 Zeichen erforderlich. | 1–80 characters required. |
| `teamWorkspacesCreateSubmit` | Anlegen | Create |
| `teamWorkspacesCreateSuccess` | Workspace ‚{name}' angelegt. | Workspace ‚{name}' created. |
| `teamWorkspacesCreateFailed` | Anlegen fehlgeschlagen: {error} | Create failed: {error} |
| `teamWorkspacesPlanUsage` | Plan {plan}: {used}/{limit} Workspaces | Plan {plan}: {used}/{limit} workspaces |
| `teamWorkspacesPlanUsageUnlimited` | Plan {plan}: {used} Workspaces (unbegrenzt) | Plan {plan}: {used} workspaces (unlimited) |
| `teamWorkspacesLimitReachedTitle` | Limit erreicht | Limit reached |
| `teamWorkspacesLimitReachedBody` | Dein Plan {plan} erlaubt {limit} Workspaces. Upgrade, um weitere anzulegen. | Your plan {plan} allows {limit} workspaces. Upgrade to create more. |
| `teamWorkspacesLimitReachedCta` | Plan upgraden | Upgrade plan |
| `teamWorkspacesSwitchTo` | Wechseln | Switch |
| `teamRenamePersonalWarn` | Dies ist dein Personal-Workspace. Sicher umbenennen? | This is your personal workspace. Rename anyway? |
| `teamInviteEmailInvalid` | Bitte gültige E-Mail-Adresse eingeben. | Please enter a valid email address. |
| `teamInviteRoleEditor` | Editor | Editor |
| `teamInviteRoleObserver` | Beobachter | Observer |
| `teamInviteRoleAdminGated` | Admin (ab Plan Team) | Admin (Team plan and up) |
| `teamInviteAdminLockedTooltip` | Admin-Rolle ist ab Plan Team verfügbar. | Admin role requires Team plan or higher. |
| `teamInviteCreatedTitle` | Einladung erstellt | Invite created |
| `teamInviteShareBody` | Sende diesen Link an dein Teammitglied: | Share this link with your teammate: |
| `teamInviteCopyLink` | Link kopieren | Copy link |
| `teamInviteCopyLinkSnack` | Einladungs-Link kopiert. | Invite link copied. |
| `teamInviteCopyFailed` | Link konnte nicht kopiert werden. Bitte manuell markieren. | Link could not be copied. Please select manually. |
| `teamInviteShareEmailHint` | E-Mail-Versand kommt in der nächsten Version. | E-mail dispatch ships with the next version. |
| `teamMemberRoleChangeTitle` | Rolle für {email} | Role for {email} |
| `teamMemberRoleChangeLoading` | Rolle wird aktualisiert… | Updating role… |
| `teamMemberRoleChangeSuccess` | Rolle aktualisiert. | Role updated. |
| `teamMemberRoleChangeFailed` | Rolle ändern fehlgeschlagen: {error} | Role change failed: {error} |
| `teamMemberRemove` | Mitglied entfernen | Remove member |
| `teamMemberRemoveConfirmTitle` | Mitglied wirklich entfernen? | Really remove member? |
| `teamMemberRemoveConfirmBody` | „{email}" verliert sofort den Zugriff auf den Workspace. | "{email}" will lose access to the workspace immediately. |
| `helpWorkspacesHowManyTitle` | Wie viele Workspaces darf ich anlegen? | How many workspaces can I create? |
| `helpWorkspacesHowManyBody` | (siehe Help-Sektion unten) | (see Help section below) |
| `helpInviteHowTitle` | Wie lade ich jemanden ein? | How do I invite someone? |
| `helpInviteHowBody` | (siehe Help-Sektion unten) | (see Help section below) |
| `helpRolesEditorObserverTitle` | Welche Rollen gibt es? | Which roles exist? |
| `helpRolesEditorObserverBody` | (siehe Help-Sektion unten) | (see Help section below) |

**Re-Use existierender Keys** (nicht neu anlegen):

- `teamRoleOwner`, `teamRoleAdmin` — bleiben.
- `teamInviteTitle`, `teamInviteEmailLabel`, `teamInviteRoleLabel`,
  `teamInvite`, `teamInviteFailed`, `teamInviteRevoke`,
  `teamInviteExpires` — bleiben.
- `commonCancel`, `commonOk` — bleiben.

**Deprecated** (bleiben im ARB, werden aber nicht mehr aus UI gerendert):

- `teamRoleMember` — wird durch `teamRoleEditor` ersetzt. Bleibt für
  Audit-Texte / Debug.
- `teamRoleViewer` — wird durch `teamRoleObserver` ersetzt. Bleibt für
  Audit-Texte / Debug.

## UI-Änderungen (Files)

### Neu

- `lib/widgets/create_workspace_dialog.dart` — Bottom-Sheet mit
  TextField + Plan-Usage-Info + Submit. Wirft auf
  `WorkspaceLimitException` einen Folge-`LimitReachedDialog`
  (Blocker 8 + 9).
- `lib/widgets/invite_member_dialog.dart` — Refactor aus dem inline-
  Dialog im `_TeamTabState._invite` heraus, als Bottom-Sheet
  (Blocker 8). Erweitert um Editor/Beobachter-Labels via
  `lib/utils/role_labels.dart`, Admin-Conditional, Token-Link-Sheet
  bei Erfolg.
- `lib/widgets/limit_reached_dialog.dart` — AlertDialog mit
  Upsell-CTA → `PricingScreen` (Blocker 9).
- `lib/widgets/member_remove_confirm_dialog.dart` — AlertDialog mit
  destruktivem Button (`AppTheme.error`), Default = Cancel (Blocker 10).
- `lib/widgets/workspace_switcher.dart` — Wiederverwendbares Widget,
  das in Team-Tab + (optional Folge-Plan) im AppBar/Header verwendbar
  ist. Mobile-First: vertikale Card-Liste statt Dropdown auf Phone.
- `lib/utils/role_labels.dart` — Single-Source l10n-Mapping (V1).

### Geändert

- `lib/screens/settings_screen.dart` — `_TeamTab` Refactor:
  - Switcher-Widget oberhalb der Member-Liste einsetzen.
  - „Neuer Workspace"-Button: IMMER enabled. Bei Limit-Check
    `LimitReachedDialog` öffnen (Blocker 9).
  - Personal-Workspace-Rename: Confirm-Dialog vorschalten (D3, via
    `workspace.isPersonal`).
  - Member-Row: Trailing-Icon öffnet Bottom-Sheet mit Rollen-Radio +
    „Entfernen". Inline-Remove-Button entfernt; Tap auf „Entfernen"
    öffnet `MemberRemoveConfirmDialog` (Blocker 10).
  - Role-Labels: `_roleLabel` Mapping ersetzt durch
    `roleLabel(r, l10n)` aus `lib/utils/role_labels.dart` (V1).
  - Enum-Updates: `WorkspaceRole.member` → `WorkspaceRole.editor`,
    `WorkspaceRole.viewer` → `WorkspaceRole.observer` (Blocker 7).
- `lib/widgets/invites_bell.dart` — Enum-Updates (Blocker 7) +
  `roleLabel`-Call statt inline-Map (V1).
- `lib/screens/help_screen.dart` — 3 neue FAQ-Sektionen.
- `lib/models/workspace.dart` — Enum-Rename + `isPersonal`-Feld.
- `lib/models/billing_profile.dart` — `workspaceLimit`-Getter (D2).
- `lib/services/workspace_service.dart` — `createWorkspace` +
  `WorkspaceLimitException`.
- `lib/providers/active_workspace_provider.dart` — `createAndSwitchTo`
  (Blocker 11, in-memory anhängen, kein full reload).

## Help-Updates (Sections)

In `lib/screens/help_screen.dart` ergänzen, Insertion in die bestehende
„Workspace & Rollen"-Sektion (Suche nach `helpWorkspaceRolesTitle`):

### FAQ „Wie viele Workspaces darf ich anlegen?"

DE-Body:

> Free + Solo: 1 Workspace (dein Personal-Workspace).
> Solo Pro: 2 Workspaces — trenne privat und geschäftlich.
> Team: 5 Workspaces — z. B. ein Workspace pro Kunde.
> Business: 20 Workspaces.
> Enterprise: unbegrenzt.
> Über „Einstellungen → Team → Neuer Workspace" legst du einen
> neuen Workspace an. Wenn dein Limit erreicht ist, schlägt die App
> dir den passenden Upgrade-Plan vor.

EN-Body: analog.

### FAQ „Wie lade ich jemanden ein?"

DE-Body:

> 1. Öffne „Einstellungen → Team".
> 2. Stelle sicher, dass der gewünschte Workspace aktiv ist.
> 3. Tippe auf „Mitglied einladen".
> 4. E-Mail-Adresse eintragen, Rolle wählen (Editor oder Beobachter),
>    „Einladen" tippen.
> 5. Kopiere den Einladungs-Link aus dem Bestätigungs-Sheet und
>    schicke ihn manuell. Automatischer E-Mail-Versand kommt mit der
>    nächsten Version.
> Die Einladung ist 14 Tage gültig. Der Empfänger muss sich mit
> derselben E-Mail-Adresse anmelden, an die der Link gerichtet ist.

EN-Body: analog.

### FAQ „Welche Rollen gibt es?"

DE-Body:

> - **Owner** — kann alles, inklusive Workspace umbenennen, Mitglieder
>   kicken und Carrier-Keys pflegen. Pro Workspace genau ein Owner.
> - **Admin** — kann einladen, Daten ändern, Carrier-Keys pflegen.
>   Kann den Workspace nicht löschen. Verfügbar ab Plan **Team**.
> - **Editor** — kann Daten lesen und bearbeiten, aber keine
>   Mitglieder einladen oder Team-Einstellungen ändern.
> - **Beobachter** — Read-only. Sieht alle Daten, kann aber nichts
>   ändern. Nützlich für Steuerberater oder externe Reviewer.

EN-Body: analog. **Der ursprüngliche „intern heißt es member/viewer"-
Hinweis ist gestrichen** (Blocker 7: Dart-Layer maskiert das jetzt
vollständig).

## Page-Registry-Update

In `.claude/agents/_page-registry.md` Sub-Routes-Tabelle ergänzen
(alphabetisch in den existierenden Block einfügen):

| Trigger | File | Pflicht-Tests |
|---|---|---|
| `/settings` → Create-Workspace-Sheet | `lib/widgets/create_workspace_dialog.dart` | smoke-theme, mobile-overflow, smoke-team-create |
| `/settings` → Invite-Member-Sheet | `lib/widgets/invite_member_dialog.dart` | smoke-theme, mobile-overflow, smoke-team-invite |
| `/settings` → Limit-Reached-Dialog | `lib/widgets/limit_reached_dialog.dart` | smoke-theme, smoke-team-limit |
| `/settings` → Member-Remove-Confirm | `lib/widgets/member_remove_confirm_dialog.dart` | smoke-theme, mobile-overflow |

Bestehende Notiz zu `_TeamTab` (in `/settings`) ergänzen um:
„Workspace-Switcher + Create-Button (Plan-gated). Personal-Rename via
Confirm-Dialog."

## Tests

### Unit (Service-Layer, Mock-SupabaseClient)

`test/workspace_service_test.dart` (Ergänzung):

- `createWorkspace` happy path → Workspace-Objekt zurück (inkl.
  `isPersonal == false`).
- `createWorkspace` mit Empty-String → `ArgumentError`.
- `createWorkspace` bei `PostgrestException(message: 'workspace_limit_reached')`
  → `WorkspaceLimitException` mit Hint propagiert.
- `createWorkspace` bei `PostgrestException(message: 'not_authenticated')`
  → rethrow.
- `WorkspaceRole.fromApi('member')` → `editor`, `fromApi('viewer')`
  → `observer`, `fromApi('garbage')` → `observer` (safe fallback).
- `WorkspaceRole.editor.apiName` → `'member'`,
  `WorkspaceRole.observer.apiName` → `'viewer'` (Wire-Stability).

`test/workspace_limits_test.dart` (NEU):

- Parametrisierte Tests über alle 6 `BillingPlan`-Werte:
  - free → 1, solo → 1, soloPro → 2, team → 5, business → 20,
    enterprise → -1.
- Test-Name dokumentiert die DB-Migration als Source-of-Truth.
- Drift-Test SQL↔Dart ist als V4 (Folge-Issue) notiert.

### Widget

`test/widgets/invite_member_dialog_test.dart` (NEU):

- Renders Editor + Beobachter Radio-Options.
- Admin-Option ist disabled wenn `currentPlan.rank < team.rank`
  (BillingProvider gemockt).
- Submit mit leerer Email → Submit-Button disabled.
- Submit mit ungültiger Email → SnackBar `teamInviteEmailInvalid`.
- Submit → `WorkspaceService.createInvite` wird mit `role: 'member'`
  aufgerufen, wenn UI „Editor" gewählt war (apiName-Aliasing-Smoke).
- Erfolg → Bottom-Sheet mit Token-Link sichtbar; „Link kopieren"
  → Clipboard-Spy verifiziert. Bei Clipboard-Failure → Snack
  `teamInviteCopyFailed`.

`test/widgets/create_workspace_dialog_test.dart` (NEU):

- TextField akzeptiert 1–80 Zeichen, Submit disabled bei 0 / >80.
- Submit ruft `ActiveWorkspaceProvider.createAndSwitchTo` mit
  getrimmtem Name auf.
- `WorkspaceLimitException` rendert `LimitReachedDialog` mit
  CTA-Button („Plan upgraden") → Navigator-Push auf `PricingScreen`
  wird verifiziert (Mock-Navigator).
- Mobile-Viewport 360×640: kein vertikaler Overflow bei eingeblendeter
  Keyboard-Mock (MediaQuery.viewInsets).

### Smoke (Browser-Tester)

Neue Szenarien:

- `smoke-team-create` — Login → Settings → Team → „Neuer Workspace"
  → Name eingeben → Submit → SnackBar erscheint → Switcher zeigt
  neuen WS aktiv. **Phone-Viewport 390×844 + iOS-Keyboard-Simulation
  (Pflicht-Akzeptanz Blocker 8).**
- `smoke-team-invite` — Login → Settings → Team → „Einladen" →
  Email + „Editor" → Submit → Sheet mit Link → „Link kopieren" →
  Clipboard-Wert geprüft. Phone-Viewport.
- `smoke-team-limit` — Login als Free-User (hat bereits 1 WS) →
  Settings → Team → „Neuer Workspace" → Button ist enabled, Tap →
  `LimitReachedDialog` erscheint mit Plan-Name + Limit + CTA
  „Plan upgraden". CTA-Tap → PricingScreen ist sichtbar.

### Wo NICHT getestet

- Live-Supabase: nicht in Unit-Tests. RPC-Behavior wird durch das
  Migration-Skript abgedeckt + manueller `supabase db reset`-Run
  vor Commit (Gate in T0–T3).
- Mail-Versand: out-of-scope (D4).
- `setPlan` REVOKE-Verhalten: nicht relevant in diesem Plan (D7/R10).

## Implementation-Order (atomare Tasks mit `depends_on`)

> Jeder Task = 1 PR-fähiges Increment. `depends_on` ist verbindlich.

- [ ] **T0 — DB-Migration `billing_plan_realign`** (Blocker 1)
  - Subagent: `db-migrator`
  - Files: `supabase/migrations/20260520000000_billing_plan_realign.sql`
  - depends_on: []
  - Gate: `supabase db reset` läuft grün; `psql -c "SELECT DISTINCT plan FROM billing_profiles"` zeigt nur Werte aus dem neuen CHECK; `psql -c "\d billing_profiles"` zeigt den neuen CHECK.

- [ ] **T1 — DB-Migration `workspaces_rls_split`** (Blocker 2)
  - Subagent: `db-migrator`
  - Files: `supabase/migrations/20260520000050_workspaces_rls_split.sql`
  - depends_on: [T0]
  - Gate: `supabase db reset` läuft grün; `psql` testet, dass ein direkter `INSERT INTO workspaces` als `authenticated`-User mit `RAISE EXCEPTION` (RLS-Deny) scheitert.

- [ ] **T2 — DB-Migration `workspace_is_personal`** (Blocker 5)
  - Subagent: `db-migrator`
  - Files: `supabase/migrations/20260520000150_workspace_is_personal.sql`
  - depends_on: [T1]
  - Gate: `supabase db reset` läuft grün; Backfill-Check: für jeden existing owner_id ist genau 1 WS mit `is_personal=TRUE`; Trigger-Re-Test: neuer Auth-User → neue WS mit `is_personal=TRUE`.

- [ ] **T3 — DB-Migration `workspace_create_rpc` + `workspace_limit_for_plan` + Advisory-Lock** (Blocker 4)
  - Subagent: `db-migrator`
  - Files: `supabase/migrations/20260520000200_workspace_create_rpc.sql`
  - depends_on: [T2]
  - Gate: `supabase db reset` läuft grün; `psql` testet: free-User mit 1 WS → `RAISE EXCEPTION 'workspace_limit_reached'`; team-User mit 5 WS → 6. INSERT scheitert; parallel-create-Smoke (2 concurrent calls für free-User) → genau 1 succeeds.

- [ ] **T4 — DB-Migration `workspace_role_labels`** (Living-Doc, optional)
  - Subagent: `db-migrator`
  - Files: `supabase/migrations/20260520000300_workspace_role_labels.sql`
  - depends_on: [T3]
  - Gate: `supabase db reset` läuft grün.

- [x] **T5 — `WorkspaceRole`-Enum-Rename + `isPersonal`-Field** (Blocker 7)
  - Subagent: `flutter-coder`
  - Files: `lib/models/workspace.dart`, `lib/widgets/invites_bell.dart`, `lib/screens/settings_screen.dart` (alle `WorkspaceRole.member|viewer`-Sites)
  - depends_on: [T0]  *(T0 reicht — Enum-Rename ist DB-unabhängig, aber wir wollen die Pre-T0-DB nicht mit alten Plan-Werten zurücklassen.)*
  - Gate: `dart analyze lib/` ohne Errors; bestehende Tests grün.

- [x] **T6 — `BillingPlan.workspaceLimit` + Unit-Tests** (D2)
  - Subagent: `flutter-coder`
  - Files: `lib/models/billing_profile.dart`, `test/billing_plan_workspace_limit_test.dart`
  - depends_on: [T5]
  - Gate: `flutter test test/billing_plan_workspace_limit_test.dart` grün.

- [x] **T7 — `WorkspaceService.createWorkspace` + `WorkspaceLimitException`**
  - Subagent: `flutter-coder`
  - Files: `lib/services/workspace_service.dart`, `test/workspace_create_test.dart`
  - depends_on: [T3, T6]
  - Gate: `flutter test test/workspace_create_test.dart` grün.

- [x] **T8 — `ActiveWorkspaceProvider.createAndSwitchTo`** (Blocker 11)
  - Subagent: `flutter-coder`
  - Files: `lib/providers/active_workspace_provider.dart`
  - depends_on: [T7]
  - Gate: `dart analyze lib/providers/` ohne Errors.

- [x] **T9 — `lib/utils/role_labels.dart` Extract** (V1)
  - Subagent: `flutter-coder`
  - Files: `lib/utils/role_labels.dart`
  - depends_on: [T5]
  - Gate: `dart analyze lib/utils/role_labels.dart`.

- [ ] **T10 — `CreateWorkspaceDialog` als Bottom-Sheet** (Blocker 8)
  - Subagent: `ui-builder`
  - Files: `lib/widgets/create_workspace_dialog.dart`, `test/widgets/create_workspace_dialog_test.dart`, `lib/l10n/app_de.arb`, `lib/l10n/app_en.arb`
  - depends_on: [T8, T9]
  - Gate: Widget-Test grün, `flutter gen-l10n` rauscht durch, Mobile-Viewport 360×640 + iOS-Keyboard-Sim ohne Overflow.

- [ ] **T11 — `InviteMemberDialog` Refactor als Bottom-Sheet + Editor/Beobachter** (Blocker 8 + Blocker 7)
  - Subagent: `ui-builder`
  - Files: `lib/widgets/invite_member_dialog.dart`, `test/widgets/invite_member_dialog_test.dart`, `lib/l10n/app_de.arb`, `lib/l10n/app_en.arb`, `lib/screens/settings_screen.dart` (Inline-Dialog raus)
  - depends_on: [T9]
  - Gate: Widget-Test grün; Admin-Conditional via BillingProvider-Mock geprüft; Mobile-Viewport-Akzeptanz.

- [ ] **T12 — `WorkspaceSwitcher` Widget**
  - Subagent: `ui-builder`
  - Files: `lib/widgets/workspace_switcher.dart`, `lib/l10n/app_de.arb`, `lib/l10n/app_en.arb`
  - depends_on: [T8]
  - Gate: `flutter analyze`, manueller Phone+Desktop-Viewport-Check; `is_personal`-Badge sichtbar.

- [ ] **T13 — `LimitReachedDialog`** (Blocker 9)
  - Subagent: `ui-builder`
  - Files: `lib/widgets/limit_reached_dialog.dart`, `lib/l10n/app_de.arb`, `lib/l10n/app_en.arb`
  - depends_on: [T6]
  - Gate: `flutter analyze`; manueller CTA-Push-Test.

- [ ] **T14 — `MemberRemoveConfirmDialog`** (Blocker 10)
  - Subagent: `ui-builder`
  - Files: `lib/widgets/member_remove_confirm_dialog.dart`, `lib/l10n/app_de.arb`, `lib/l10n/app_en.arb`
  - depends_on: [T9]
  - Gate: `flutter analyze`; Widget-Smoke optional.

- [ ] **T15 — Settings → Team-Tab Integration**
  - Subagent: `ui-builder`
  - Files: `lib/screens/settings_screen.dart`, `lib/l10n/app_de.arb`, `lib/l10n/app_en.arb`
  - depends_on: [T10, T11, T12, T13, T14]
  - Gate: `flutter analyze`; Phone+Desktop-Viewport-Check; Personal-Rename-Confirm sichtbar; Member-Remove-Confirm sichtbar.

- [ ] **T16 — Help-Screen FAQ-Sektionen**
  - Subagent: `ui-builder`
  - Files: `lib/screens/help_screen.dart`, `lib/l10n/app_de.arb`, `lib/l10n/app_en.arb`
  - depends_on: [T15]
  - Gate: `/check-l10n` (kein TODO en, keine fehlenden Keys).

- [ ] **T17 — Page-Registry + Handbook Doku-Update**
  - Subagent: `doc-updater` (oder manuell)
  - Files: `.claude/agents/_page-registry.md`, `docs/handbook/03-screens-walkthrough.md`, `docs/handbook/05-architecture.md`, `docs/handbook/06-database.md`
  - depends_on: [T15, T16]
  - Gate: `grep` zeigt neue Sub-Route-Einträge in `_page-registry.md`; Handbook-Sektionen für `is_personal`, `workspace_limit_for_plan`, RLS-Split sind ergänzt.

- [ ] **T18 — Browser-Smoke: `smoke-team-create`, `smoke-team-invite`, `smoke-team-limit`, `smoke-full-app-audit`**
  - Subagent: `browser-tester`
  - Files: `.claude/test-runs/<ts>/...` (generiert)
  - depends_on: [T17]
  - Gate: `Result: passed` für alle 3 Szenarien auf Phone-Viewport; aktueller (< 24h) `smoke-full-app-audit`-Pass für Merge auf main.

## Risiken

- **R1 — RPC-Roundtrip langsamer als direkter INSERT.** Mitigation:
  irrelevant (Create-Workspace ist seltener Action; +50ms toleriert).
- **R2 — Plan-Limit-Drift Dart ↔ Postgres.** Bei Plan-Restruktur müssen
  beide Stellen geupdated werden. Mitigation: T6-Unit-Test dokumentiert
  die Tabelle; Folge-Issue V4 plant automatisierten SQL↔Dart-Test.
- **R3 — Personal-Workspace-Rename verwirrt User.** Mitigation: D3-
  Confirm-Dialog + `is_personal`-Spalte als stabiler Indikator.
- **R4 — Audit-Log fehlt für create/invite/role_change.** Tabelle
  existiert, aber kein Write. Out-of-Scope hier — wenn Compliance-
  Anforderung wächst, dedicated Plan.
- **R5 — Token-Link in UI = User muss manuell senden.** Pre-Launch
  vertretbar. Mitigation: Help-FAQ erklärt, Bottom-Sheet sagt es,
  Folge-Plan plant Mail-Versand (siehe V5 für
  `supabase.auth.admin.generateLink`-Hinweis).
- **R6 — `deleted_at`-Mutation-Guard-Trigger fehlt.** Council schlug
  einen Trigger vor, der UPDATEs auf `deleted_at` außerhalb
  SECURITY-DEFINER-Kontexten blockiert. **Entscheidung:** Vertagt
  auf den Soft-Delete-UI-Folge-Plan. Begründung: dieser Plan baut
  KEINE UI für Workspace-Löschen; `deleted_at` wird heute nur durch
  Migrationen / manuelle SQL-Edits gesetzt; ein präventiver Trigger
  würde testbar nur als Smoke laufen, weil es keinen App-Pfad gibt.
  Wenn der Soft-Delete-Flow gebaut wird, kommt der Trigger
  garantiert mit (Reference: Spec-Snippet im Council-Blocker-6).
- **R7 — `accept_workspace_invite` Race.** Council schlug
  `SELECT … FOR UPDATE` auf invite-Row vor. Mitigation: bestehender
  RPC bleibt unverändert in diesem Plan; Race-Härtung als Folge-Issue
  notiert (V2).
- **R8 — Existing inline `_invite`-Dialog im SettingsScreen wird
  durch T11 extrahiert.** Risiko: Regression beim Refactor. Mitigation:
  Widget-Test deckt Submit-Pfad; manueller Smoke in T18.
- **R9 — Mobile-Overflow im neuen Switcher auf 360×640 (kleinster
  Phone).** Mitigation: T12 testet auf 360 + 390; Cards statt
  Dropdown; T10/T11 prüfen Keyboard-Sim mit `viewInsetsOf`.
- **R10 — `BillingService.setPlan` macht direkten UPDATE auf
  `billing_profiles.plan`** (D7). Der ursprünglich vom Council
  vorgeschlagene REVOKE der `plan`-Spalten-UPDATE-Rechte wird in
  diesem Plan NICHT umgesetzt, weil das den Pre-Launch-Upgrade-Flow
  bricht. Pre-Launch ohne echtes Billing → akzeptables Restrisiko.
  Folge-Plan (Stripe-Webhook): `setPlan` → SECURITY DEFINER RPC,
  dann REVOKE durchführen.
- **R11 — Provider-Cache wird nach Workspace-Switch nicht
  invalidiert.** Andere Provider (InventoryProvider, DealsProvider,
  …) halten ggf. Daten des alten Workspace im Memory. Mitigation:
  Out-of-Scope dieses Plans; siehe V3 (Folge-Issue „Provider-Cache-
  Clear-Signal bei Workspace-Switch").

## Verbesserungen (nicht-blockierend, dokumentiert)

- **V1 — `lib/utils/role_labels.dart` als Single-Source.** Implementiert
  in T9; konsumiert von T10, T11, T14, T15.
- **V2 — `accept_workspace_invite` Race-Härtung** (`SELECT … FOR UPDATE`
  auf invite-Row) — Folge-Plan, siehe R7.
- **V3 — Provider-Cache-Clear-Signal bei Workspace-Switch** — Folge-
  Plan, siehe R11. In diesem Plan kein neuer Code; wird als R-Eintrag
  dokumentiert.
- **V4 — Drift-Test SQL ↔ Dart `workspace_limit`** — automatisierter
  Test (z. B. via `dart` runscript, der `psql -c "SELECT workspace_limit_for_plan('solo')"`
  aufruft und mit `BillingPlan.solo.workspaceLimit` vergleicht). Folge-
  Issue, weil zusätzliche CI-Plumbing nötig wäre.
- **V5 — `supabase.auth.admin.generateLink({type: 'invite'})`-Pfad**
  für späteren Invite-Mail-Versand (D4-Folge). Vermerk im
  `plans/<future>_invite_email_dispatch.md`-Folge-Plan.

## Rollback-Strategie

1. **DB:**
   - T0 (`billing_plan_realign`): Rollback würde alte Plan-Werte
     wiederherstellen müssen → Restore-Script `UPDATE … SET plan = 'starter' WHERE plan = 'solo'`
     + alter CHECK-Constraint. Nur Pre-Launch akzeptabel.
   - T1 (`rls_split`): Rollback via `DROP POLICY workspaces_owner_update; DROP POLICY workspaces_owner_delete; CREATE POLICY workspaces_owner_write FOR ALL …`.
   - T2 (`is_personal`): Rollback via `ALTER TABLE workspaces DROP COLUMN is_personal;`
     — Trigger-Function kann ohne `is_personal` weiter funktionieren
     (CREATE OR REPLACE FUNCTION ohne `is_personal`-Insert).
   - T3 (`create_workspace`): Rollback via `DROP FUNCTION public.create_workspace(TEXT); DROP FUNCTION public.workspace_limit_for_plan(TEXT);`.
   - T4 (`role_labels`): Reine COMMENT-Migration — kein Rollback nötig.
2. **Dart:** `git revert <merge-commit>`. Da der Personal-Workspace-
   Trigger und alle bestehenden RPCs unverändert bleiben (außer der
   `is_personal`-Erweiterung, die rückwärtskompatibel ist), läuft die
   App ohne diesen Plan weiter.
3. **L10n:** Neue Keys lassen sich `flutter gen-l10n`-frisch wieder
   herausnehmen. Kein Daten-Schaden.

## Bestätigte Annahmen

- Es gibt **noch keine** Edge-Function für Invite-Mails (`supabase/functions/`-Liste enthält keine entsprechende). → D4 ist konsistent.
- `provision_personal_workspace`-Trigger läuft pro neuem auth-User → jeder hat mind. 1 Workspace, daher `workspace_limit_for_plan('free') = 1` ist „bereits voll" beim Versuch, einen zweiten zu erstellen. → Free-Limit-Test bei T18 ist sinnvoll.
- `BillingService.setPlan` macht heute direkten UPDATE — REVOKE würde brechen (verifiziert in `lib/services/billing_service.dart:50-71`). → D7 / R10.
- `workspaces_owner_write FOR ALL` erlaubt heute direkten Client-INSERT mit `owner_id = auth.uid()` (verifiziert in `supabase/migrations/20260504000200_workspaces.sql:94-95`). → D6 / Blocker 2 real.
- Dart-Enum `BillingPlan` mappt schon `starter → solo`, `pro → soloPro`, `ultimate → enterprise` (verifiziert in `lib/models/billing_profile.dart:31-43`). → T0 ist der DB-Realign passend dazu.

## Confidence

**medium** — Architektur ist solide (RPC + Limit-Lookup + Advisory-
Lock + RLS-Split + `is_personal`-Flag), aber das UI hat 4
zusammenhängende Touchpoints (Switcher, Create-Sheet, Invite-Sheet,
Role-Sheet + Remove-Confirm), die parallel sauber laufen müssen.
Mobile-Overflow auf 360px + iOS-Keyboard ist das Hauptrisiko (Blocker 8).
Enum-Rename (Blocker 7) hat Touch-Liste sauber dokumentiert, aber
mehrfaches Forgotten-Replace ist denkbar — Pre-Commit-grep auf
`WorkspaceRole\.\(member\|viewer\)` ist Pflicht.

Subagenten-Output-Review (CLAUDE.md §Subagent-Output-Review-Pflicht)
ist ab T7 zwingend (jeder Task > 50 Zeilen Diff).

## Effort

**~18 h** verteilt:
- DB ~3.5h (5 Migrations statt 2: T0–T4)
- Service/Provider ~2.5h (T5–T8)
- Utils ~0.5h (T9)
- Widgets ~6h (T10–T14, davon T10+T11 mit Bottom-Sheet-Refactor je 1.5h)
- Settings-Integration ~2h (T15)
- l10n+Help ~1h (T16)
- Tests ~1.5h
- Doku ~0.5h (T17)
- Smoke ~0.5h (T18)
