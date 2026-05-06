# Automatisiertes Entwicklungs-Ökosystem für `inventory_management`

**Datum:** 2026-05-07
**Status:** Vorschlag, wartet auf Freigabe
**Stack-Realität:** Flutter 3.11 (Dart) + Supabase (Postgres, RLS, Edge Functions in Deno/TS) + Firebase Messaging
**App-Reife:** **Pre-Launch / aktive Entwicklung** — keine echten Nutzer, kein echtes Billing. Schema (`billing_profiles`, `subscription_overhaul`) existiert, ist aber noch nicht live.

> **Update 2026-05-07:** Ursprüngliche Version dieses Plans war zu konservativ (hat das Projekt fälschlich als Produktiv-App behandelt). User hat klargestellt: solange git-versioniert ist, dürfen Änderungen aggressiver sein. Quality-Gates und Phasen wurden entsprechend gestrafft.

---

## 1. Ehrliche Einschätzung der vorgeschlagenen Architektur

Die Vorlage aus der vorherigen Antwort kommt aus einem **Next.js/TypeScript-Kontext** (npm, vitest, zod, shadcn/ui, Storybook) und passt zu ~40% direkt. Was übersetzt werden muss:

| Vorlage (Next.js) | Realität hier (Flutter) |
|---|---|
| `npm run lint` | `flutter analyze` |
| `npm run test` | `flutter test` (nur Widget-/Unit, keine echten E2E ohne Device) |
| `tsc --noEmit` | im `dart analyze` enthalten |
| `vitest`/`jest` | `flutter_test` |
| Zod-Validation auf API-Routes | Edge Functions in `supabase/functions/_shared/` — eigenes Pattern |
| shadcn/ui + design-tokens | Flutter Widget-Tree + `app_theme.dart` |
| Storybook | (nicht da, würde `widgetbook` brauchen — Overkill jetzt) |

**Was an dem Vorschlag richtig ist:**
- Subagent-Architektur mit Modell-Routing (Opus für Planung/Security, Sonnet für Coding) ✅
- Hooks für deterministische Quality Gates ✅
- Feature-Branches + GitHub Action für PR-Review ✅
- `CLAUDE.md` als zentrale Regelquelle ✅

**Was trotz Pre-Launch beachtet bleibt:**
- ⚠️ **`flutter test` als alleinige Quality Gate ist dünn.** Du hast aktuell zwei Test-Files. Auto-Push in Feature-Branch ist OK, aber Auto-Merge auf `main` braucht zumindest grünen `flutter analyze` + `flutter test` — und solange Tests minimal sind, ist „grün" nur ein schwaches Signal.
- ⚠️ **UI-Regressionen bemerkt der Agent nicht.** Widget-Tests fangen Layout-Bugs nicht. → Smoke-Test im Device/Emulator bleibt deine Aufgabe; aber er muss nicht VOR jedem Merge erfolgen, sondern kann gebatcht werden (alle 1–3 Tage durch alle Screens klicken).
- ⚠️ **`git add .` im Auto-Commit** — du hast `.dart_tool/`, `build/`, `prompt_archive/`, `deals_2026-04-30.csv` im Umfeld. Lösung: saubere `.gitignore` + Whitelist-Add (`git add lib/ supabase/ test/ pubspec.yaml`).
- ⚠️ **Secrets:** `lib/config/supabase_config.dart` und Firebase-Configs trotzdem geschützt behandeln. Auch im Pre-Launch nicht öffentlich machen, sonst musst du Keys später rotieren.

**Was jetzt OK ist (war im ersten Entwurf zu restriktiv):**
- ✅ **Aggressive Migrations.** Schema-Änderungen, Refactorings, sogar destruktive Migrations sind reversibel via git + `supabase db reset`. `supabase db push` auf das Dev-Projekt ist auch OK, solange du es nicht versehentlich gegen einen Prod-Project-Ref linkst.
- ✅ **Auto-Merge auf `main`** kann nach Phase 3 eingeführt werden, wenn Tests + Analyze + Security-Review grün sind. Pre-Launch heißt: schnellere Iteration > paranoides Gating.
- ✅ **Headless-Loop** (Continuous Claude / `claude --print` in Cron) wird realistischer — siehe Phase 5.

**Realistische Zielgröße:**
> **Weitgehend autonom**: Claude plant, codet, testet, committed, pusht und mergt in Feature-Branches → `main`. DU machst gebatcht (1–3× pro Woche) einen UI-Smoke-Test und prüfst neue Migrations vor dem nächsten Schema-Reset. Versionierung (Git) ist das Sicherheitsnetz.

---

## 2. Architektur (auf dieses Projekt zugeschnitten)

```
[Du] → Feature-Wunsch oder /plan-Slash
  ↓
[planner Agent (opus)]   → schreibt plans/YYYY-MM-DD_<slug>.md
  ↓
[Du gibst Plan frei]    ← Quality Gate #1 (5 Min Lesen — optional ab Phase 3)
  ↓
[orchestrator]
  ├─ [flutter-coder (sonnet)]    → lib/, providers/, services/
  ├─ [edge-fn-coder (sonnet)]    → supabase/functions/
  ├─ [db-migrator (sonnet)]      → supabase/migrations/ + RLS
  └─ [ui-builder (sonnet)]       → screens/, widgets/, l10n/
  ↓
[Hook: PostToolUse]    → flutter analyze (nach jedem Edit)
  ↓
[tester (sonnet)]      → flutter test, fixt iterativ (max 5 Loops)
  ↓
[security-reviewer (opus)] → liest Diff, prüft RLS/Secrets/Inputs
  ↓
[Hook: Stop]           → commit zu feature/<slug> + push (Whitelist-Add)
  ↓
[GitHub Action]        → claude-code-action reviewt PR
  ↓
[Auto-Merge]           → wenn alle Checks grün (ab Phase 3)
  ↓
[Du]                   ← Smoke-Test 1–3× pro Woche, gebatcht
```

**Ein hartes Gate bleibt:** `supabase db push` gegen Prod-Project-Ref. Dev-Project ist frei. Versionierung im Git ist das Sicherheitsnetz für alles andere.

---

## 3. Was konkret eingerichtet wird

### 3.1 `CLAUDE.md` (Repo-Root)

Single Source of Truth für alle Subagenten. Inhalt (Stichpunkte):

- Stack-Versionen (Flutter SDK, Dart, Supabase CLI, wichtige Pakete aus `pubspec.yaml`)
- Branch-Regeln: nie direkt auf `main`, immer `feature/<slug>`
- Workflow: Plan → Code → analyze → test → security-review → commit → PR
- Lint-Befehl: `flutter analyze`, Test: `flutter test`
- Supabase: Migrations via `supabase migration new`, lokal via `supabase db reset` testen, **NIE `supabase db push` ohne explizite User-Bestätigung**
- l10n: jeder neue String muss in `lib/l10n/*.arb` (de + en), nicht hardcoden
- Theme: nur Tokens aus `lib/app_theme.dart`
- Provider-Pattern beibehalten (kein Riverpod-Mix)
- `.env`, `supabase/config.toml` mit Secrets, `lib/config/supabase_config.dart` mit Keys → trotz Pre-Launch nicht aus Versehen exposen (sonst spätere Key-Rotation)
- Pricing-Logik (`PricingPlan`) und Billing — Logik darf weiterentwickelt werden, aber Tests/Smoke-Test vor Merge

### 3.2 Subagenten unter `.claude/agents/`

Sechs Agenten, alle mit YAML-Frontmatter und Modell-Pinning:

| Agent | Modell | Tools | Zweck |
|---|---|---|---|
| `planner` | opus | Read, Glob, Grep, WebSearch | Erstellt `plans/*.md` aus Feature-Request |
| `flutter-coder` | sonnet | Read, Edit, Write, Bash, Glob, Grep | Dart-Code in `lib/` |
| `edge-fn-coder` | sonnet | Read, Edit, Write, Bash | Deno/TS in `supabase/functions/` |
| `db-migrator` | sonnet | Read, Edit, Write, Bash | Migrations + RLS-Policies, lokales `db reset` |
| `ui-builder` | sonnet | Read, Edit, Write, Glob | Widgets/Screens, l10n-Pflege, Theme-Konformität |
| `tester` | sonnet | Bash, Read, Edit | `flutter analyze` + `flutter test`, fixt Failures |
| `security-reviewer` | opus | Read, Grep, Glob, Bash | RLS-Audit, Secret-Scan, Input-Validation, OWASP |

Jeder Agent bekommt einen **knappen System-Prompt mit Erfolgs- und Stop-Kriterien** — nicht das übliche Wall-of-Text-Manifest.

### 3.3 Hooks in `.claude/settings.json` (NICHT `settings.local.json`, das bleibt für persönliche Permissions)

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "hooks": [{ "type": "command", "command": ".claude/scripts/post-edit.sh" }]
    }],
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{ "type": "command", "command": ".claude/scripts/guard-bash.sh" }]
    }]
  }
}
```

**Scripts** (`.claude/scripts/`):

- `post-edit.sh` → wenn `.dart` editiert: `flutter analyze` auf das geänderte Modul (nicht das ganze Repo, dauert 30s+); wenn `.ts` in `supabase/functions/`: `deno check`
- `guard-bash.sh` → blockiert hart:
  - `supabase link --project-ref <prod>` (das Verlinken eines Prod-Projects, falls eines existiert — solange du nur ein Dev-Project hast, ist das harmlos)
  - `git push -f origin main`, `git reset --hard origin/*`, `rm -rf` außerhalb `build/`/`.dart_tool/`/`.next/`
  - `flutter pub publish`
  - Schreiben in `lib/config/supabase_config.dart` ohne explizite Bestätigung
  - Schreiben in `android/app/google-services.json` und `ios/Runner/GoogleService-Info.plist`

**Auto-Commit JA, aber mit Whitelist:** Stop-Hook führt aus:
```bash
git add lib/ supabase/migrations/ supabase/functions/ test/ pubspec.yaml pubspec.lock plans/ .github/
git commit -m "auto: $(cat .claude/last-task.txt 2>/dev/null || echo 'work')"
git push origin "$(git branch --show-current)"
```
Niemals `git add .` — sonst landen `prompt_archive/`, CSV-Exports und `.DS_Store`-Müll im Repo.

### 3.4 Slash-Commands unter `.claude/commands/`

- `/plan <feature>` → ruft `planner`
- `/work <plan-file>` → orchestriert die Coder-Agenten gegen einen Plan
- `/ship` → führt `flutter analyze`, `flutter test`, `security-reviewer`, dann commit auf aktuellen Feature-Branch + push + öffnet PR via `gh pr create`
- `/migrate <name>` → ruft `db-migrator`, läuft `supabase db reset` lokal, regeneriert keine Types (Flutter nutzt sie nicht wie TS)

### 3.5 GitHub Actions (`.github/workflows/`)

Zwei Workflows, beide nur auf PRs gegen `main`:

1. **`flutter-ci.yml`**: `flutter pub get` → `flutter analyze` → `flutter test` → optional Build-Smoke (Web)
2. **`claude-review.yml`**: Nutzt `anthropics/claude-code-action@v1` + `anthropics/claude-code-security-review@main`. Promptet auf: RLS-Coverage neuer Tabellen, Secret-Leaks, l10n-Vollständigkeit, Theme-Konformität, Provider-Konsistenz. Braucht `ANTHROPIC_API_KEY` als Repo-Secret.

**Bewusst nicht in CI:** `supabase db push`, App-Store-Builds, jegliches Deployment. Bleibt manuell.

### 3.6 Modell-Routing-Strategie

| Task | Modell | Begründung |
|---|---|---|
| Planung großer Features (>3 Files) | Opus 4.7 | Muss App-Architektur + neuen Plan parallel im Kopf halten |
| Security-Review | Opus 4.7 | Adversariales Denken, RLS-Kombinatorik |
| Routine-Coding (1 Provider, 1 Screen) | Sonnet 4.6 | Schnell, günstig, scoped |
| UI-Polish, l10n-Strings, kleine Widgets | Sonnet 4.6 oder Haiku 4.5 | Mechanisch |
| Migrations (RLS-kritisch!) | Opus 4.7 | Fehler hier sind teuer |
| Bug-Fix mit klar lokalisiertem Stack-Trace | Sonnet 4.6 | Scope ist eng |

---

## 4. Phasenplan (gestrafft, weil Pre-Launch)

### Phase 1 — Fundament (heute, 1–2 Stunden)
1. `CLAUDE.md` schreiben
2. `plans/` ✅ existiert bereits
3. `.claude/agents/` mit allen 6 Agenten anlegen (planner, flutter-coder, edge-fn-coder, db-migrator, ui-builder, tester, security-reviewer)
4. `guard-bash.sh` Hook (Block-Regeln) + `post-edit.sh` Hook (`flutter analyze`)
5. Auto-Commit-Hook mit Whitelist + Auto-Push auf Feature-Branch
6. Slash-Commands `/plan`, `/work`, `/ship`, `/migrate`

### Phase 2 — GitHub-Integration (diese Woche)
7. `gh` CLI prüfen, `ANTHROPIC_API_KEY` als Repo-Secret setzen
8. `.github/workflows/flutter-ci.yml` (analyze + test)
9. `.github/workflows/claude-review.yml` mit `claude-code-action@v1` und `claude-code-security-review`
10. PR-Template mit Smoke-Test-Checkliste

### Phase 3 — Auto-Merge + Test-Coverage (Woche 2)
11. Test-Coverage gezielt ausbauen — Service-Layer (`lib/services/`) und Provider zuerst, weil mockbar
12. Auto-Merge auf `main` aktivieren, sobald CI grün UND Claude-Review ohne `severity:high`
13. Eine Woche beobachten, Review-Qualität messen

### Phase 4 — Headless-Loop (Woche 3, optional)
14. `claude --print` mit kleinem Backlog-File, in Cron alle paar Stunden gegen einen Backlog-Ordner
15. `--max-budget-usd` pro Run setzen (Token-Cost-Cap)
16. Daily-Digest-Mail/Notification, was nachts gemerged wurde

**Was bleibt manuell:**
- UI-Smoke-Test im Emulator/Device (gebatcht, 1–3× pro Woche)
- `supabase db push` gegen Prod (sobald Prod existiert)
- Dependency-Updates in `pubspec.yaml` (Supply-Chain-Risiko)
- App-Store-Signing/-Releases

---

## 5. Kosten-Realismus

Multi-Agent-Workflows verbrauchen Tokens. Grobe Schätzung pro Feature mittlerer Größe:
- Planner (Opus, ~5k input/2k output): ~$0.15
- 3× Coder-Agenten (Sonnet, je ~30k/5k): ~$0.45
- Tester-Loop (Sonnet, 5 Iterationen, ~50k total): ~$0.20
- Security-Reviewer (Opus, ~10k/2k): ~$0.30

→ **~$1–2 pro Feature**, plus die GitHub-Action pro PR (~$0.10–0.30). Bei 10 Features/Woche → ~$50–100/Monat. Mit `--max-budget-usd` deckeln.

---

## 6. Was bleibt manuell (auch im Pre-Launch)

- Schreiben in `lib/config/supabase_config.dart` (Keys-Schutz)
- `supabase link --project-ref` gegen ein Prod-Project (sobald existiert)
- Dependency-Bumps in `pubspec.yaml` (Supply-Chain-Risiko ist nicht von Pre-Launch entkoppelt)
- Änderungen an `android/app/build.gradle.kts`, `ios/Runner.xcodeproj`, Signing-Configs
- Firebase-Konfiguration (`google-services.json`, `GoogleService-Info.plist`)
- `flutter pub publish`
- App-Store-/Play-Store-Releases

**Auto-Merge auf `main` ist OK** ab Phase 3, solange CI + Claude-Review grün sind. Wird vor Launch wieder eingeschränkt.

---

## 7. Antwort auf deine Frage

**„Ist das umsetzbar?"** Ja, und im Pre-Launch sogar gut. Die Adaption für Flutter + Supabase steht oben. Phasen 1–3 in ~2 Wochen einführbar, Phase 4 (Headless-Loop) optional.

**„Wie würdest du das perfekte Ökosystem bauen?"** Stark autonom mit Auto-Commit/-Push/-Merge in Feature-Branches → `main`, abgesichert durch:
1. Whitelist-Auto-Add (nicht `git add .`)
2. `flutter analyze` + `flutter test` als CI-Gate
3. Claude Security-Review als zweites Gate
4. Bash-Guard gegen destruktive Aktionen + Secret-Files
5. Versionierung in Git als ultimatives Sicherheitsnetz
6. Eine wöchentliche manuelle UI-Smoke-Session durch dich

**Empfehlung:** Direkt **Phase 1 + 2** zusammen anlegen (~2 Stunden Arbeit von mir), weil im Pre-Launch keine Notwendigkeit für die langsame Beobachtungs-Phase besteht.

**Wenn du „los" sagst, lege ich an:**
1. `CLAUDE.md` (Projekt-spezifisch, nutzt deine echten Pakete und Conventions)
2. Alle 7 Subagenten in `.claude/agents/`
3. `.claude/scripts/guard-bash.sh`, `post-edit.sh`, `auto-commit.sh`
4. `.claude/commands/plan.md`, `work.md`, `ship.md`, `migrate.md`
5. `.github/workflows/flutter-ci.yml` und `claude-review.yml`
6. Hinweis am Ende: was du noch manuell machen musst (`gh secret set ANTHROPIC_API_KEY`, GitHub-App installieren via `/install-github-app`)
