# Was ändert sich?

<!-- 1–3 Sätze: Was wurde gemacht und warum. -->

## Scope

- [ ] Dart-Code (`lib/`)
- [ ] Migrations (`supabase/migrations/`) — RLS-Policies enthalten?
- [ ] Edge Functions (`supabase/functions/`)
- [ ] UI / l10n (`lib/screens`, `lib/widgets`, `lib/l10n/`)
- [ ] Tests (`test/`)
- [ ] CI / Tooling (`.github/`, `.claude/`)
- [ ] Sonstiges:

## Quality Gates

- [ ] `flutter analyze` lokal grün
- [ ] `flutter test` lokal grün
- [ ] (falls Migration) `supabase db reset` lokal erfolgreich
- [ ] Keine Secrets im Diff (`lib/config/supabase_config.dart`, `*.env`,
      `google-services.json`, `GoogleService-Info.plist`, CSV-Daten)
- [ ] Neue UI-Strings in `app_de.arb` UND `app_en.arb`
- [ ] Neue Tabellen haben RLS-Policies (Default-Deny)

## UI-Smoke-Test

- [ ] Lokal in Chrome geprüft (`/test-ui smoke-<feature>` oder manuell)
- [ ] Screenshots in PR-Body (optional)
- [ ] Nicht UI-relevant — übersprungen

## Plan / Issue

<!-- Pfad zum Plan-File in plans/ oder Issue-Referenz -->

## Reviewer-Hinweise

<!-- Worauf der Review besonders achten soll. -->
