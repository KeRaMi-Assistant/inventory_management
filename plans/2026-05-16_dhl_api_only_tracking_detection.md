# DHL-API-Only Tracking-Detection

**Status:** Draft → Implementation
**Owner:** keramo
**Datum:** 2026-05-16
**Vorgänger-PR:** #82 (DHL-Tracking-Aktivierung mit Master-Key-Bootstrap)

## Problem

In der Inbox-Suggestion-Card (`lib/screens/inbox_screen.dart:1114-1126`)
sieht der Stakeholder pro Mail bis zu 4+ Tracking-Pills, obwohl die Mail
nur eine echte Tracking-Nummer enthält. Quelle: die Pattern-Heuristik in
`supabase/functions/_shared/inbox_adapters.ts:260-344` findet pro Mail
mehrere "strong"-Kandidaten (Bestellnr, Kundennr, Rechnungsnr und echte
Tracking-Nr — alle als 12-22-stellige Zahl mit Anchor matchend). In
`resolveTrackingForAdapter` (Zeilen 982-988) werden alle strongs in
`trackings: string[]` persistiert und vom UI als Pill-Reihe gerendert.

Stakeholder-Wunsch (verbatim):
> "alte Trackingfindungslogik raus, es soll immer über api erfolgen"
> "Hermes/GLS/Amazon/DPD/UPS: komplett ausschalten"

## Ziel

Tracking-Detection läuft **ausschließlich** über DHL-API-Validation gegen
den im Workspace gespeicherten DHL-API-Key. Alle Pattern-basierten
Carrier-Detection-Pfade (UPS, Amazon, S10-UPU, generic context-anchor)
werden entfernt oder deaktiviert. Per Mail höchstens 1 Tracking-Nummer
in `trackings[]`. Mails ohne DHL-API-Treffer haben `tracking=NULL,
trackings=[], tracking_confidence='none'` — der User pflegt manuell.

## Scope

**In-Scope:**

- `TRACKING_PATTERNS` reduzieren auf DHL-spezifische Patterns (JJD-Prefix,
  DE-Prefix, DE-Suffix). Alles andere raus.
- API-Validation-Layer: pro Kandidat ein DHL-API-Probe-Call. Nur Treffer
  landen in `trackings`.
- DB-seitiger Validation-Cache (workspace-scoped), um wiederholte
  Probe-Calls zu vermeiden.
- Inbox-Parse-Runner zieht den DHL-API-Key des Workspaces beim Parsen.
- Fehlt der Key → Detection deaktiviert (kein Auto-Tracking, NUR manuell).
- Bestehende Adapter-Tests (`inbox_adapters_test.dart`) mit
  Hermes/UPS/Amazon-Patterns entweder löschen oder als `[REMOVED]`-
  Marker mit Skip-Annotation.
- Help-Page-Sektion „Versand" + „Deals → Tracking" textlich anpassen:
  Auto-Detection läuft nur via DHL-API.

**Out-of-Scope:**

- DPD/UPS-Adapter-Aktivierung (separates Backlog-Item).
- Migration bestehender `pending_deal_suggestions.trackings`-Multi-
  Einträge — neue Runs überschreiben, alte bleiben so lange bestehen,
  bis der User sie akzeptiert/verwirft.
- UI-Redesign des Pill-Renderings — Single-Pill ergibt sich automatisch
  aus dem `trackings`-Array mit max 1 Element.
- Re-Parse-Trigger-UX (separate Frage, ob nach diesem Refactor ein
  Force-Reparse anlaufen soll — als Folge-Item gequeued).

## Architektur-Entscheidungen

### D1: TRACKING_PATTERNS auf DHL reduzieren + inferCarrier raus

In `supabase/functions/_shared/inbox_adapters.ts:260-344` werden alle
Patterns entfernt außer:

- `dhl-jjd` (`\bJJD\d{10,18}\b`)
- `dhl-de-suffix` (`\b[A-Z]{2}\d{9}DE\b`)
- `dhl-de-prefix` (`\bDE\d{8,14}\b`)

Entfernt:

- `ups-1z` (1Z+16-char) — UPS-spezifisch, ohne API-Key.
- `amazon-tba` (TBA+9-14 digits) — Amazon Logistics, kein API-Adapter.
- `s10-upu` (2+8+2 alphanum) — Universal Postal Union, zu generisch.
- `context-numeric-10-22` (`\b\d{10,22}\b` mit Anchor) — Falsch-Positiv-
  Quelle (Bestellnr, Kundennr, Rechnungsnr).
- `context-alphanumeric-tracking` — generischer Fallback, raus.

Plan-Critic-Punkt 7: `inferCarrier()` (Zeile 512) wird komplett
entfernt. Mit nur noch DHL-Patterns ist Carrier-Inference toter Code.
Die wenigen Callsites in Zeile 620 + 759 verlieren den Aufruf, der
`carrier`-Wert kommt direkt aus `pattern.carrier ?? 'DHL'`.

Begründung: nur Patterns behalten, die mit hoher Specifität DHL-Tracking-
Nummern sind. Die API entscheidet final, ob's wirklich ein DHL-Versand
ist.

### D2: API-Validation als Wrapper NACH parseInboxMessage (kein Async-Cascade)

Plan-Critic-Fix: `resolveTrackingForAdapter` bleibt **sync + pure**. Ein
neuer Wrapper `enrichWithDhlValidation(parsedMessage, apiKey,
supabaseAdmin)` läuft im parse-runner **nach** `parseInboxMessage` und
modifiziert ausschließlich `parsedMessage.tracking`,
`parsedMessage.trackings`, `parsedMessage.tracking_confidence` und
`parsedMessage.tracking_needs_review`. Vorteile:

- **Eine** Touch-Site statt 18 — Pure-Function-Pattern bleibt erhalten.
- Silent-Breakage-Risk minimiert (kein vergessenes `await` in einer der
  Adapter-Sites).
- `parseInboxMessage` bleibt unit-testbar ohne Mocked-Supabase.

Wrapper-Logik:

1. Pre-Filter Input-Kandidaten (`parsedMessage.trackingCandidates`): nur
   Carrier `DHL` oder ohne Carrier-Hint.
2. Cache-Lookup pro Kandidat auf `tracking_validation_cache` (siehe D4).
3. Cache-Miss → `dhlAdapter.fetchStatus(tracking, apiKey)`. Wenn Result
   non-null + Shipment-Object existiert → `is_valid=true`. Sonst
   `is_valid=false`.
4. Cache-Eintrag schreiben mit TTL-Split (siehe D4).
5. Validation-Output:
   - 1+ valide Kandidaten → `trackings = [primary]` (höchste Confidence
     aus den validen), `tracking = primary`, `tracking_confidence =
     'strong'`.
   - 0 valide Kandidaten + Mail shipped/delivered → `trackings = []`,
     `tracking_confidence = 'none'`, `tracking_needs_review = true`.
   - 0 valide Kandidaten + Mail ordered → `trackings = []`,
     `tracking_needs_review = false`.
6. **Hard-Limit:** max 5 API-Calls pro Mail. Wenn mehr Kandidaten:
   - Top-5 nach Confidence-Order probieren.
   - Bei `candidates.length > 5` → strukturiertes Log `console.warn`
     mit `{ event: 'validation_capped', workspace_id, candidate_count,
     dropped_count }` (Plan-Critic-Punkt 4).
7. **Spike-Arrest (HIGH-Risk-Mitigation, R1 neu):** DHL Free-Tier hat
   **1 Call / 5 Sekunden** (verified via developer.dhl.com). Zwischen
   API-Calls innerhalb eines Runs `await sleep(5100ms)` einbauen. Bei
   `parseInboxMessage` über 20 Mails × 5 Calls = 100 Calls × 5.1s =
   ~8.5 Min — akzeptabel für Cron-Run alle 4h, **nicht** für
   Onboarding-Backfill.
8. **Onboarding-Backfill-Pfad (R1 neu):** wenn parse-runner mehr als
   N=10 Mails in einem Batch hat, läuft die Validation **deferred**:
   `parseInboxMessage` schreibt Suggestion mit `tracking=NULL,
   tracking_needs_review=true`, und ein separater Async-Job
   `tracking-validate-queue` picked die in 5s-Intervallen ab. Out-of-
   Scope für diese PR — siehe `## Future`, hier nur deferred-Flag
   `defer_validation BOOLEAN` an den Wrapper.
9. **Rate-Limit-Resilienz (Plan-Critic + D2.7 alt):** Bei HTTP 429
   oder 5xx von DHL → Kandidat als `unknown` cachen (TTL 1h), nicht
   `is_valid=false` (sonst poisons Cache für gültige Nrn). Wrapper
   gibt `tracking_needs_review=true` zurück.

### D3: Inbox-Parse-Runner zieht API-Key einmalig pro Run

`inbox_parse_runner.ts` lädt den DHL-API-Key **einmal pro Run** via
`get_carrier_api_key`-RPC (Service-Role-Pfad existiert seit Sprint 7).
Cached im Run-Scope, kein Roundtrip pro Mail.

Pfad:

1. Run startet → `apiKey = await supabaseAdmin.rpc('get_carrier_api_key',
   { _workspace_id, _carrier_id: 'dhl' })`.
2. Pro Mail: `parseInboxMessage(...)` (sync, unverändert).
3. Pro Mail: `await enrichWithDhlValidation(parsedMessage, apiKey,
   supabaseAdmin)` (neu, einzige neue async-Site).
4. Wenn `apiKey === null` (kein Key gesetzt für Workspace):
   - Wrapper kurz-schließt: `trackings=[], tracking_confidence='none',
     tracking_needs_review=true` (wenn shipped/delivered).
   - Strukturiertes Log `{ event: 'validation_skipped_no_key',
     workspace_id }` einmal pro Run, nicht pro Mail.
   - Help-Page zeigt klare Action: „DHL-API-Key in Settings hinterlegen,
     damit Auto-Tracking funktioniert."

### D4: DB-Cache für Validation-Ergebnisse (globaler Scope)

Plan-Critic-Fix: Cache-PK = `tracking_norm` (global), nicht workspace-
scoped. Eine Tracking-Nummer ist objektiv valide oder nicht — kein
Cross-Workspace-Reuse-Verlust mehr.

Neue Migration `20260517000000_tracking_validation_cache.sql` legt
Tabelle [NEW] `tracking_validation_cache` an:

```
tracking_norm            TEXT NOT NULL PRIMARY KEY  -- uppercase, no whitespace
is_valid                 BOOLEAN NOT NULL
result_state             TEXT NOT NULL CHECK (result_state IN ('valid','invalid','unknown'))
status_raw               JSONB           -- letztes API-Result, debug
first_seen_workspace_id  UUID REFERENCES public.workspaces(id) ON DELETE SET NULL  -- audit-only
last_checked_at          TIMESTAMPTZ NOT NULL DEFAULT now()
```

- RLS: bewusst kein Policy, nur service_role schreibt/liest (Edge-Fn).
- Index: `(last_checked_at)` für TTL-Cleanup.
- TTL:
  - `result_state='valid'` → 7 Tage.
  - `result_state='invalid'` → 30 Tage (Tracking-Nrn werden nicht
    nachträglich gültig).
  - `result_state='unknown'` → 1 Stunde (DHL-Rate-Limit / 5xx-Fallback).

### D4b: Legacy-Cleanup-Migration

Plan-Critic-Punkt 6: bestehende `pending_deal_suggestions` mit Multi-
Tracking-Arrays bleiben sonst Multi-Pill-Frustquelle. Zweite Migration
`20260517000100_clear_legacy_multi_trackings.sql`:

```sql
UPDATE pending_deal_suggestions
   SET trackings = ARRAY[]::TEXT[],
       tracking = NULL,
       tracking_confidence = 'none',
       tracking_needs_review = true
 WHERE array_length(trackings, 1) > 1
   AND user_accepted_at IS NULL;
```

Nur **pending** Suggestions (kein User-Accept), die mehr als 1 Tracking
haben. Nach Migration triggert der User `Settings → Sendungsnummern neu
prüfen` (siehe D7), die Pipeline re-validiert sauber.

### D5: Bestehende Tests verschlanken

`test/inbox_adapters_test.dart` hat ~60 Cases die UPS/Hermes/Amazon/S10-
Patterns testen. Plan:

- **Entfernen** alle Cases die testen, dass Non-DHL-Pattern detected
  werden (z.B. „UPS 1Z9999... wird als strong erkannt").
- **Behalten** alle DHL-spezifischen Cases.
- **Neu hinzufügen** Cases die testen, dass Non-DHL-Patterns
  NICHT mehr detected werden (Regression-Guard).
- **Neu hinzufügen** Unit-Test für `validateCandidatesAgainstDhl` mit
  Mocked `_doFetch`.

### D6: UI bleibt unverändert

`lib/screens/inbox_screen.dart:1121` iteriert weiter über
`suggestion.trackings`. Da das Array nun max 1 Element hat, sieht der
User automatisch max 1 Pill. Kein UI-Code-Change.

Eine kleine Doku-Update in der Help-Section „Deals → Tracking-Status"
genügt: „Tracking-Nummern werden automatisch gegen die DHL-API
verifiziert" statt „aus Mails erkannt".

### D7: Help-Page erwähnt Re-Parse-Trigger explizit

Plan-Critic-Punkt 8: Wenn der User den API-Key NACH den ersten
Inbox-Importen einträgt, sollen die alten Mails durch die neue
Pipeline laufen. Help-Page (DE+EN) bekommt einen klaren Hinweis:

> „Nach dem ersten DHL-API-Key-Eintrag tippe einmal Settings →
> ‚Sendungsnummern neu prüfen', damit bestehende Mails mit der
> API-Validation neu geparst werden."

Der Re-Parse-Trigger existiert bereits (`triggerReparseTracking`
in `lib/services/supabase_repository.dart:815`). Kein neuer Code,
nur Discoverability.

## Touches

### Neue Files

- `supabase/migrations/20260517000000_tracking_validation_cache.sql`
  [NEW]
- `supabase/migrations/20260517000100_clear_legacy_multi_trackings.sql`
  [NEW]
- `supabase/functions/_shared/tracking_validation.ts` (neue Modul mit
  `enrichWithDhlValidation` + Cache-Logik + sleep-Helper für Spike-Arrest)

### Geänderte Files

- `supabase/functions/_shared/inbox_adapters.ts`:
  - `TRACKING_PATTERNS` reduziert (D1).
  - `inferCarrier()` Funktion entfernen + Callsites in Zeile 620 + 759
    auf `pattern.carrier ?? 'DHL'` umstellen.
  - `resolveTrackingForAdapter` bleibt unverändert (sync + pure).
- `supabase/functions/_shared/inbox_parse_runner.ts`:
  - Pro Run einmal: `apiKey = await supabaseAdmin.rpc('get_carrier_api_key',
    ...)`.
  - Pro Mail nach `parseInboxMessage`: `await enrichWithDhlValidation(
    parsedMessage, apiKey, supabaseAdmin)`.
- `lib/l10n/app_de.arb` + `lib/l10n/app_en.arb`:
  - Update `helpDealsTrackingDesc` (Carrier-Liste schrumpfen).
  - Neu: `helpTrackingApiOnlyTitle` [NEW], `helpTrackingApiOnlyDesc` [NEW].
- `lib/screens/help_screen.dart`:
  - Eintrag „Auto-Tracking läuft nur via DHL-API" in der Deals-Section.
- `test/inbox_adapters_test.dart` (oder die richtige Test-Datei):
  - Non-DHL-Tests entfernen, DHL-Only-Regression-Guards hinzufügen.
- `supabase/functions/tracking-poll/SETUP.md`:
  - Hinweis: Inbox-Detection nutzt jetzt denselben API-Key wie
    tracking-poll.

### Möglicherweise berührt

- `docs/handbook/04-inbox-mail-pipeline.md` — Pipeline-Beschreibung
  aktualisieren.
- `.claude/scripts/verify/` — neuer Smoke-Test für `tracking_validation`-
  Pipeline (nice-to-have).

## Risiken

- **R1: DHL-API Spike-Arrest 1/5s + Tageslimit 250 Calls.** (Quelle:
  developer.dhl.com — Plan-Critic verifiziert.) Der ECHTE Engpass ist
  nicht das Tageslimit, sondern die Spike-Limit. 1000-Mail-Backfill
  mit 5 Kandidaten/Mail = 5000 Calls × 5.1s = ~7 Stunden linear.
  **Mitigations:**
  - Spike-Arrest `await sleep(5100ms)` zwischen Calls (D2.7).
  - Hard-Limit 5 Calls/Mail (D2.6).
  - Cache 7d/30d/1h-Split (D4).
  - Onboarding-Backfill-Pfad → deferred async-Job (D2.8, out-of-scope
    für diese PR — separates Backlog-Item).
- **R2: Validation-Cache vergiftet sich, wenn DHL-API kurz down ist.**
  TTL für `unknown` ist nur 1 Stunde — selbstheilend.
- **R3: Hermes/Amazon-Mails verlieren Auto-Tracking.** Bewusst, vom
  Stakeholder explizit angefordert. UX-Mitigation: Help-Page erklärt
  klar, dass nur DHL automatisch ist.
- **R4: Bestehende Suggestions mit Multi-Trackings bleiben in der DB.**
  **Plan-Critic-Fix:** Legacy-Cleanup-Migration `20260517000100` setzt
  `trackings=[]` für alle pending Multi-Tracking-Suggestions (D4b).
  User triggert dann Re-Parse für saubere Single-Pill-Resultate.
- **R5: Async-Cascade durch `resolveTrackingForAdapter`.**
  **Plan-Critic-Fix:** Validation läuft als Wrapper NACH
  `parseInboxMessage` (D2 neu), nicht innerhalb. `resolveTrackingForAdapter`
  bleibt sync + pure. Eine einzige neue async-Site im parse-runner.
- **R6: `findAllTrackings` ist in 36-jkeen-Regression-Test verankert
  (Plan: PR #79).** Wenn die jkeen-Test-Numbers Non-DHL-Carrier
  enthalten, brechen Tests. **Mitigation:** Test-Subset auf DHL-Only
  filtern, Rest als removed-by-design markieren.

## Tests

### Pflicht-Tests

- **Edge-Fn-Unit-Test** für `validateCandidatesAgainstDhl`:
  - Cache-Hit → kein HTTP-Call.
  - Cache-Miss + DHL-API 200 mit Shipment → valid + Cache-Write.
  - Cache-Miss + DHL-API 404 → invalid + Cache-Write.
  - Cache-Miss + DHL-API 429 → unknown + 1h-TTL.
  - Hard-Limit-5 wird respektiert.
- **Adapter-Test** in `inbox_adapters_test.dart`:
  - UPS-1Z + Amazon-TBA + S10 in Mail-Body → `trackings = []` (alle weg).
  - DHL-JJD in Mail-Body, mit gemocktem API-200 → `trackings = [JJD…]`.
  - DHL-JJD in Mail-Body, mit gemocktem API-404 → `trackings = []`,
    `trackingNeedsReview = true`.

### Manuell

1. PR #82 muss gemerged sein UND der Master-Key im Vault liegen (wurde
   bereits manuell gesetzt).
2. DHL-API-Key in Settings → Versand hinterlegt.
3. Re-Parse-Trigger in Settings → „Sendungsnummern neu prüfen".
4. Eine Mail mit echter DHL-Tracking-Nr → Inbox-Suggestion zeigt
   genau 1 Pill.
5. Eine Mail mit Hermes/Amazon-Tracking-Nr → Inbox-Suggestion zeigt
   keine Pills.

### Browser-Smoke (Pre-Ship-Pflicht, UI-Wirkung indirekt)

- `smoke-inbox` — Inbox-Tab + Suggestions-Card-Layout.
- `smoke-help` — Help-Page mit neuer Sektion.

## Rollout

1. PR-Branch `feature/dhl-api-only-tracking-detection`.
2. Council vor Implementation (multi-Expert-Review wegen Tragweite).
3. Implementation in Layers: D1 + D5 zuerst (Pattern-Reduction +
   Test-Update), dann D2 + D3 + D4 (API-Validation + Cache).
4. `flutter analyze` + `flutter test` + Deno-Edge-Fn-Tests.
5. Browser-Smoke `smoke-inbox`.
6. `supabase db push --project-ref <PROD>` für Cache-Migration
   (manueller User-Step).
7. Re-Parse einmal triggern, dass alte Multi-Tracking-Suggestions
   überschrieben werden.

## Future / Nicht-Ziele

- **DPD/UPS-API-Validation**: wenn die Carrier später API-aktiv sind,
  wird dieselbe Validation-Pipeline für sie verwendet. `TRACKING_PATTERNS`
  bekommt dann die DPD/UPS-Patterns zurück, gegated durch
  `enabledCarrierIds`.
- **Hermes/GLS-API**: keine offizielle API bekannt — bleibt dauerhaft
  out-of-scope ohne Stakeholder-Re-Mandat.
- **Manual-Review-UI für nicht-validierte Kandidaten**: wenn der User
  Mails sehen will, in denen Pattern-Hits waren, die API aber nicht
  bestätigte, brauchen wir eine eigene „Maybe tracking"-Sektion.
  Folge-Backlog-Item.
- **Re-Parse-Auto-Trigger nach API-Key-Eintrag**: nice-to-have, wäre
  ein Listener auf `workspace_carrier_credentials`-INSERT.
