# 09 — Troubleshooting

Dieses Kapitel listet die Bugs, Fehlerbilder und Stolpersteine, die in der
Entwicklung am häufigsten auftauchen — zusammen mit der Diagnose und der
Lösung. Ist als Nachschlage-Sammlung gedacht: such nach dem Symptom, lies
zwei Absätze, fix.

> Begriffe wie *Workspace*, *RLS*, *Service-Role*, *Adapter*, *FCM* sind im
> [Glossar](10-glossary.md) erklärt.

## Setup-Probleme

### `SupabaseConfig` not found

**Symptom:** Beim ersten Start: `Error: file not found:
lib/config/supabase_config.dart`.

**Ursache:** Du hast die Datei nicht angelegt; sie ist gitignored, weil
Secrets drinstehen.

**Fix:** Datei manuell anlegen mit URL + anonKey aus dem Supabase-
Dashboard. Siehe
[`01-getting-started.md`](01-getting-started.md#supabase-projekt-aufsetzen).

### `flutter pub get` schlägt fehl

**Symptom:** `Resolving dependencies failed`.

**Diagnose:**

- Flutter-Version prüfen: `flutter --version` → muss `3.11+` (Dart `^3.11.5`).
- Paket-Lock veraltet? `flutter pub upgrade --major-versions`.
- Network-Restriktionen? `pub.dev` proxied?

### `supabase db reset` hängt

**Symptom:** Lokaler Reset bricht in Migration X ab.

**Diagnose:** `supabase status` checken — läuft der Stack?
Logs: `supabase logs db`.

**Fix:** Meist eine Migration mit nicht-idempotentem SQL. Pattern
`IF NOT EXISTS` / `DROP POLICY IF EXISTS` ergänzen.

## Auth-Probleme

### "Unauthorized" beim Login

**Symptom:** Login klappt nicht, Snackbar zeigt "Ungültige Anmeldedaten".

**Diagnose:**

1. **E-Mail-Confirm fehlt?** Im Supabase-Studio → Auth → Users → Spalte
   `email_confirmed_at` muss gesetzt sein. Wenn nicht: "Confirm Email"
   manuell.
2. **Falsches Passwort.** Trivial — neu setzen via
   [Forgot-Password-Flow](03-screens-walkthrough.md#register--forgot--reset--verify).
3. **Wrong project.** `lib/config/supabase_config.dart` zeigt auf falsche
   Cloud-Instanz?

### Login klappt, aber landet auf weißem Screen

**Symptom:** Login → Splash → leer.

**Diagnose:** `_AuthGate._hydrate()` failed. Browser-Konsole + Flutter-
Devtools auf Errors prüfen.

**Häufige Ursachen:**

- **Workspaces nicht angelegt** (Trigger
  `provision_personal_workspace` fehlt). Im Studio
  `SELECT * FROM public.workspaces WHERE owner_id = '<user-id>';` —
  wenn leer: Migration
  [`20260504000200_workspaces.sql`](../../supabase/migrations/20260504000200_workspaces.sql)
  einspielen.
- **RLS blockiert.** `SELECT auth.uid();` → null? Dann ist die Session
  kaputt. Sign-out + sign-in.

### Magic-Link-Reset funktioniert nicht

**Symptom:** Reset-Link aus E-Mail klickt, kommt aber auf Login statt
Reset-Form.

**Diagnose:** `_RecoveryListener` in
[`main.dart`](../../lib/main.dart) hört auf
`AuthProvider.passwordRecoveryStream`. Wenn der Stream nichts sendet,
deeplink ist nicht gehandhabt.

**Fix:** Im Browser muss die URL eine Hash-Fragment-Form haben
(`#access_token=…&type=recovery`). Wenn der Magic-Link auf
`?access_token=…` zeigt, ist die Redirect-URL im Supabase-Dashboard
falsch konfiguriert (Auth → URL Configuration).

## Workspace- & RLS-Probleme

### "permission denied for table xxx"

**Symptom:** Insert/Update/Select wirft `permission denied`.

**Ursache:** RLS-Policy passt nicht. Häufig:

- Falsche Workspace-ID gesetzt. Check `_clientOrNull.activeWorkspaceId`.
- `auth.uid()` ist null (Session abgelaufen).
- Policy verlangt höhere Rolle (z.B. `owner|admin` für Mailbox-Account-
  Schreiben, du bist nur `member`).

**Diagnose:**

```sql
SET role authenticated;
SET request.jwt.claim.sub = '<user-id>';
EXPLAIN (ANALYZE, VERBOSE) SELECT * FROM public.deals WHERE id = …;
```

oder einfacher: Im Studio → SQL Editor → "Run as authenticated" mit der
User-ID.

### "kein aktiver Workspace gesetzt"

**Symptom:** `StateError: SupabaseRepository: kein aktiver Workspace
gesetzt.`

**Ursache:** Im Code-Flow wurde `repository.setActiveWorkspace(...)` nicht
aufgerufen. Passiert i.d.R. nur in Tests.

**Fix:**

```dart
final repo = SupabaseRepository(client);
repo.setActiveWorkspace('<ws-id>');
```

In Produktion ruft der `_AuthGate._hydrate()`-Pfad das automatisch.

### Workspace-Wechsel zeigt alte Daten

**Symptom:** Du wechselst über das Workspace-Dropdown, siehst aber noch
die Deals des alten Workspaces.

**Ursache:** `_AuthGate._onWorkspaceChanged` hat den Wechsel nicht
gehört (Listener nicht angehängt).

**Fix:** Sicherstellen, dass `_attachWorkspaceListener` in `_hydrate`
gerufen wurde. Beim Test: Hot-Restart (nicht nur Hot-Reload).

## Inbox-Probleme

> Sehr wichtige Lektüre vorab:
> [`04-inbox-mail-pipeline.md`](04-inbox-mail-pipeline.md). 90 % der Inbox-
> Bugs werden klar, wenn man die Pipeline einmal verstanden hat.

### Mail kommt nicht in die Inbox

**Diagnose-Checkliste:**

1. **Postfach `enabled = TRUE`?** SQL:
   ```sql
   SELECT id, label, enabled, last_polled_at, last_error
   FROM public.mailbox_accounts
   WHERE workspace_id = '<ws>';
   ```
2. **`last_error` gesetzt?** Dann hat IMAP-Connect/Login gefailed.
   Häufig: 2FA aktiv, App-Passwort fehlt, falsches Postfach
   (`folder='Sent'` statt `INBOX`).
3. **Adapter matched nicht?** `from`-Domain checken. Wenn der Shop noch
   nicht in der Registry: Adapter ergänzen in
   [`inbox_adapters.ts`](../../supabase/functions/_shared/inbox_adapters.ts).
4. **`looksLikeOrder` filtert weg?** Subject-Pattern erweitern,
   Forensik-Test (`inbox_forensics_test.ts`) ergänzen.
5. **Mail in `parsed_messages` mit `status='unclassified'`?** Adapter hat
   gematcht, `parse` lieferte `null`. Mail im UI manuell zu Deal machen
   oder Re-Parse-Mode mit verbessertem Adapter laufen lassen.

### Tracking-Nummer fehlt im geparsten Deal

**Diagnose:**

- Plaintext-Body enthält kein offensichtliches Tracking-Pattern.
- HTML-Forensik nicht implementiert für diesen Shop.

**Fix:** Forensik-Test schreiben (`inbox_forensics_test.ts`), Adapter-
Code anpassen, Re-Parse mit
`{reparse_forensics: true, workspace_id: '...', shop_key: '...'}`.

### "Bootstrap zieht nichts"

**Symptom:** Erstes Pollen eines neuen Postfachs liefert 0 Mails, obwohl
das Konto voll ist.

**Diagnose:** `BOOTSTRAP_LOOKBACK_DAYS=90` zu klein für sparse Postfächer.

**Fix:**

```bash
supabase secrets set BOOTSTRAP_LOOKBACK_DAYS=180
```

und nochmal pollen. `last_uid` muss `NULL` sein (sonst greift Bootstrap
nicht).

### Mails werden wiederholt gepollt

**Symptom:** Bei jedem Cron-Tick kommen dieselben Mails neu rein.

**Ursache:** `last_uid` wird nicht persistiert — meist Folge eines Polls,
der vor dem `UPDATE mailbox_accounts SET last_uid = …`-Step abbricht.

**Fix:**

- Logs der letzten Poll-Runs prüfen.
- Wenn Time-Budget zu knapp: `MAX_FETCH_PER_RUN` reduzieren.
- Wenn IMAP-Server flaky: Retry-Logik im Account-Block.

### "Inbox-Tab fehlt im Nav"

**Symptom:** Inbox-Tab nicht sichtbar.

**Ursache:** `BillingProvider.currentPlan` ist `Free`. Free hat
`hasInbox = false` (siehe
[`pricing_plan.dart`](../../lib/models/pricing_plan.dart)).

**Fix:** Plan upgraden (Settings → Subscription) oder im Studio das
`billing_profiles.plan` auf `'starter'` setzen.

## Tracking-Probleme

### Tracking-Status aktualisiert nicht

**Diagnose:**

1. **Carrier-Adapter erkennt Tracking?** Wenn nicht, ist das die Ursache.
   Adapter erweitern.
2. **API-Key fehlt?** `workspace_carrier_credentials` mit
   `enabled=TRUE` und API-Key vorhanden?
3. **Cron läuft?** `SELECT * FROM cron.job WHERE jobname LIKE
   'tracking%';` — und `cron.job_run_details` für letzte Runs.

### "Status hat sich nicht auf 'Angekommen' geändert"

**Ursache:** Carrier-API liefert `delivered`, aber `tracking-poll` hat
das beim Mapping nicht erkannt.

**Fix:** Adapter-Status-Mapping in
[`tracking_adapters.ts`](../../supabase/functions/_shared/tracking_adapters.ts)
prüfen — die Status-Strings der einzelnen Carrier sind extrem
inkonsistent ("Zugestellt", "delivered", "DELIVERED", "✅ delivered").

## Push-Notifications

### Push kommt nicht an (Android)

**Diagnose:**

1. `google-services.json` in `android/app/` vorhanden?
2. `firebase_core` initialisiert? Logs: `Firebase initialized`.
3. FCM-Token in `fcm_tokens`-Tabelle?
   ```sql
   SELECT * FROM public.fcm_tokens WHERE user_id = '<u>';
   ```
4. `notifications_sent` zeigt versendete Push? Wenn ja, Problem ist
   client-seitig.
5. `send-notifications`-Function-Logs:
   ```bash
   supabase functions logs send-notifications --tail 100
   ```

### Push kommt nicht an (iOS)

**Diagnose:** Wie Android plus:

- APNs-Capability + Push-Cert in Apple-Developer eingerichtet?
- `GoogleService-Info.plist` in `ios/Runner/`?
- App im Vordergrund vs. Hintergrund — APNs verhält sich unterschiedlich.

## Build-/Deploy-Probleme

### `flutter analyze` fail

**Symptom:** CI rot, lokal reproduzierbar.

**Diagnose:** Lies die Fehlermeldungen genau — sehr oft hardcoded String
(muss in ARB) oder ungenutzter Import.

**Fix:**

```bash
dart fix --apply           # autofix-bare Imports
dart format .              # Format-Drift
flutter gen-l10n           # ARB → Dart-Code regenerieren
```

### `flutter test` schlägt fehl in CI, aber nicht lokal

**Diagnose:** Häufig sind Tests gegen Locale `de_DE` getunet. CI-Runner
hat nur `en_US`.

**Fix:** In `test/` Setup `await initializeDateFormatting('de_DE')`
ergänzen, oder Test gegen mehrere Locales schreiben.

### Edge-Function Deploy "missing import"

**Symptom:** `supabase functions deploy` failt mit Import-Fehler.

**Ursache:** Deno hat strikte Import-URLs. Lokales Caching kann
inkonsistent sein.

**Fix:**

```bash
deno cache --reload supabase/functions/<name>/index.ts
supabase functions deploy <name>
```

### `supabase db push` zerbricht an einer Migration

**Symptom:** Push gegen Cloud failt mit SQL-Error.

**Diagnose:** Lokal `supabase db reset` läuft? Wenn ja, Cloud-State weicht
ab — z.B. Spalten existieren schon, weil ein vorheriger Push halb
durchlief.

**Fix:**

- Cloud-Schema im Studio anschauen, manuelle Korrekturen via SQL Editor.
- Migration-File so anpassen, dass es **idempotent** ist (vor allem
  `DROP POLICY IF EXISTS` und `CREATE POLICY` getrennt halten).

## Performance

### App ruckelt auf Phone

**Diagnose:** DevTools → Performance-Profile aufnehmen.

**Häufig:**

- `setState`-Welle, weil ein großer Provider neu builded.
  → `Selector` statt `Consumer` für punktuelles Rebuilden.
- Listen ohne `ListView.builder` (alles im Speicher).
- Bilder ohne `cached_network_image` (komplett neu geladen).

### Inbox-Tab sehr langsam

**Diagnose:** Pro Workspace 10 000+ `parsed_messages` aufgelaufen?

**Fix:**

- Sichtbarkeitsfenster über `applyPlanQuota` einschränken.
- DB-Cleanup-Job läuft? `cleanup_inbox_history` täglich um 03:15 UTC,
  aber bei Plan-Upgrade auf 100 Tage werden Mails bis 100 Tage
  aufgehoben.

## Data-Loss-Verdacht

### "Mein Deal ist weg!"

**Diagnose-Reihenfolge:**

1. Soft-Delete? `SELECT * FROM public.deals WHERE id = X;` — wenn
   `deleted_at IS NOT NULL`, ist er nur ausgeblendet.
2. Workspace-Wechsel? In dem aktiven Workspace nicht vorhanden, aber im
   anderen ja.
3. Echt gelöscht? `audit_log` checken:
   ```sql
   SELECT * FROM public.audit_log
   WHERE entity_type = 'deal' AND entity_id = '<id>'
   ORDER BY created_at DESC;
   ```

### "Workspace ist verschwunden"

**Diagnose:** `workspaces.deleted_at IS NOT NULL`. Workspace-Löschung ist
soft. Restore via Studio: `UPDATE workspaces SET deleted_at = NULL WHERE
id = '...';`

### Postfach ist nach Workspace-Löschung weg

**Ursache:** `mailbox_accounts.workspace_id ON DELETE CASCADE`. Bei
**echter** Workspace-Löschung sind Mailboxen + Credentials weg.

**Fix:** Backup vor jeder Workspace-Löschung. Pre-Launch-Strategie: einfach
neu anlegen.

## Diagnose-Tooling

### Logs

```bash
supabase functions logs <fn> --follow      # live
supabase functions logs <fn> --tail 200    # Snapshot
supabase logs db --follow                  # Postgres-Logs
```

### Studio-SQL-Editor

Sehr nützlich für Ad-hoc-Queries. Im "Roles"-Switch zwischen
`postgres` (Admin), `service_role` (Edge-Fn-Sicht) und `authenticated`
(User-Sicht mit RLS) wechseln, um RLS-Probleme zu reproduzieren.

### Browser-Tester

```bash
/test-ui smoke-login
/test-ui smoke-inbox
/test-ui "öffne Settings, klicke 'Mailbox hinzufügen'"
```

Reports + Screenshots in `.claude/test-runs/<timestamp>/`. Sehr gut, um
zu prüfen, ob ein Refactoring den Login zerlegt hat.

### `flutter doctor`

```bash
flutter doctor -v
```

Druckt alles, was in der Toolchain fehlt (Xcode-Lizenz, Android-SDK-
Lizenz, Chrome, etc.).

## Wann eskalieren?

- **Datenverlust mit unklarer Ursache** → STOP, kein weiteres Schreiben,
  Audit-Log + Backup analysieren.
- **RLS-Bypass entdeckt** → STOP, security-reviewer-Subagent rufen,
  Migration mit Fix vorbereiten, Cloud-Push erst nach Re-Audit.
- **Edge-Function leakt Tokens in Logs** → STOP, Logs purgen wenn möglich,
  Deploy zurückrollen, neuen Deploy ohne Token-Logs.

## Quelle im Code

- [`lib/main.dart`](../../lib/main.dart) — `_AuthGate`-Hydration-Pfad
- [`lib/services/supabase_repository.dart`](../../lib/services/supabase_repository.dart) — Repository-StateError-Bedingungen
- [`lib/providers/inbox_provider.dart`](../../lib/providers/inbox_provider.dart) — Inbox-State-Logik
- [`supabase/functions/inbox-poll/index.ts`](../../supabase/functions/inbox-poll/index.ts) — Bootstrap & UID-Cap
- [`supabase/functions/_shared/inbox_adapters.ts`](../../supabase/functions/_shared/inbox_adapters.ts) — Adapter-Whitelist
- [`supabase/functions/tracking-poll/index.ts`](../../supabase/functions/tracking-poll/index.ts) — Carrier-Calls
- [`supabase/migrations/20260504000300_workspace_rls_fix.sql`](../../supabase/migrations/20260504000300_workspace_rls_fix.sql) — RLS-Helper
- [`supabase/migrations/20260507000000_inbox.sql`](../../supabase/migrations/20260507000000_inbox.sql) — Mailbox-RPCs
- [Glossar](10-glossary.md) — Begriffsdefinitionen
- [04-inbox-mail-pipeline.md](04-inbox-mail-pipeline.md) — Pipeline-Tiefenwissen
