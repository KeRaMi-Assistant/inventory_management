# 08 — Deployment

Dieses Kapitel beschreibt, wie die App in die Welt kommt: Migrations,
Edge-Functions, Flutter-Builds für Web, iOS und Android. Auto-Merge auf
`main` ist im Pre-Launch-Modus erlaubt — Details siehe [CLAUDE.md](../../CLAUDE.md).

> Begriffe wie *Workspace*, *RLS*, *Service-Role*, *FCM*, *Web-Renderer*
> sind im [Glossar](10-glossary.md) erklärt.

## Big Picture

```text
  feature/<slug>  ──► PR ──► CI gates  ──► auto-merge ──► main
                              │
                              ├─► flutter analyze
                              ├─► flutter test
                              └─► security-reviewer

  main  ──► manual: supabase db push (Migrations)
        ──► manual: supabase functions deploy <name>
        ──► manual: flutter build web / ios / android
```

> **Pre-Launch-Hinweis:** Migrations und Function-Deploys gegen Cloud sind
> NIE automatisiert. `supabase db push` läuft nur auf explizite User-
> Bestätigung (siehe verbotene Aktionen in [CLAUDE.md](../../CLAUDE.md)).

## Migrations deployen

### Lokal testen (PFLICHT)

```bash
supabase db reset
```

`db reset` startet den lokalen Stack neu, droppt das Schema und spielt
**alle** Migrations chronologisch ein. Wenn das clean durchläuft, ist die
Migration bereit. Wenn nicht: SQL fixen, neu reset.

### Cloud (`supabase db push`)

```bash
supabase link --project-ref <ref>      # einmalig pro Maschine
supabase db push                        # spielt alle ungemachten Migrations ein
```

`supabase db push` zeigt eine Diff-Übersicht und fragt nach Bestätigung.
**Nie automatisieren** — Migrations gegen Prod sind risikoreich.

### Migration-Idempotenz prüfen

Vor `db push` lokal nochmal:

```bash
supabase db reset
# kein Fehler → idempotent
```

Wenn dieselbe Migration zweimal läuft (z.B. weil ein Cleanup-Script
durchläuft), darf sie nicht crashen. Das Pattern `IF NOT EXISTS`,
`DROP POLICY IF EXISTS` ist Pflicht.

## Edge Functions deployen

### Erstes Mal

```bash
supabase login                                # einmalig
supabase link --project-ref <ref>             # einmalig
supabase secrets set CRON_SECRET="$(openssl rand -hex 32)"
supabase secrets set FCM_SERVICE_ACCOUNT_JSON="$(cat fcm-sa.json)"
# weitere Secrets siehe Function-SETUP.md je Function
```

### Single-Function-Deploy

```bash
# Inbox-Poll & -Parse: --no-verify-jwt, weil eigene Auth
supabase functions deploy inbox-poll --no-verify-jwt
supabase functions deploy inbox-parse --no-verify-jwt
supabase functions deploy tracking-poll --no-verify-jwt
supabase functions deploy send-notifications --no-verify-jwt

# delete-account & seed-demo-workspace: User-JWT validieren lassen
supabase functions deploy delete-account
supabase functions deploy seed-demo-workspace
```

### All-at-once

```bash
for fn in inbox-poll inbox-parse tracking-poll send-notifications; do
  supabase functions deploy "$fn" --no-verify-jwt
done
supabase functions deploy delete-account
supabase functions deploy seed-demo-workspace
```

### pg_cron-Schedule setzen

Beim ersten Deploy musst du in der Datenbank den Schedule manuell anlegen.
Beispiel `inbox-poll` alle 5 Minuten:

```sql
SELECT cron.schedule(
  'inbox-poll-every-5min',
  '*/5 * * * *',
  $$ SELECT net.http_post(
       url := 'https://<ref>.functions.supabase.co/inbox-poll',
       headers := jsonb_build_object(
         'Authorization', 'Bearer ' || current_setting('app.cron_secret'),
         'Content-Type', 'application/json'
       ),
       body := '{}'::jsonb
     ); $$
);
```

> Voraussetzungen: `pg_cron` und `pg_net` aktiviert (Migration
> [`20260503001100_enable_cron.sql`](../../supabase/migrations/20260503001100_enable_cron.sql)
> + Dashboard-Toggle).

Schedule für `tracking-poll` (alle 4h) und `send-notifications` (laut
SETUP.md) analog.

## Flutter-Builds

Die App läuft auf Web, iOS und Android. Pre-Launch ist Web der primäre
Build (Smoke-Tests + Public-Profile). Mobile-Builds folgen, sobald Stripe
+ Stores aktiv sind.

### Vor jedem Build

```bash
flutter pub get
flutter gen-l10n              # ARB → Dart
flutter analyze               # MUSS grün sein
flutter test                  # MUSS grün sein
```

### Web-Build

```bash
flutter build web --release \
  --dart-define=SUPABASE_URL_OVERRIDE=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_OVERRIDE=$SUPABASE_ANON
```

> Aktuell sind `lib/config/supabase_config.dart` hartcodiert. Wenn du
> Build-Time-Configuration willst (CI-Workflow), erweitere den Loader,
> damit `String.fromEnvironment` Fallback ist.

Output: `build/web/`. Hosting:

- **Lokal serven** (Smoke-Tests):
  ```bash
  bash .claude/scripts/dev-web.sh   # Port 8123
  ```
- **Statisch hosten** (Cloudflare Pages, Netlify, Vercel, GitHub Pages —
  alles geht). Wichtig: `index.html` als 404-Fallback konfigurieren, damit
  Path-URLs (`/u/<handle>`) nicht 404en.

### iOS-Build

```bash
flutter build ios --release
# danach in Xcode öffnen für Signing
open ios/Runner.xcworkspace
```

Voraussetzungen:

- Xcode aktuell (mind. 15+).
- Apple-Developer-Account.
- `GoogleService-Info.plist` in `ios/Runner/` (gitignored).
- APNs-Capability in Apple-Developer + Push-Cert konfiguriert.
- Sign-In-with-Apple-Capability aktiviert (in `Signing & Capabilities`).

```bash
# nach Xcode-Archive
# Distribution → App Store Connect / TestFlight
```

### Android-Build

```bash
flutter build apk --release         # APK (für Sideload)
flutter build appbundle --release   # AAB (für Play Store)
```

Voraussetzungen:

- Android-SDK installiert.
- Signing-Key:
  ```bash
  keytool -genkey -v -keystore android/upload-keystore.jks \
    -keyalg RSA -keysize 2048 -validity 10000 -alias upload
  ```
  + `android/key.properties` (gitignored) mit Keystore-Pfad und Passwörter.
- `google-services.json` in `android/app/` (gitignored).

Output: `build/app/outputs/flutter-apk/app-release.apk` bzw.
`build/app/outputs/bundle/release/app-release.aab`.

## Branching, PRs, Auto-Merge

Aus [CLAUDE.md](../../CLAUDE.md):

- **NIE direkt auf `main`** committen.
- Branch-Naming: `feature/<slug>` oder `fix/<slug>`, kebab-case, max 40
  Zeichen.
- Whitelist für `git add`: nur `lib/`, `supabase/migrations/`,
  `supabase/functions/`, `test/`, `pubspec.yaml`, `pubspec.lock`,
  `plans/`, `.github/`, `CLAUDE.md`, `.claude/`.
- **Niemals committen:** `lib/config/supabase_config.dart`,
  `google-services.json`, `GoogleService-Info.plist`, `.env*`,
  CSV-Dumps mit Echtdaten.

### `/ship`-Workflow

```bash
# In Claude Code:
/ship
```

Macht:

1. `flutter analyze` + `flutter test`.
2. `security-reviewer`-Subagent.
3. Commit auf Feature-Branch.
4. `git push`.
5. `gh pr create`.
6. `gh pr merge --auto --squash --delete-branch`.

Wenn Branch-Protection auf `main` aktiv ist (siehe
[`.claude/scripts/setup-branch-protection.sh`](../../.claude/scripts/setup-branch-protection.sh)),
wartet GitHub bis CI grün ist und merged dann automatisch.

### Auto-Merge ohne Branch-Protection (Helper)

```bash
bash .claude/scripts/auto-merge-pr.sh         # nimmt PR des aktuellen Branches
bash .claude/scripts/auto-merge-pr.sh 42      # gezielt PR #42
```

Switched nach Erfolg auf `main` und macht `git pull`.

## Backups & Restore

### Schema-Backup

```bash
supabase db dump --schema-only > schema.sql
supabase db dump --data-only --table public.deals > deals.csv
```

### Restore

```bash
psql "$DATABASE_URL" -f schema.sql
```

> Achtung: Schema-Restore muss in einer leeren DB laufen, sonst Konflikte.
> Pre-Launch ist das okay; sobald Echtdaten drin sind, lieber
> point-in-time-Recovery von Supabase nutzen.

## CI

### GitHub Actions

`.github/workflows/` (im Repo prüfen) enthält:

- **`flutter_ci.yml`** — `flutter analyze` + `flutter test` auf jeden PR.
- **`claude-code-action.yml`** — Code-Review-Bot via Max-Plan-OAuth-Token.

> Kein `supabase db push` in CI. Migrations werden manuell deployed.

### Lokale Pre-Push-Hooks

`.claude/scripts/post-edit.sh` läuft nach jedem File-Edit `dart analyze
<pfad>` und meldet Fehler zurück. Browser-Smoke ist über `/test-ui smoke-*`
verfügbar.

## Headless-Loop (Optional)

Datei: [`.claude/scripts/install-headless.sh`](../../.claude/scripts/install-headless.sh)

Ein macOS-LaunchAgent triggert alle 30min (Default) den Headless-Runner,
der ein Backlog-Item aus `.claude/backlog/inbox/` zieht und durchspielt.
Nicht relevant für klassisches Deployment, aber praktisch fürs
"Roboterhafte Abarbeiten" einer Liste.

## Versionierung

Datei: [`pubspec.yaml`](../../pubspec.yaml)

```yaml
version: 1.0.0+1
```

Pre-Launch bleibt das auf `1.0.0+1`. Ab Public-Release:

- Patch-Bump für Bugfixes (`1.0.1+2`)
- Minor-Bump für Feature-Releases (`1.1.0+10`)
- Major-Bump für Breaking-Changes (selten)

Build-Number (`+N`) muss bei jedem Store-Upload streng monoton steigen.

## Rollback-Strategie

### Code-Rollback

```bash
git revert <commit>
/ship
```

### Migration-Rollback

Es gibt **keinen automatischen Down-Migration-Mechanismus**. Pre-Launch-
Strategie:

- Wenn die letzte Migration falsch war: neue Migration schreiben, die das
  korrigiert (idempotent).
- Im Notfall lokal Schema dumpen, Cloud-DB resetten, Schema spielen.

Ab Echtdaten gilt: Migrations sind **forward-only**. Down-Migrations
mitschreiben, falls Risiko hoch.

### Function-Rollback

```bash
git checkout <last-good-commit> -- supabase/functions/<name>/
supabase functions deploy <name> --no-verify-jwt
```

## Quelle im Code

- [`CLAUDE.md`](../../CLAUDE.md) — verbotene Aktionen + Auto-Merge-Regeln
- [`SUPABASE_SETUP.md`](../../SUPABASE_SETUP.md) — Cloud-Erstkonfiguration
- [`pubspec.yaml`](../../pubspec.yaml) — Flutter-Version + Build-Number
- [`supabase/migrations/`](../../supabase/migrations/) — alle Migrations
- [`supabase/functions/`](../../supabase/functions/) — alle Edge-Functions
- [`supabase/functions/tracking-poll/SETUP.md`](../../supabase/functions/tracking-poll/SETUP.md) — pg_cron-Setup-Beispiel
- [`supabase/functions/send-notifications/SETUP.md`](../../supabase/functions/send-notifications/SETUP.md) — FCM-Setup
- [`.claude/scripts/auto-merge-pr.sh`](../../.claude/scripts/auto-merge-pr.sh) — Auto-Merge-Helper
- [`.claude/scripts/setup-branch-protection.sh`](../../.claude/scripts/setup-branch-protection.sh) — GH Branch Protection
- [`.claude/scripts/dev-web.sh`](../../.claude/scripts/dev-web.sh) — lokaler Web-Server
- [Glossar](10-glossary.md) — Begriffsdefinitionen
