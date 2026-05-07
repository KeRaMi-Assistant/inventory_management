# Inbox: "Alle als gelesen markieren"

> Status: Plan
> Datum: 2026-05-07
> Branch (geplant): `feature/inbox-mark-all-read`

## Ziel

Den Nutzern eine Bulk-Aktion geben, mit der sie den gesamten Inbox-Bestand
(Vorschläge + matched + unklassifiziert) als "gesehen / abgehakt"
markieren können — ohne damit Vorschläge zu akzeptieren oder Mails zu
verwerfen. Der UI-Indicator (z.B. fette Card, ungelesen-Badge auf den
Tabs) soll sich dadurch leeren, die fachliche Resolve-Logik bleibt
unverändert.

## Begriffsabgrenzung — "gelesen" ist NICHT "verworfen"

Der bestehende Code kennt heute drei Zustände, aber **kein** Lese-Status:

| Aktion              | Mechanismus                                                                 | Effekt                                                                |
|---------------------|-----------------------------------------------------------------------------|-----------------------------------------------------------------------|
| **Akzeptieren**     | `pending_deal_suggestions.resolved_at` + `resolved_action='accepted'`       | Suggestion verschwindet aus Tab "Vorschläge".                         |
| **Verwerfen** (UI)  | `parsed_messages.status='dismissed'` *und* `inbox_dismissals` (Order/Msg-Key) | Eintrag verschwindet aus Inbox + zukünftige Mails werden gefiltert. |
| **(neu) Gelesen**   | `inbox_reads (workspace_id, parsed_message_id)` — *neu*                     | UI markiert Card als "gesehen", aber Eintrag bleibt im Tab.           |

Klar formuliert: **gelesen ≠ verworfen ≠ akzeptiert**. Wer auf "Alle als
gelesen" klickt, soll seine offenen Vorschläge und unklassifizierten
Mails NICHT verlieren — nur den Ungelesen-Indicator zurücksetzen.

## Betroffener Scope

- **DB:**
  - Neu: `supabase/migrations/20260507900000_inbox_reads.sql`
- **Models:**
  - `lib/models/inbox_message.dart` (neue Klasse `InboxRead` oder Field
    `bool isRead` an `ParsedMessage` / `PendingDealSuggestion` als
    Convenience).
- **Repository:**
  - `lib/services/supabase_repository.dart` — neue Methoden
    `loadInboxReads()`, `markAllInboxRead()`, optional
    `markInboxItemRead(...)`.
- **Provider:**
  - `lib/providers/inbox_provider.dart` — Set `_readKeys`, getter
    `unreadCount`, `unreadSuggestionsCount`, `unreadMatchedCount`,
    `unreadUnclassifiedCount`, Methode `markAllRead()`. `_recomputeViews`
    bleibt unverändert (Read-Status filtert nichts).
- **Screen:**
  - `lib/screens/inbox_screen.dart` — Button im `_InboxHeader`,
    Confirmation-Dialog, optional "ungelesen"-Badge an den drei Tabs,
    visueller Hinweis (FontWeight) auf ungelesenen Cards.
- **l10n:**
  - `lib/l10n/app_de.arb` + `lib/l10n/app_en.arb` — neue Keys
    (`inboxMarkAllRead`, `inboxMarkAllReadConfirmTitle`,
    `inboxMarkAllReadConfirmBody`, `inboxMarkAllReadSuccess`,
    `inboxMarkAllReadFailure`, `inboxUnreadBadge`).
- **Tests:**
  - `test/inbox_provider_test.dart` (neu oder erweitert) — Repository-Mock.

## Datenmodell

### Neue Tabelle `public.inbox_reads`

```sql
CREATE TABLE IF NOT EXISTS public.inbox_reads (
  workspace_id      UUID NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
  parsed_message_id UUID NOT NULL REFERENCES public.parsed_messages(id) ON DELETE CASCADE,
  read_by           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  read_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (workspace_id, parsed_message_id, read_by)
);

CREATE INDEX IF NOT EXISTS inbox_reads_ws_user_idx
  ON public.inbox_reads(workspace_id, read_by);

ALTER TABLE public.inbox_reads ENABLE ROW LEVEL SECURITY;
```

**Designentscheidungen:**

- Pro-User, nicht pro-Workspace: Wenn zwei Workspace-Member die Inbox
  ansehen, hat jeder seinen eigenen Lese-Zustand.
- Composite-PK statt synthetischer ID — effizientes Idempotency:
  `INSERT ... ON CONFLICT DO NOTHING` für Bulk-Mark.
- `parsed_message_id` als Anker: gilt sowohl für matched/unclassified als
  auch indirekt für Suggestions (jede `pending_deal_suggestions`-Zeile
  hat `parsed_message_id`). Eine Tabelle reicht.
- ON DELETE CASCADE: Wenn die parsed_message vom Cleanup-Cron entsorgt
  wird, fliegt der Read-Eintrag mit raus.

### RLS-Policies

```sql
DROP POLICY IF EXISTS inbox_reads_self_read ON public.inbox_reads;
CREATE POLICY inbox_reads_self_read ON public.inbox_reads FOR SELECT
  USING (
    read_by = auth.uid()
    AND public.is_workspace_member(workspace_id, auth.uid())
  );

DROP POLICY IF EXISTS inbox_reads_self_write ON public.inbox_reads;
CREATE POLICY inbox_reads_self_write ON public.inbox_reads FOR ALL
  USING (
    read_by = auth.uid()
    AND public.has_workspace_role(workspace_id, auth.uid(),
        ARRAY['owner','admin','member'])
  )
  WITH CHECK (
    read_by = auth.uid()
    AND public.has_workspace_role(workspace_id, auth.uid(),
        ARRAY['owner','admin','member'])
  );
```

### Bulk-Mark RPC

```sql
CREATE OR REPLACE FUNCTION public.mark_all_inbox_read(_workspace_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  inserted_count INTEGER;
BEGIN
  IF NOT public.is_workspace_member(_workspace_id, auth.uid()) THEN
    RAISE EXCEPTION 'Keine Berechtigung für Workspace %.', _workspace_id;
  END IF;

  WITH ins AS (
    INSERT INTO public.inbox_reads (workspace_id, parsed_message_id, read_by)
    SELECT pm.workspace_id, pm.id, auth.uid()
      FROM public.parsed_messages pm
     WHERE pm.workspace_id = _workspace_id
       AND pm.status IN ('matched','unclassified','suggested','pending')
       AND pm.received_at >= NOW() - INTERVAL '30 days'
    ON CONFLICT DO NOTHING
    RETURNING 1
  )
  SELECT COUNT(*) INTO inserted_count FROM ins;

  RETURN inserted_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_all_inbox_read(UUID) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.mark_all_inbox_read(UUID) TO authenticated;
```

### Cleanup

`cleanup_inbox_history()` muss nicht angefasst werden — `ON DELETE CASCADE`
regelt das automatisch.

## API / Edge Functions

Keine neue Edge Function nötig. Nur die oben definierte Postgres-RPC
`mark_all_inbox_read(_workspace_id)` und der Standard-`select`-Call für
`loadInboxReads()`.

## UI-Änderungen

### `_InboxHeader` (in `lib/screens/inbox_screen.dart`)

Neuer `IconButton` zwischen dem Dismiss-Filter-Button und dem
Refresh-Button:

- Icon: `Icons.mark_email_read_outlined`
- Tooltip: `l10n.inboxMarkAllRead` (z.B. "Alle als gelesen markieren ($unreadCount)")
- Disabled, wenn `unreadCount == 0` oder `provider.isLoading`
- onPressed: zeigt Confirm-Dialog → ruft `provider.markAllRead()` →
  SnackBar success/failure

### Tab-Badges (optional)

Die drei Tabs können neben `(N)` einen kleinen Dot zeigen, wenn
`unreadXxxCount > 0`. Implementierung als `Badge.count(...)` um die
`Tab`-Widgets. Wenn Layout in schmalen Screens bricht: verwerfen.

### Visueller Read-Marker auf Cards

Auf `_SuggestionCard`, `_MatchedTab`-ListTile und
`_UnclassifiedRow`-ListTile: wenn `provider.isUnread(parsedMessageId)`,
Title-Text in `FontWeight.w800` (statt w700) oder Card-Border in
`AppTheme.accent`. Nicht ausblenden.

### l10n-Keys (DE / EN)

| Key                              | DE                                                        | EN                                                              |
|----------------------------------|-----------------------------------------------------------|-----------------------------------------------------------------|
| `inboxMarkAllRead`               | "Alle als gelesen markieren"                              | "Mark all as read"                                              |
| `inboxMarkAllReadTooltip`        | "Alle als gelesen markieren ({count})"                    | "Mark all as read ({count})"                                    |
| `inboxMarkAllReadConfirmTitle`   | "Alle als gelesen markieren?"                             | "Mark all as read?"                                             |
| `inboxMarkAllReadConfirmBody`    | "{count} ungelesene Einträge werden als gelesen markiert. Vorschläge und Mails bleiben in der Inbox." | "{count} unread items will be marked as read. Suggestions and messages stay in the inbox." |
| `inboxMarkAllReadSuccess`        | "{count} Einträge als gelesen markiert."                  | "{count} items marked as read."                                 |
| `inboxMarkAllReadFailure`        | "Markieren fehlgeschlagen: {error}"                       | "Mark as read failed: {error}"                                  |
| `inboxUnreadBadge`               | "{count} neu"                                             | "{count} new"                                                   |

`{count}` mit ICU-Plural-Form falls Pattern bestehend, sonst Platzhalter.

## Tests

### Provider-Test (`test/inbox_provider_test.dart`)

- Repository-Mock liefert 3 parsed_messages + 2 suggestions.
- `loadInboxReads` initial leer → `unreadCount == 5`.
- `markAllRead()` → Repository-Aufruf mit Workspace-ID → `_readKeys`
  enthält alle 5 IDs → `unreadCount == 0` → notifyListeners genau
  einmal nach Erfolg.
- Nach erneutem `refresh()` werden Read-Status persistent geladen.
- Fehlerpfad: Repository wirft → State bleibt unverändert,
  `lastError` gesetzt.

### Migration-Test (manuell, lokal)

- `supabase db reset` muss durchlaufen.
- Insert eines parsed_message + RPC-Call → 1 Row in `inbox_reads`.
- Zweiter RPC-Call → ON CONFLICT, 0 neue Rows.
- DELETE der parsed_message → CASCADE räumt inbox_reads.

### Widget-Test (optional)

- Header zeigt Button disabled wenn `unreadCount==0`.
- Click → Confirm-Dialog → Confirm → Provider-Methode aufgerufen.

## Risiken

1. **Verwechslung mit "Verwerfen"**. Confirm-Dialog-Body macht das
   explizit klar ("bleiben in der Inbox").
2. **Lese-Status pro User vs. pro Workspace**: Wir wählen pro-User.
   Falls später anders gewünscht: kleine Folge-Migration (`read_by`
   aus PK rauswerfen).
3. **Performance bei großen Inboxen**: Workspace mit ~1000
   parsed_messages → RPC liefert ~1000 Inserts in einer Transaction.
   Akzeptabel bei rolling 30-Tage-Fenster.
4. **Race mit Inbox-Poll-Cron**: Während `mark_all_inbox_read` läuft,
   können neue parsed_messages reinkommen. Die werden im aktuellen
   Aufruf nicht erfasst — beim nächsten Refresh erscheinen sie als
   ungelesen. Korrekt und erwartet.
5. **Suggestions ohne parsed_message** existieren nicht (FK NOT NULL),
   kein Edge-Case dort.
6. **Migration auf Prod**: Pre-Launch — kein Risiko. Trotzdem
   `supabase db push` nicht automatisch (siehe CLAUDE.md).
7. **Dart-Provider-Doppel-Notify**: Nach `markAllRead` lokal Set füllen
   UND `notifyListeners()` ohne erneutes refresh, sonst flackert UI doppelt.

## Tasks

- [ ] **T1 — Migration `inbox_reads` + RLS + RPC** *(Subagent: `db-migrator`)*
  Datei: `supabase/migrations/20260507900000_inbox_reads.sql`. Tabelle,
  Indizes, RLS-Policies, RPC `mark_all_inbox_read(_workspace_id)`. Lokal
  `supabase db reset` testen.

- [x] **T2 — Model `InboxRead`** *(Subagent: `flutter-coder`)*
  In `lib/models/inbox_message.dart`: kleine Klasse mit
  `parsedMessageId` + `readAt`, `fromSupabase` Factory. Kein Behavior.

- [x] **T3 — Repository: loadInboxReads + markAllInboxRead** *(Subagent: `flutter-coder`)*
  In `lib/services/supabase_repository.dart`: zwei Methoden,
  Workspace-Scoped. RPC-Call `mark_all_inbox_read`.

- [x] **T4 — Provider: Read-State-Tracking** *(Subagent: `flutter-coder`)*
  In `lib/providers/inbox_provider.dart`: Field `_readMessageIds`
  (Set<String>), `isUnread(messageId)`, `unreadCount`,
  `unreadSuggestionsCount`, `unreadMatchedCount`,
  `unreadUnclassifiedCount`. Im `refresh()` Reads parallel laden
  (Future.wait erweitern). Methode `markAllRead()`: Repo-Call →
  Set-Update mit allen aktuell sichtbaren parsedMessageIds → notify.

- [ ] **T5 — l10n-Keys DE/EN** *(Subagent: `ui-builder`)*
  Neue Keys aus UI-Sektion in `app_de.arb` + `app_en.arb` + `@-Metadata`.
  `flutter gen-l10n` läuft per Hook.

- [ ] **T6 — UI: Mark-All-Read-Button im Header** *(Subagent: `ui-builder`)*
  In `_InboxHeader`: neuer IconButton (`Icons.mark_email_read_outlined`)
  vor dem Refresh-Button. Disabled wenn `unreadCount==0` oder
  `isLoading`. Confirm-Dialog mit l10n-Strings. SnackBar success/error.
  Folgt dem Pattern von `_confirmClearDismissals`.

- [x] **T7 — UI: Visueller Read-Marker auf Suggestion-Cards** *(Subagent: `ui-builder`)*
  In `_SuggestionCard.build`: wenn
  `context.read<InboxProvider>().isUnread(suggestion.parsedMessageId)`,
  Title-Text `FontWeight.w800` ODER Card-Border `AppTheme.accent`.

- [x] **T8 — UI: Read-Marker auf Matched + Unclassified ListTiles** *(Subagent: `ui-builder`)*
  Analog zu T7 in `_MatchedTab` und `_UnclassifiedRow`.

- [x] **T9 — UI: Tab-Badges für ungelesen-Counter** *(Subagent: `ui-builder`, optional)*
  An den drei `Tab`-Widgets: `Badge.count(...)`. Bei Layout-Konflikt
  verwerfen.

- [x] **T10 — Provider-Test** *(Subagent: `flutter-coder`)*
  Datei: `test/inbox_provider_test.dart`. Mock-Repository ohne externe
  Mock-Pakete. Cases siehe Tests-Sektion.

- [ ] **T11 — Migration-Smoke-Test lokal** *(Subagent: `db-migrator`)*
  `supabase db reset` + händischer Test-Insert in `parsed_messages` +
  RPC-Call → Verify in `inbox_reads`. Befund als Kommentar im
  Migration-File festhalten.

- [ ] **T12 — Security-Review + Ship** *(Subagent: `security-reviewer` → manuell `/ship`)*
  RLS-Policies prüfen (kein Cross-Workspace-Leak, `read_by = auth.uid()`-
  Constraint stimmt), RPC-Permissions (kein PUBLIC, nur authenticated).
  Branch-Push + PR.

## Subagent-Routing

| Task    | Subagent          | Modell  |
|---------|-------------------|---------|
| T1      | `db-migrator`     | Opus    |
| T2      | `flutter-coder`   | Sonnet  |
| T3      | `flutter-coder`   | Sonnet  |
| T4      | `flutter-coder`   | Sonnet  |
| T5      | `ui-builder`      | Sonnet  |
| T6      | `ui-builder`      | Sonnet  |
| T7      | `ui-builder`      | Sonnet  |
| T8      | `ui-builder`      | Sonnet  |
| T9      | `ui-builder`      | Haiku   |
| T10     | `flutter-coder`   | Sonnet  |
| T11     | `db-migrator`     | Sonnet  |
| T12     | `security-reviewer` | Opus  |
