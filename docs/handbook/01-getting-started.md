# 01 — Getting Started

Dieses Kapitel führt dich von einem frischen Checkout bis zum ersten
funktionierenden Login. Wenn du am Ende die App startest, dich einloggst und
das [Onboarding](10-glossary.md#onboarding) siehst, ist alles richtig
verkabelt.

## Voraussetzungen

| Tool | Version | Wie installieren |
|---|---|---|
| Flutter SDK | 3.11+ (Dart `^3.11.5`) | [flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install) |
| Supabase CLI | aktuell | `brew install supabase/tap/supabase` |
| Node + npx | LTS | für Playwright-MCP-Bootstrapping |
| `gh` (GitHub CLI) | aktuell | `brew install gh` — für `/ship` |
| Xcode + iOS-Simulator | aktuell (macOS) | App Store |
| Android Studio + SDK | aktuell | optional, nur für Android-Build |
| Chrome | aktuell | Web-Smoke-Tests + manuelles Klicken |
| `claude` CLI | aktuell | für Headless-Loop, optional |

> **Pre-Launch-Hinweis:** Die App ist im Pre-Launch-Stadium. Es gibt keine
> echten Nutzer und kein Stripe-Abo. Aggressive Refactorings sind okay,
> solange git-versioniert. Siehe [CLAUDE.md](../../CLAUDE.md).

## Repo klonen

```bash
git clone <repo-url> inventory_management
cd inventory_management
flutter pub get
```

`flutter pub get` zieht alle Dependencies aus `pubspec.yaml` — u.a.
`supabase_flutter`, `provider`, `firebase_messaging`, `mobile_scanner`,
`pdf`/`printing` und `excel`. Das dauert beim ersten Mal ein paar Minuten.

## Supabase-Projekt aufsetzen

Du brauchst ein Supabase-Projekt (Cloud oder selbst gehostet). Zwei Pfade:

### Variante A — Cloud-Projekt + Migrations einspielen

1. [supabase.com](https://supabase.com) → neues Projekt anlegen (Region nach
   Wahl, "Free"-Tier reicht).
2. Aus Supabase-Dashboard → "Project Settings" → "API" die folgenden Werte
   notieren:
   - **Project URL** (sieht aus wie `https://<ref>.supabase.co`)
   - **anon public key** (`eyJhbGciOi...`)
3. `lib/config/supabase_config.dart` anlegen — die Datei ist gitignored:

   ```dart
   // lib/config/supabase_config.dart  ← NICHT committen!
   class SupabaseConfig {
     static const url = 'https://<ref>.supabase.co';
     static const anonKey = 'eyJ...';
   }
   ```

4. Migrations einspielen. Lokal gegen ein Supabase-Cloud-Projekt:

   ```bash
   supabase link --project-ref <ref>
   supabase db push
   ```

   `supabase db push` lädt **alle** Migrations aus
   `supabase/migrations/` hoch — siehe [06-database.md](06-database.md). Die
   App ist nicht funktional, bevor mindestens die initiale Schema-Migration
   gelaufen ist.

5. Edge Functions deployen (siehe
   [08-deployment.md](08-deployment.md#edge-functions-deployen)).

### Variante B — Lokaler Supabase-Stack via Docker

Praktisch fürs Offline-Entwickeln:

```bash
supabase start         # Spin-up lokaler Postgres + Studio + Storage
supabase db reset      # spielt alle Migrations frisch ein
```

`supabase start` druckt am Ende u.a. die lokale `API URL`
(typischerweise `http://127.0.0.1:54321`) und einen lokalen `anon key`. Die
trägst du dann in `lib/config/supabase_config.dart` ein. Siehe auch
[`SUPABASE_SETUP.md`](../../SUPABASE_SETUP.md) im Repo-Root.

## Auth-Provider konfigurieren

Die App unterstützt drei Login-Wege:

- **E-Mail + Passwort** (Supabase Auth, Default)
- **Google Sign-In** (`google_sign_in`)
- **Apple Sign-In** (`sign_in_with_apple`)

Für Google/Apple musst du im Supabase-Dashboard unter "Authentication" →
"Providers" jeweils Client-IDs eintragen. Ohne diese Provider funktioniert
nur E-Mail-Login. Für die App-Smoke-Tests reicht E-Mail.

> **Test-Accounts:** Während der Entwicklung legen wir in jedem Supabase-Dev
> zwei Accounts an: `test@test.com` und `test2@test.com` (Passwort: `passwort`).
> Diese Accounts sind im Browser-Tester referenziert. Siehe
> `.env.test.example`. **Keine echten Mailadressen committen.**

## Firebase / Push-Notifications

Push-Notifications sind optional. Wenn du sie willst:

1. Firebase-Projekt anlegen.
2. `google-services.json` (Android) und `GoogleService-Info.plist` (iOS) in
   die Plattform-Ordner ablegen — beide Dateien sind in `.gitignore`.
3. FCM-Service-Account-JSON als Supabase-Secret setzen:

   ```bash
   supabase secrets set FCM_SERVICE_ACCOUNT_JSON="$(cat path/to/sa.json)"
   ```

4. `send-notifications`-Edge-Function deployen (siehe
   [07-edge-functions.md](07-edge-functions.md#send-notifications)).

Wenn diese Schritte fehlen, läuft die App **trotzdem** — Push-Registrierung
ist Best-Effort. Die [`PushService.init()`](../../lib/services/push_service.dart)-
Methode fängt fehlende Firebase-Konfiguration still ab.

## Erster Start

```bash
flutter run                    # interaktiver Device-Picker
flutter run -d chrome          # Web
flutter run -d <ios-sim-id>    # iOS-Simulator
flutter run -d <android-id>    # Android-Emulator
```

Der erste Start nimmt ein paar Sekunden — danach landest du auf dem
[Login-Screen](03-screens-walkthrough.md#login).

### Account anlegen

1. "Account erstellen" → E-Mail + Passwort.
2. Supabase schickt eine Bestätigungsmail. Im Cloud-Tier muss der Link
   geklickt werden, lokal kannst du E-Mail-Confirm im Supabase-Studio ("Auth
   → Users → confirm") manuell setzen.
3. Beim nächsten Login startet automatisch das Onboarding.

### Onboarding-Flow

`OnboardingProvider` führt durch drei Schritte:

1. **Personal-Workspace bestätigen.** Der wird beim Sign-Up automatisch
   per Trigger angelegt (siehe
   [Migration `20260504000200_workspaces.sql`](../../supabase/migrations/20260504000200_workspaces.sql)).
2. **Demo-Daten optional importieren.** Nutzt
   [`DemoDataService`](../../lib/services/demo_data_service.dart) und ruft
   die Edge-Function
   [`seed-demo-workspace`](../../supabase/functions/seed-demo-workspace/index.ts)
   auf. Funktioniert nur für `test@test.com` (Hard-Constraint im
   Function-Code).
3. **`onboarded_at`-Marker setzen.** Sobald gesetzt, schaltet
   [`AuthGate`](../../lib/main.dart) auf den
   [`MainScreen`](../../lib/screens/main_screen.dart).

> **Begriffe** wie *Workspace*, *Provider*, *Service* sind im
> [Glossar](10-glossary.md) definiert.

## Aufruf-Kette beim ersten Start

Wenn du `flutter run` startest, läuft Folgendes ab:

1. `main()` in [`lib/main.dart`](../../lib/main.dart) initialisiert
   `WidgetsFlutterBinding`, lädt `intl`-Daten für `de_DE` und ruft
   `Supabase.initialize(url, anonKey)`.
2. Web-Sonderfall: Wenn die URL `/u/<handle>` matcht, rendert die App
   das öffentliche Verkaufsprofil ohne Login. Andernfalls:
3. `AppPreferencesProvider.load()` zieht Theme + Sprache aus
   `SharedPreferences`.
4. `PushService.init()` wird "best effort" gerufen — wenn Firebase nicht
   konfiguriert ist, wird stilly weitergeleitet.
5. `runApp(InventoryApp)` baut den `MultiProvider`-Tree (siehe
   [05-architecture.md](05-architecture.md#provider-di-tree)).
6. `_AuthGate` prüft `AuthProvider.currentUser`:
   - `null` → `LoginScreen`.
   - vorhanden, aber noch nicht hydrated → `SplashScreen` + `_hydrate()`.
   - hydrated, Workspace ohne `onboarded_at` → `OnboardingScreen`.
   - sonst → `MainScreen`.

Wenn auf einem dieser Schritte etwas hängt, ist das Logfile dein Freund:
`flutter logs` (für Mobile) oder die Browser-Konsole (für Web).

## Web-Smoke-Test

Wenn du sicher gehen willst, dass alles tut, lass den Browser-Tester einmal
durchlaufen:

```bash
bash .claude/scripts/dev-web.sh   # baut + serviert auf :8123
# In einem zweiten Tab:
# /test-ui smoke-login
```

Erwartetes Ergebnis: Login mit `test@test.com` klappt, du landest auf dem
Dashboard, kein Console-Fehler. Reports liegen unter
`.claude/test-runs/<timestamp>/`. Stoppen via
`bash .claude/scripts/stop-web.sh`.

## Tests lokal laufen lassen

```bash
flutter analyze     # statische Analyse, MUSS clean sein
flutter test        # Unit + Widget-Tests
```

`flutter analyze` hat in `analysis_options.yaml` `flutter_lints` 6.0.0
aktiviert. Warnings werden als Fehler behandelt — siehe
`.github/workflows/`.

## Häufige Stolpersteine beim Setup

- **`SupabaseConfig` not found.** → Du hast `lib/config/supabase_config.dart`
  vergessen. Datei mit URL + anonKey neu anlegen.
- **`Unauthorized` beim Login.** → E-Mail-Confirm fehlt; im Supabase-Studio
  "Auth → Users → Confirm Email" aktivieren oder den Link aus der Mail
  klicken.
- **`Unable to connect`.** → Falsche `url` (Cloud-Projekt aus, falsche
  Region, oder lokaler `supabase start` ist gestoppt). Prüfen mit
  `curl <url>/rest/v1/`.
- **Onboarding hängt.** → Workspace wurde nicht angelegt. Im Studio
  `SELECT * FROM public.workspaces;` prüfen. Wenn leer, ist
  [Migration `20260504000200_workspaces.sql`](../../supabase/migrations/20260504000200_workspaces.sql)
  nicht eingespielt.
- **Push tut nicht auf iOS.** → APNs-Capability + Push-Cert in Apple
  Developer fehlen. Optional, blockt nicht den Rest.

Mehr Fehlerbilder im Kapitel [09-troubleshooting.md](09-troubleshooting.md).

## Was als nächstes?

- **Verstehe die Domäne** → [02-concepts.md](02-concepts.md).
- **Klick durch die App** → [03-screens-walkthrough.md](03-screens-walkthrough.md).
- **Stack im Detail** → [05-architecture.md](05-architecture.md).

## Quelle im Code

- [`lib/main.dart`](../../lib/main.dart) — Bootstrapping, MultiProvider, AuthGate
- [`lib/config/supabase_config.dart`](../../lib/config/) — gitignored, du legst sie selbst an
- [`lib/services/push_service.dart`](../../lib/services/push_service.dart) — Firebase-init
- [`lib/providers/auth_provider.dart`](../../lib/providers/auth_provider.dart) — Login/Sign-Up
- [`lib/providers/onboarding_provider.dart`](../../lib/providers/onboarding_provider.dart) — Onboarding-State
- [`lib/screens/auth/login_screen.dart`](../../lib/screens/auth/login_screen.dart) — Login-UI
- [`lib/screens/onboarding_screen.dart`](../../lib/screens/onboarding_screen.dart) — Onboarding-UI
- [`supabase/migrations/20260430000000_initial_schema.sql`](../../supabase/migrations/20260430000000_initial_schema.sql) — Basis-Tabellen
- [`supabase/migrations/20260504000200_workspaces.sql`](../../supabase/migrations/20260504000200_workspaces.sql) — Workspace-Trigger
- [`SUPABASE_SETUP.md`](../../SUPABASE_SETUP.md) — Schritt-für-Schritt Cloud-Setup
- [`pubspec.yaml`](../../pubspec.yaml) — Dependencies + Versionen
