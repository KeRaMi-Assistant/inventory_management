# Strict-Tracking Smoke-Audit-Plan (PR #69)

`[Committee-Approved 2026-05-15]`

> **Council-Review: 2026-05-15** (Architekt + Bug-Hunter + External-Scout + Security + UX/Mobile)
> 10 Pflicht-Änderungen integriert, 4 Empfehlungen integriert, jkeen/Patrol-Recommendation: Hybrid (alchemist optional).
> Security-Findings: 3× high (Credentials, Seed-SQL-Scope, Rate-Limit-Bypass) — alle gefixt.
> Bug-Hunter-Findings: 3× kritisch (Seed-Tabellenname, S7-Architekturannahme, fehlende Keys) — alle gefixt.

## 1. Ziel

Nachgeholter Smoke-Audit (T15 aus Original-Plan) für PR #69
`feature/strict-tracking-extraction`. **PASS-Definition:** Alle 5
`TrackingStatusBlock`-States (strong / manual / empty / needsReview /
amazonShipmentIdOnly) werden in Inbox-Detail + Deal-Detail korrekt
gerendert; Re-Parse-Flow (Loading / Success / Rate-Limit / Offline)
funktioniert end-to-end; Filter-Chip "Prüfen ({count})" auf
Deals-Liste filtert; Banner + Counter-Badge (Drawer-Nav) +
Suggestion-Card-Badge sichtbar bei `count > 0`; **keine neuen
Dart-Console-Errors** aus `tracking_*`-Pfaden. PR ist erst mergeable
wenn alle 5 Mega-Szenarien (A-E) + Console-Audit PASS oder als WARN
klassifiziert sind.

## 2. Pre-Conditions

### 2.1 Test-Credentials (NIEMALS im Klartext)

- **Test-Account:** aus `.env.test` laden — `TEST_USER_EMAIL` /
  `TEST_USER_PW`. KEINE hartcodierten Mail-Adressen / Passwörter in
  diesem Plan oder Audit-Reports.
- **Loader-Snippet** (Browser-Tester + Seed-Runner):
  ```bash
  set -a; source .env.test; set +a
  : "${TEST_USER_EMAIL:?TEST_USER_EMAIL fehlt — bitte .env.test aus .env.test.example kopieren}"
  : "${TEST_USER_PW:?TEST_USER_PW fehlt}"
  ```
- **Abort-Bedingung:** Wenn `.env.test` fehlt → Audit sofort
  abbrechen, User-Notify: "Kopiere `.env.test.example` nach
  `.env.test` und fülle TEST_USER_EMAIL/TEST_USER_PW."
- **Followup-Item (parallel):** `chore/redact-test-creds-in-committed-files`
  — bereits-committete Klartext-Credentials in
  `.claude/agents/browser-tester.md` + `plans/2026-05-07_browser_testing.md`
  redacten. Eigener Inbox-Eintrag, NICHT Blocker dieses Audits.

### 2.2 Build-Mode (Dart-Exceptions sichtbar)

- `bash .claude/scripts/dev-web.sh` macht heute **Release-Build** →
  Dart-Exceptions sind silent. Audit MUSS auf Profile-Build laufen.
- **TA0b** ergänzt `--profile`-Flag in `dev-web.sh` (oder neues
  Script `dev-web-profile.sh`). Bis Implementierung: Tester startet
  manuell `flutter run -d chrome --profile --web-port 8123`.

### 2.3 Demo-Workspace + Seed

- Mind. 4 Test-Deals + 1 Inbox-Suggestion mit diversen Tracking-
  Konstellationen (siehe Sektion 4 Seed-SQL — repariert).
- Pre-Insert Schema-Assert: `SELECT column_name FROM
  information_schema.columns WHERE table_name='deals' AND column_name
  IN ('tracking_carrier','tracking_confidence','tracking_needs_review')`
  muss alle 3 zurückgeben — sonst Abort.

### 2.4 Browser/Runtime

- **Web-Build:** Profile-Mode auf Port 8123. Vorher
  `bash .claude/scripts/stop-web.sh`.
- **Cache-Bypass:** Navigation auf
  `http://127.0.0.1:8123/?nocache=$(date +%s)` + vor jedem Login
  Hard-Reload + `application.serviceWorker.unregister`.
- **Console-Capture:** Playwright `page.on('console')` +
  `page.on('pageerror')` Hooks. Level Verbose, Preserve log.
- **Rate-Limit-Reset (S3):** Via Test-Mode-Override-Pfad in
  `inbox-parse` Edge-Function (TA0c). KEIN direkter SQL-UPDATE-
  Bypass mehr.

### 2.5 Cost-Pre-Flight

- Vor TA2 Start: `bash .claude/scripts/lib/cost-cap.sh check-or-die 8 25`
  (oder Inline-Check falls Helper nicht existiert).
- Pro Browser-Tester-Task: `--max-budget-usd 8`.

## 3. Audit-Szenarien (5 Mega-Szenarien)

Bündelung von ursprünglich 18 atomaren Szenarien zu 5 Mega-Runs
(Browser-Tester ist single-threaded, Login-Cost pro Run dominiert).
Console-Audit (S18) bleibt als Aggregations-Pass.

### Mega-A — Re-Parse-Flow (S1-S4)

**Pre-State:** Logged in (`.env.test`-Loader), Cooldown via
Test-Mode-Override entsperrt (TA0c).

**S1 — Settings-Re-Parse-Button sichtbar**
- Klick-Pfad: Drawer → "Einstellungen" → Tab "Postfach" → Scroll bis
  Key `tracking-reparse-cta`.
- Accept: Key findbar + enabled, nicht hinter Scroll verborgen
  (Phone-Viewport). Screenshot `s1-settings-reparse-cta.png`.

**S2 — Re-Parse Confirm-Dialog + Success**
- Klick-Pfad: Tap CTA → Confirm (Key `tracking-reparse-confirm`).
- Accept: Loading-Snackbar `trackingReparseRunning` →
  Success-Snackbar `trackingReparseSuccessCount` mit N≥0.
  Screenshots `s2a-dialog.png`, `s2b-success.png`.

**S3 — Re-Parse Rate-Limit (429) — ehrlicher Cooldown-Test**
- Direkt nach S2 (Cooldown aktiv, NICHT zurückgesetzt).
- Accept: Snackbar `trackingReparseFailed` mit Retry-After
  Sekunden > 0. Kein Stack-Trace. Screenshot `s3-rate-limit.png`.
- **Wichtig:** Reset für S4 nur via Test-Mode-Override-Pfad
  (`POST /inbox-parse {test_mode_override:'reset_cooldown'}` mit
  Test-User-Auth), NICHT via SQL-Bypass.

**S4 — Re-Parse Offline (Playwright-API)**
- Klick-Pfad: `context.setOffline(true)` → Tap CTA → Confirm →
  `context.setOffline(false)` nach Snackbar.
- Accept: Snackbar `trackingReparseOffline`.
- **Validation-Pre-Step:** Code-Lookup auf
  `supabase/functions/inbox-parse/index.ts` + `_TrackingReparseTile`
  Error-Pfad. Wenn `SocketException` in Web nie geworfen wird (nur
  `ClientException` aus `package:http`), Snackbar-Pfad anpassen oder
  S4 als WARN klassifizieren.

### Mega-B — Count-Surfaces (S5-S8)

**S5 — Filter-Chip auf Deals-Screen**
- Pre-State: ≥1 Deal mit `tracking_needs_review=true`.
- Klick-Pfad: Nav → "Deals" → Filter-Bar.
- Accept: Chip `filter-chip-tracking-needs-review` mit Label
  `({n})`, n≥1. Tap → Liste filtert. Screenshots `s5-filter-chip.png`,
  `s5b-filtered-list.png`.
- Negativ: Chip darf bei count=0 NICHT sichtbar sein (siehe S20).

**S6 — Banner "Improved Detection" + Dismiss**
- Pre-State: count>0 + LocalStorage-Key
  `flutter.tracking_banner_dismissed_v1` cleared.
- Klick-Pfad: Inbox → Banner sichtbar → Close → Reload (F5).
- Accept: Banner nach Reload weg.

**S7 — Counter-Badge im Drawer/Mobile-Nav (KORRIGIERT)**
- **Architektur-Realität:** `MainScreen` rendert bei `width<800`
  einen Drawer + `_MobileNavList`, KEIN `BottomNavigationBar`.
- Pre-State: Phone-Viewport 390×844 + needs_review-Count > 0.
- Klick-Pfad: Drawer öffnen → Eintrag "Inbox" inspizieren.
- Accept: Counter-Badge sichtbar via Key
  `mobile-nav-inbox-badge` (wird in TA0a gesetzt) oder
  aria-label-Fallback. Counter == Filter-Chip-Count aus S5.
  Screenshot `s7-drawer-badge.png`.
- **Worst-Case:** count=127 → Badge-Layout auf collapsed Sidebar
  (64px) bleibt im Bounds.

**S8 — Suggestion-Card "Prüfen"-Badge**
- Klick-Pfad: Inbox → Suggestions → erste needs_review-Card.
- Accept: Key `inbox-suggestion-card-needs-review-badge` findbar.
  Screenshot `s8-suggestion-card-badge.png`.

### Mega-C — State-Matrix (S9-S12)

Alle 5 `TrackingStatusBlock`-States.

**S9 — needsReview (Inbox-Detail-Sheet)**
- Klick-Pfad: Suggestion → "Details & Tracking" Bottom-Sheet.
- Accept: Gelber Indikator, Tracking sichtbar, 3 CTAs findbar
  (`tracking-accept-cta`, `tracking-manual-input-cta`,
  `tracking-discard-cta`). Screenshot `s9-needsreview-state.png`.

**S10 — strong (Deal-Detail)**
- Pre-State: Deal mit `tracking_confidence='strong'`.
- Accept: Carrier-Label + grüner OK-Indikator, read-only.
  Screenshot `s10-strong-state.png`.

**S11 — empty**
- Pre-State: Deal ohne Tracking + needs_review=false.
- Accept: "Keine Sendungsnummer erkannt" + Manual-Input-CTA.
  Screenshot `s11-empty-state.png`.

**S12 — amazonShipmentIdOnly**
- Pre-State: Suggestion mit `parsed_payload.tracking_candidates[*].source=='amazon-shipment-id'`.
- Accept: Amazon-Logistics-Hinweis, kein externer Wert.
  Screenshot `s12-amazon-only.png`.

(State `manual` wird in Mega-D durch S13/S14 erzeugt + verifiziert.)

### Mega-D — Aktionen (S13-S15)

**S13 — Manuell-Input-Flow**
- Pre-State: S11 offen.
- Klick-Pfad: Tap `tracking-manual-input-cta` → Dialog →
  `1Z999AA10123456784` → Bestätigen.
- Accept: State wechselt zu `manual`. Screenshots `s13a-input-dialog.png`,
  `s13b-manual-state.png`.

**S14 — Accept-as-Correct**
- Pre-State: S9 offen.
- Accept: State → `manual`, Suggestion-Badge weg, Counter -1.
  Screenshot `s14-after-accept.png`.

**S15 — Discard**
- Pre-State: Zweite needs_review-Card S9-artig öffnen.
- Accept: State → `empty`, Counter -1. Screenshot `s15-after-discard.png`.

### Mega-E — Theme + Mobile + l10n + Edge-Cases (S16-S17, S19-S21)

**S16 — Theme-Switch (Dark) für alle 5 States**
- Settings → Theme "Dunkel" → Mega-C wiederholen.
- Accept: Keine hardcoded `Colors.*`. Screenshots `s16-*-dark.png`.

**S17 — Mobile-Overflow + Touch-Target-Matrix**
- **4-Viewport-Matrix:** 360×640, 390×844, 768×1024, 1440×900.
- Pflicht-Cases pro Viewport: `needsReview`-State + Manuell-Input-
  Dialog.
- Touch-Target-Messung via DevTools-Box-Model: alle CTAs
  (`tracking-accept-cta`, `tracking-manual-input-cta`,
  `tracking-discard-cta`, `_IconCta` in Strong/Manual) MÜSSEN ≥48dp.
- **UX-Bug-Hunter-Hinweis:** `_IconCta padding: EdgeInsets.all(12)`
  ergibt nur 42dp Hit-Box → potentieller Blocker. Falls bestätigt →
  TA0d-Fix (Padding auf 14 erhöhen oder explizit `constraints:
  BoxConstraints(minWidth: 48, minHeight: 48)`).
- Screenshots `s17-<viewport>-<case>.png` (8 Bilder).

**S19 — l10n-EN-Switch (neu)**
- Settings → Sprache EN → Mega-C + Mega-D wiederholen auf 360×640.
- Accept: Kein Overflow bei längeren EN-Strings. Screenshots
  `s19-en-*.png`.

**S20 — Empty-Workspace-Negativ (neu)**
- Seed-Variante mit 0 needs_review-Deals (siehe Seed-Sektion 4.2).
- Accept: Chip, Banner, Counter-Badge ALLE abwesend.
  Screenshot `s20-empty-state.png`.

**S21 — Keyboard-Coverage Phone (neu)**
- 390×844, Manuell-Input-Dialog offen, TextField fokussiert,
  `viewInsets.bottom=300` simuliert.
- Accept: TextField sichtbar, Buttons via Scroll erreichbar.
  Screenshot `s21-keyboard.png`.

### S18 — Console-Errors-Audit (Aggregation)

- Alle `console.error` + Dart-Exceptions aus Mega-A bis Mega-E.
- Vergleich mit Baseline `.claude/test-runs/baseline-pre-69.json`
  (neu erstellen falls nicht vorhanden).
- Blocker: Jeder neue Error aus `tracking_*`, `inbox_*`,
  `mailbox_*`. Akzeptabel: Firebase-Init-Warnings, Image-404-Demo.

## 4. Seed-SQL (kritisch repariert)

### 4.1 Haupt-Seed (Mega-A bis Mega-E)

```sql
-- Pre-condition: Dev-DB-Guard
DO $$ BEGIN
  IF current_database() NOT LIKE '%dev%' AND current_database() <> 'postgres' THEN
    RAISE EXCEPTION 'Audit-Seed darf nur gegen Dev-DB laufen (db=%)', current_database();
  END IF;
END $$;

-- Schema-Assert: alle 3 Spalten müssen existieren
DO $$ DECLARE col_count int; BEGIN
  SELECT count(*) INTO col_count FROM information_schema.columns
    WHERE table_schema='public' AND table_name='deals'
    AND column_name IN ('tracking_carrier','tracking_confidence','tracking_needs_review');
  IF col_count <> 3 THEN
    RAISE EXCEPTION 'deals-Schema fehlt erwartete Tracking-Spalten (gefunden %/3)', col_count;
  END IF;
END $$;

-- Test-User-Email muss als runtime-config gesetzt sein:
--   psql ... -v test_user_email="$TEST_USER_EMAIL" -c "SET app.test_user_email = :'test_user_email';" -f seed.sql
-- Pre-condition: exact 1 workspace
DO $$ DECLARE ws_count int; BEGIN
  SELECT count(*) INTO ws_count
    FROM workspace_members wm
    JOIN auth.users u ON u.id = wm.user_id
    WHERE u.email = current_setting('app.test_user_email', true);
  IF ws_count <> 1 THEN
    RAISE EXCEPTION 'Test-User muss in genau einem Workspace sein (gefunden: %)', ws_count;
  END IF;
END $$;

-- Idempotenz-Cleanup
DELETE FROM public.deals WHERE title LIKE 'Audit-%';
DELETE FROM public.parsed_messages WHERE subject LIKE 'Audit-%';

-- Helper-CTEs als reuse
WITH ws AS (
  SELECT wm.workspace_id, u.id AS user_id
  FROM workspace_members wm
  JOIN auth.users u ON u.id = wm.user_id
  WHERE u.email = current_setting('app.test_user_email', true)
  ORDER BY wm.created_at ASC
  LIMIT 1
)
INSERT INTO public.deals
  (workspace_id, title, tracking, tracking_carrier,
   tracking_confidence, tracking_needs_review, created_by, created_at)
SELECT workspace_id, 'Audit-Strong',   '1Z999AA10123456784', 'UPS',
       'strong', false, user_id, now() FROM ws
UNION ALL
SELECT workspace_id, 'Audit-NeedsReview', 'XYZ-LEGACY-123', NULL,
       'none', true, user_id, now() FROM ws
UNION ALL
SELECT workspace_id, 'Audit-Empty', NULL, NULL, NULL, false, user_id, now() FROM ws
UNION ALL
SELECT workspace_id, 'Audit-Manual', 'DHL-MANUAL-9999', 'DHL',
       'manual', false, user_id, now() FROM ws
ON CONFLICT DO NOTHING;

-- Inbox-Suggestion mit nur amazon-shipment-id
-- KORRIGIERT: Tabelle heißt parsed_messages, NICHT inbox_messages
INSERT INTO public.parsed_messages
  (workspace_id, subject, parsed_payload, needs_review, created_at)
SELECT (SELECT workspace_id FROM workspace_members wm
          JOIN auth.users u ON u.id = wm.user_id
          WHERE u.email = current_setting('app.test_user_email', true)
          ORDER BY wm.created_at ASC LIMIT 1),
       'Audit-Amazon-Logistics',
       jsonb_build_object('tracking_candidates',
         jsonb_build_array(jsonb_build_object(
           'value','TBA123456789','source','amazon-shipment-id',
           'confidence','none'))),
       true, now();
```

> Bei Abweichung der Spaltennamen → `db-migrator` adaptiert Seed VOR
> Run (Schema-Assert oben failt loud).

### 4.2 Negativ-Seed (für S20)

```sql
-- Variante: clear alle needs_review-Flags
UPDATE public.deals SET tracking_needs_review = false
  WHERE workspace_id = (SELECT workspace_id FROM workspace_members wm
    JOIN auth.users u ON u.id = wm.user_id
    WHERE u.email = current_setting('app.test_user_email', true) LIMIT 1);
UPDATE public.parsed_messages SET needs_review = false
  WHERE workspace_id = (SELECT workspace_id FROM workspace_members wm
    JOIN auth.users u ON u.id = wm.user_id
    WHERE u.email = current_setting('app.test_user_email', true) LIMIT 1);
```

## 5. Browser-Tester-Anker-Tabelle

| Key | Screen/Widget | l10n-Fallback |
|---|---|---|
| `tracking-reparse-cta` | settings_screen (Postfach-Tab) | `trackingReparseCta` |
| `tracking-reparse-confirm` | Confirm-Dialog | `trackingReparseConfirmCta` |
| `tracking-banner-improved-detection` | inbox_screen + deal_table | `trackingBannerImprovedDetection` |
| `mobile-nav-inbox-badge` *(neu, TA0a)* | drawer + `_MobileNavList` | – |
| `inbox-suggestion-card-needs-review-badge` | suggestion_card | `trackingNeedsReviewBadge` |
| `filter-chip-tracking-needs-review` | deal_table Filter-Bar | `trackingNeedsReviewFilterChip` |
| `tracking-accept-cta` | tracking_status_block | `trackingAcceptAsCorrect` |
| `tracking-manual-input-cta` | tracking_status_block | `trackingManualInputCta` |
| `tracking-discard-cta` | tracking_status_block | `trackingDiscardCta` |
| `tracking-status-block` | Container-Root | – |

## 6. Akzeptanz

- **PASS:** 5/5 Mega + Console-Audit grün, 0 neue Console-Errors →
  `gh pr merge 69`.
- **WARN:** 1-2 Polish-Findings (Spacing, Theme-Detail) →
  Followup-Items, PR darf mergen.
- **FAIL:** ≥1 Mega blocked, neuer Crash, oder Counter-Mismatch →
  Fix vor Merge.

## 7. Risiken

- **Service-Worker-Cache:** alter Build sticky → `?nocache=` +
  SW-Unregister Pflicht.
- **Seed-Schema-Drift:** Spaltennamen ändern sich → Schema-Assert
  failt loud, nicht silent.
- **Animation-Race (Sheets+Snackbars):** Playwright
  `waitForSelector({state:'visible', timeout:8000})` statt fixed
  sleeps.
- **Rate-Limit-Cooldown (5min) bei S3:** Test-Mode-Override-Pfad
  (TA0c) statt SQL-Bypass.
- **Web-Offline-Pfad:** wenn Dart-Web `SocketException` nie wirft →
  S4 als WARN, nicht Blocker.
- **i18n-Drift während Audit:** `flutter gen-l10n` vor Audit.
- **TA0d-Risk:** Touch-Target-Fix in `_IconCta` könnte Layout
  verschieben → visuelle Regression in S10/S16 möglich.
- **Cost-Overrun:** 5 Mega à $8 + Buffer = $25 cap. Bei Überlauf
  `cost-cap.sh` Hard-Stop.

## 8. Out-of-Scope

- Lighthouse / Performance.
- A11y-Screen-Reader.
- iOS / Android-Native-Smoke.
- Backend-Re-Parse-Job-Korrektheit (nur UI-Verhalten).

## 9. Tasks

### Pre-Audit-Code-Fixes (TA0-Familie)

- [x] **TA0a** — `Key('mobile-nav-inbox-badge')` in
  `lib/screens/main_screen.dart` (`_NavItem` / `_MobileNavList`)
  setzen wenn `badgeCount > 0`. _agent: `flutter-coder`, est: 15min._
- [ ] **TA0b** — `--profile`-Flag in `.claude/scripts/dev-web.sh`
  ergänzen ODER neues `dev-web-profile.sh` anlegen. _agent:
  `flutter-coder`, est: 15min._
- [ ] **TA0c** — Test-Mode-Override in
  `supabase/functions/inbox-parse/index.ts`: wenn
  `body.test_mode_override === 'reset_cooldown'` UND
  `auth.uid()` == Owner von `TEST_USER_EMAIL` → setze
  `last_reparse_at=NULL`, sonst 403. _agent: `edge-fn-coder`, est:
  30min._
- [ ] **TA0d** — Touch-Target-Fix `_IconCta` (Padding/Constraints
  ≥48dp) falls Box-Model-Messung in S17 <48dp bestätigt. _agent:
  `flutter-coder`, est: 15min — optional, nur bei Bestätigung._
- [x] **TA0e** *(optional)* — `SemanticsBinding.instance.ensureSemantics()`
  in `lib/main.dart` hinter `--dart-define=ENABLE_SEMANTICS=true`
  für Profile-Build. Browser-Tester kann dann `getByLabel()` statt
  Text-Fallback. _agent: `flutter-coder`, est: 30min._

### Audit-Tooling

- [ ] **TA1** — Demo-Seed-SQL (Sektion 4.1) idempotent anwenden +
  Schema-Assert + Workspace-Scope-Assert. _agent: `db-migrator`,
  est: 30min._
- [ ] **TA2.0** — `smoke-suite-runner.json` für browser-tester:
  deklaratives Array `{id, preState, steps[], asserts[],
  screenshots[]}` für Mega-A bis Mega-E. Spart Prompt-Duplikation.
  _agent: `flutter-coder`, est: 45min._

### Audit-Runs

- [ ] **TA2** — Browser-Tester Mega-A (Re-Parse-Flow S1-S4).
  _agent: `browser-tester`, est: 1h, `--max-budget-usd 8`._
- [ ] **TA3** — Browser-Tester Mega-B + Mega-C (Count-Surfaces +
  State-Matrix). _agent: `browser-tester`, est: 1.5h,
  `--max-budget-usd 8`._
- [ ] **TA4** — Browser-Tester Mega-D + Mega-E (Aktionen + Theme +
  4-Viewport-Matrix + l10n + Empty + Keyboard). _agent:
  `browser-tester`, est: 2h, `--max-budget-usd 8`._
- [ ] **TA5** — Console-Errors-Aggregation (S18) + Baseline-Diff +
  Markdown-Report. _agent: `browser-tester`, est: 30min,
  `--max-budget-usd 4`._

### Post-Audit

- [ ] **TA6** — Bei Findings: atomare Followup-Items
  (`00-followup-…`) ins Inbox. _agent: `planner`, est: 15min._
- [ ] **TA7** — `_page-registry.md`-Eintrag für
  `tracking_status_block.dart` als Sub-Route von Inbox-Detail +
  Deal-Detail; neuer Pflicht-Test-Key `smoke-tracking-states`
  definieren. _agent: `doc-updater`, est: 15min._
- [ ] **TA-NEU** *(optional, nice-to-have)* — 5 Golden-Tests via
  `alchemist` für `TrackingStatusBlock`-States in
  `test/widgets/tracking_status_block_golden_test.dart`. Catched
  State-Matrix deterministisch in CI. _agent: `flutter-coder`, est:
  1h. Skipbar wenn time-critical._

### Parallel

- [ ] **TA-PAR** — `chore/redact-test-creds-in-committed-files`:
  Klartext-Credentials in `.claude/agents/browser-tester.md` +
  `plans/2026-05-07_browser_testing.md` redacten. Separates
  Inbox-Item, kein Blocker. _agent: `flutter-coder`, est: 15min._

## 10. Critical Path

```
TA0a + TA0b + TA0c  ──►  TA1 ──► TA2.0 ──►  TA2 ──► TA3 ──► TA4 ──► TA5
                                                      │
                                          TA0d (nur bei S17-Bestätigung)
                                                      ▼
                                                (TA6 bei Findings) ──► TA7
```

TA0a/b/c sind parallelisierbar (verschiedene Agents). TA0e + TA-NEU
+ TA-PAR sind off-critical-path. Total Audit-Kern est: ~6.5h
sequenziell + ~1h Pre-Fixes. Cost-Cap (Sektion 11) limitiert
Audit-Runs.

## 11. Cost-Cap

| Task | Budget |
|---|---|
| TA2 (Mega-A) | $8 |
| TA3 (Mega-B+C) | $8 |
| TA4 (Mega-D+E, 4-Viewport-Matrix) | $8 |
| TA5 (Aggregation) | $4 |
| **Total Hard-Cap** | **$25** |

Pre-Flight Check vor TA2:
```bash
bash .claude/scripts/lib/cost-cap.sh check-or-die 8 25
```
(Falls Helper nicht existiert → Inline-Check via `cost-tracker.sh`
oder ähnlich. Hard-Stop bei Überlauf, manueller Reset via
`resume.sh`.)

Pre-Audit-Code-Fixes (TA0a-e) laufen außerhalb des Audit-Cap, da
das `flutter-coder`/`edge-fn-coder`-Budget separat liegt.
