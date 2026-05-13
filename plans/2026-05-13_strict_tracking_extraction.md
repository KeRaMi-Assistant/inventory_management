# Strict Tracking Extraction — entweder garantiert echt oder explizit NULL

> **[Committee-Approved 2026-05-13]**
> Erstellt: 2026-05-13 · Autor: planner-Subagent
> Council-Review: 2026-05-13 (Architekt + Bug-Hunter + External-Scout + Security + UX/Mobile)
> 10 Pflicht-Änderungen integriert, 6 Empfehlungen integriert, jkeen-DB als T2b ergänzt.
> Bug-Hunter-Findings #1 (Plain-Text), #3 (CHECK-Constraint), #6 (Reject-Pattern blockt DHL-20)
> waren kritisch.
>
> Trigger-Quote (Stakeholder): _„plane nun wie trackings richtig aus den mails
> genommen werden und keine random zahlen und mach hier die struktur so, dass es
> entweder am ende richtige trackings zeigt oder keine aber nicht irgendwas"_

---

## 1. Ziel + Problem

### Problem
Die Inbox-Pipeline schreibt heute Tracking-Nummern in `parsed_messages.parsed_payload.tracking`,
`pending_deal_suggestions.tracking` und (via Backfill + Suggestion-Akzeptanz) auf
`deals.tracking`, OHNE dass ein einheitlicher Confidence-Score über die Quelle erhalten bleibt.
Beobachtete falsch-positive Fälle:

1. **Amazon `orderingShipmentId`** wird in
   [`20260512000000_backfill_amazon_logistics_tracking.sql`](../supabase/migrations/20260512000000_backfill_amazon_logistics_tracking.sql)
   und in
   [`inbox_adapters.ts:236`](../supabase/functions/_shared/inbox_adapters.ts) als
   _Tracking-Nummer_ klassifiziert. Das ist die **interne Amazon-Logistics-Shipment-ID**,
   keine vom Carrier abrufbare Sendungsnummer.
2. **`STRONG_TRACKING_PATTERNS`** in `inbox_adapters.ts:100` enthält
   `/\b(\d{20,22})\b/` _ohne_ Anchor-Pflicht und `/\b(DE\d{8,14})\b/` ebenfalls
   anchor-frei → jede 20–22-stellige Zahl im Body wird als DHL-Tracking gewertet.
3. **`CONTEXT_TRACKING_RE`** akzeptiert nach „Tracking" jeden Token aus
   `[A-Z0-9-]{8,30}` — also auch `123-1234567-1234567`-Order-IDs.
4. **Keine Confidence-Stufen.** Code kennt nur `STRONG_TRACKING_PATTERNS` vs.
   `CONTEXT_TRACKING_RE` vs. `findTrackingsInHtml` — alle gleichwertig in `trackings[]`.
5. **Keine Validatoren.** Keine Checksum-Prüfung (UPS 1Z-Mod10, DHL JJD-Mod10, S10, …).

### Ziel
Eine Tracking-Nummer landet **nur dann** in `deals.tracking`, `parsed_messages.parsed_payload.tracking`
oder `pending_deal_suggestions.tracking`, wenn ALLE drei Bedingungen erfüllt sind:

- **(a) Klassifizierte Quelle**: Strukturierte Carrier-URL **ODER** Strong-Pattern
  mit Anchor-Wort im selben Sentence-Window.
- **(b) Strukturvalidierung**: Carrier-spezifische Länge + Charset + (wo möglich)
  Checksum bestanden.
- **(c) Confidence ≥ STRONG**. `MEDIUM`/`WEAK` werden im Hintergrund mitgeführt
  (für Forensik), aber **nicht** in Deal/Suggestion-Pfade durchgereicht — Mapping
  in den Persistenz-Layer ist hart: `strong→'strong'`, alles andere → `'none'`
  (CHECK-Constraint, siehe §4.1).

Wenn (a)+(b)+(c) nicht alle erfüllt: `tracking = NULL`, `tracking_confidence = 'none'`,
`tracking_needs_review = TRUE`. UI zeigt: _„Keine Sendungsnummer erkannt — manuell eingeben"_.

---

## 2. Audit der jetzigen Pipeline (Code-Funde)

### 2.1 Pattern-Inventar
Stand: [`supabase/functions/_shared/inbox_adapters.ts`](../supabase/functions/_shared/inbox_adapters.ts).

| Pattern | Quelle | Carrier | Anchor-Pflicht | Validierung | FP-Risiko |
|---|---|---|---|---|---|
| `1Z[A-Z0-9]{16}` | STRONG L101 | UPS | nein | nur Format | sehr niedrig |
| `TBA\d{9,14}` | STRONG L102 | Amazon Logistics | nein | nur Format | niedrig |
| `JJD\d{10,18}` | STRONG L103 | DHL | nein | nur Format | niedrig |
| `[A-Z]{2}\d{9}DE` | STRONG L104 | DHL | nein | nur Format | niedrig |
| `\d{20,22}` | STRONG L105 | DHL | **nein ⚠️** | keine | **HOCH** |
| `DE\d{8,14}` | STRONG L115 | unbekannt | **nein ⚠️** | keine | **HOCH** |
| `CONTEXT_TRACKING_RE` L134 | Context | Anchor + `[A-Z0-9-]{8,30}` | ja | nur Format | **MITTEL** |
| `track.amazon.*/(TBA?)` | HTML L228 | Amazon Logistics | URL | nur Format | niedrig |
| `[?&]trackingId=` | HTML L229 | Amazon Logistics | URL | nur Format | niedrig |
| `orderingShipmentId=` | HTML L236 | Amazon Logistics | URL | nur Format | **ZWEIFEL** |
| `piececode`, `idc`, `trackingNumber` | HTML L238–256 | DHL/DPD/GLS/Hermes/… | URL | nur Format | niedrig |
| `trk\|tracking_?number\|…` | HTML L260 | **unbekannt** | URL | nur Format | mittel |

### 2.2 Confidence-Stufen heute
Keine explizite Confidence-Klasse. `findAllTrackings()` (L303–345) flacht alle Treffer ein.

### 2.3 Gate-Logik
`gateTracking()` (L382) filtert nur nach Mail-Status. Kein Confidence-Gate.

### 2.4 Dart-Seite
`InboxMessage` speichert `tracking`, `trackings[]`, `carrier` — keine `confidence`.
[`lib/services/inbox_match_service.dart`](../lib/services/inbox_match_service.dart)
Z.67–72: schreibt `parsedTracking` nur wenn `currentTracking == null || isEmpty`
(Forward-Only). **Council-Finding #2**: Diese Logik blockt heute das Überschreiben
auch dann, wenn das alte Tracking ein bekannt-falscher Wert ist (`needs_review=TRUE`).

### 2.5 DB-Schema
`pending_deal_suggestions.tracking TEXT`, `deals.tracking TEXT`, `parsed_messages.parsed_payload`
JSONB. Kein `needs_review`-Feld.

### 2.6 Re-Parse heute
[`supabase/functions/inbox-parse/index.ts`](../supabase/functions/inbox-parse/index.ts)
hat bereits drei Re-Parse-Modi (Z.111–135): `reparse_unclassified`, `reparse_no_tracking`,
`reparse_forensics`. Plus `force_overwrite`-Flag (Z.75) für reparse_no_tracking.
**Council-Finding #6**: KEINE neue Function bauen — neuen Mode `reparse_low_confidence`
in dieselbe Function einhängen.

**Council-Finding #1 (kritisch)**: Re-Parse liest heute den HTML-Body aus
`parsed_payload._raw_html` (Z.265, 386). Seit PRs #48/#51 gibt es aber
plain-text-only-Mails, deren Body in `parsed_payload._raw.text` liegt
(`inbox_parse_runner.ts:112`). Beide Pfade müssen unterstützt sein, sonst
Daten-Regression für DE-Plain-Text-Cases.

### 2.7 Tests
- [`test/services/amazon_adapter_test.dart`](../test/services/amazon_adapter_test.dart)
- [`supabase/functions/_shared/inbox_adapters_test.ts`](../supabase/functions/_shared/inbox_adapters_test.ts)
- Keine dedizierten Negativ-Tests (Order-ID, IBAN, PLZ, Telefon).

---

## 3. Architektur-Änderungen

### Was bleibt
- Adapter-Struktur in `inbox_adapters.ts` (Shop-spezifische `parse()`).
- `findAllTrackings(s, html)` als zentraler Einstieg.
- HTML-href-Scanning.

### Was wird umgebaut

#### 3.1 Pipeline-Order (NEU, Pflicht-Reihenfolge)
1. **Body-Cap**: Mail-Body wird auf `MAX_BODY_LEN = 256 * 1024` getrimmt
   (ReDoS-Mitigation — Council-Empfehlung).
2. **Anchor-Detection**: Sentence-Window-Scan auf DE/EN/FR/IT/ES/PL-Anchor-Wörter
   (`Sendungsnummer`, `Tracking`, `Sendungsverfolgung`, `numéro de suivi`, …).
3. **Whitespace-Normalisierung (NEU — Council-Finding #4)**: Vor jedem
   Pattern-Match: `candidate.replace(/[\s ]+/g, '')`. Sonst killt der
   Strict-Mode legitime UPS-Trackings wie `1Z 999 AA1 0123456784`.
4. **Pattern-Match** auf den normalisierten Token.
5. **Reject-Filter** (Negativ-Liste, läuft NUR gegen den 3–30-Zeichen-Token,
   nicht gegen die volle Mail — Council-Empfehlung ReDoS).
6. **Validator** (Checksum/Length).
7. **Confidence-Assignment** + Mapping in Persistenz-Stufen.

#### 3.2 Neuer Typ `TrackingCandidate`
```ts
interface TrackingCandidate {
  value: string                       // normalisiert, ohne Whitespace
  carrier?: string
  confidence: 'strong' | 'medium' | 'weak'   // intern, Forensik
  source: 'strong-pattern' | 'context-anchor' | 'html-carrier-url'
        | 'html-generic-url' | 'amazon-shipment-id'
  anchorMatched?: string              // max 50 chars, NUR das Anchor-Wort
                                      // (z.B. "Sendungsnummer:"), KEIN Folge-Text
                                      // (Council-Finding #7, PII-Schutz)
  validation: {
    lengthOk: boolean
    checksumOk?: boolean | null       // null = N/A
    rejectedBy?: string               // welche Reject-Regel, falls rejected
  }
}
```

**Persistenz-Mapping (Council-Finding #3, Option b)**: Der Adapter darf
Candidates mit `confidence: 'medium'`/`'weak'` intern führen, aber:
- `parsed_payload.tracking` + `pending_deal_suggestions.tracking` + `deals.tracking`
  bekommen den Value NUR wenn `confidence === 'strong'`.
- `parsed_payload.tracking_confidence`/`pending_deal_suggestions.tracking_confidence`/
  `deals.tracking_confidence` sind hart `'strong' | 'none'` (plus `'manual'` auf
  `deals`). CHECK-Constraints lehnen `'medium'`/`'weak'` ab.
- `parsed_payload.tracking_candidates[]` darf Forensik-Einträge mit beliebiger
  Confidence führen (JSONB, schemafrei).

#### 3.3 Pattern-Tabelle (Pflicht-Refactor)
Pro Carrier ein Block:
```ts
{ pattern, requiresAnchor, validator, defaultConfidence, carrier, source }
```
`STRONG_TRACKING_PATTERNS` ist abgeschafft. **Jedes** Pattern (außer URL-eingebettete,
die strukturell schon Anchor sind) ist `requiresAnchor: true`.

#### 3.4 Validatoren via jkeen-DB (External-Scout, T2b)
Statt selbstgebauter Mod-10/Mod-7-Funktionen vendoren wir
[`jkeen/tracking_number_data`](https://github.com/jkeen/tracking_number_data) (MIT-Lizenz):
- Pfad: `supabase/functions/_shared/tracking_data/` mit JSON-Files + LICENSE + README
  (upstream-SHA dokumentiert für künftige Updates).
- Dünner Deno-Interpreter (~80 LOC) in `tracking_validators.ts`, der
  `regex_group_format` + `validation.checksum` (mod10, mod7, s10,
  sum_product_with_weightings_and_modulo) ausführt.
- Test-Numbers aus den JSON-Files als Fixture-Source.

**Eigenbau bleibt**:
- DE/EN/FR/IT/ES/PL-Anchor-Wörter (jkeen hat keine Sprach-Daten).
- Negativ-Liste (Amazon-Order-ID, IBAN, PLZ, Telefon).
- Amazon-`orderingShipmentId`-Sonderfall.

#### 3.5 Negativ-Liste (Council-Finding ReDoS-mitigated)
Reject-Patterns laufen NUR gegen den bereits-gematchten Token (3–30 chars).
```ts
const REJECT_PATTERNS: RegExp[] = [
  /^\d{3}-\d{7}-\d{7}$/,                  // Amazon-Order-ID
  /^[A-Z]{2}\d{2}\d{4}\d{4}/,             // IBAN-Prefix (DE/AT/CH), nach Normalisierung
  /^\+?\d{2,4}\d{3,}$/,                   // Telefonnummern
  /^0\d{4,5}$/,                            // Vorwahl-Fragmente
  /^\d{5}$/,                               // PLZ
  /^[0-9]{1,7}$/,                          // zu kurze numerische IDs
  /^[0-9]{6}-[0-9]{6}-[0-9]{6}$/,          // generische Auftragsnummer-Form
]
```
**WICHTIG (Council-Finding #6)**: KEIN `^\d{20}$`-Reject — würde echte
DHL-20-stellige Trackings blocken. DHL-20-Validierung läuft via jkeen-Checksum.

Reject-Hits werden in `tracking_candidates[]` mit `validation.rejectedBy: '<regex>'`
geloggt (nicht silent dropped — Forensik).

#### 3.6 `findAllTrackings()` Refactor
Gibt `TrackingCandidate[]` zurück, sortiert nach `(confidence desc, source-rank desc,
length desc)`. Adapter konsumieren nur den ersten Candidate mit `confidence === 'strong'`.

#### 3.7 `gateTracking()` erweitern
- `minConfidence`-Parameter (Default `'strong'`).
- Wenn kein Candidate die Schwelle erreicht: `tracking = undefined`,
  `tracking_confidence = 'none'`, `tracking_needs_review = true`.

#### 3.8 Amazon-Sonderfall
`orderingShipmentId` → `confidence: 'medium'`, `source: 'amazon-shipment-id'`.
Erscheint nicht im Default-Output, aber bleibt in `tracking_candidates[]`. UI
zeigt Hinweis-State „Amazon-interne Shipment-ID — kein vollwertiges Carrier-Tracking".

#### 3.9 Dart-Seite
- `InboxMessage` + `Deal` bekommen `trackingConfidence` + `trackingNeedsReview`.
- **`inbox_match_service.dart` Forward-Only aufbrechen (Council-Finding #2)**:
  Neue Signatur erhält `currentTrackingNeedsReview: bool`. Schreib-Bedingung:
  ```dart
  if (parsedTracking != null && parsedTracking.isNotEmpty &&
      parsedConfidence == 'strong' &&
      (currentTracking == null || currentTracking.isEmpty ||
       currentTrackingNeedsReview == true)) {
    updates['tracking'] = parsedTracking;
    updates['tracking_confidence'] = 'strong';
    updates['tracking_needs_review'] = false;
  }
  ```
  Schreiben bleibt blockiert für `tracking_confidence = 'manual'`.

---

## 4. Datenmodell + RLS-Änderungen

### 4.1 Neue Spalten

**`parsed_messages.parsed_payload`** (JSONB) bekommt:
- `tracking_confidence: 'strong' | 'none'`
- `tracking_candidates: TrackingCandidate[]` (Forensik, max 10 Einträge,
  `anchorMatched` max 50 chars — Council-Finding #7)
- `tracking_needs_review: boolean`

**`pending_deal_suggestions`** (Council-Finding #3, Option b — strikt `strong|none`):
```sql
ALTER TABLE public.pending_deal_suggestions
  ADD COLUMN tracking_confidence TEXT NOT NULL DEFAULT 'none'
    CHECK (tracking_confidence IN ('strong','none')),
  ADD COLUMN tracking_needs_review BOOLEAN NOT NULL DEFAULT FALSE;
```

**`deals`** (zusätzlich `manual`):
```sql
ALTER TABLE public.deals
  ADD COLUMN tracking_confidence TEXT NOT NULL DEFAULT 'none'
    CHECK (tracking_confidence IN ('strong','manual','none')),
  ADD COLUMN tracking_needs_review BOOLEAN NOT NULL DEFAULT FALSE;
```

**`mailbox_accounts`** (Council-Empfehlung Rate-Limit):
```sql
ALTER TABLE public.mailbox_accounts
  ADD COLUMN last_reparse_at TIMESTAMPTZ;
```
Rate-Limit für Re-Parse-Button: 1× pro Workspace / 5min.

### 4.2 RLS
Keine neuen Tabellen → keine neuen Policies. Spalten erben bestehende Workspace-Policies.

### 4.3 Indizes
```sql
CREATE INDEX deals_needs_tracking_review_idx
  ON public.deals(workspace_id)
  WHERE tracking_needs_review = TRUE AND deleted_at IS NULL;
```

---

## 5. Migration-Strategie (existierende Daten)

### 5.1 Schritt 1: Schema-Add
Neue Spalten anlegen, Default `none`/`false` → kein Datenverlust.

### 5.2 Schritt 2: Re-Klassifizierung (mit Manual-Guard, Council-Empfehlung)
```sql
UPDATE public.deals
SET tracking_needs_review = TRUE,
    tracking_confidence  = 'none'
WHERE tracking IS NOT NULL
  AND tracking_confidence <> 'manual';   -- idempotenter Re-Run-Guard

UPDATE public.pending_deal_suggestions
SET tracking_needs_review = TRUE,
    tracking_confidence  = 'none'
WHERE tracking IS NOT NULL
  AND resolved_at IS NULL;
```
`deals.tracking` wird **nicht genullt** — nur als „review needed" markiert.

### 5.3 Schritt 3: Re-Parse via bestehender `inbox-parse`-Function
**Council-Finding #6**: KEINE neue Function. Bestehende `inbox-parse/index.ts`
bekommt einen vierten Mode `reparse_low_confidence` neben den drei vorhandenen
(`reparse_unclassified`, `reparse_no_tracking`, `reparse_forensics`).

**Council-Finding #1 (kritisch)**: Der neue Mode (und der Fix für die bestehenden)
muss BEIDE Body-Quellen lesen:
```ts
const html = row.parsed_payload?._raw_html ?? ''
const text = row.parsed_payload?._raw?.text ?? ''
const candidates = findAllTrackings(text, html)
```
Sonst regression auf Plain-Text-only-Mails aus PRs #48/#51.

**Council-Finding #9 — Endpoint-Contract**:
- `workspace_id` wird AUSSCHLIESSLICH aus `auth.uid()` → `mailbox_accounts`-Lookup
  abgeleitet. Bestehender 403-Check (`inbox-parse/index.ts:106`) bleibt aktiv.
- Body-`workspace_id` darf nur INNERHALB des User-Scopes filtern, niemals erweitern.
- Service-Role-Bearer-Pfad NUR für Cron/Maintenance (Schedule oder manueller Admin-Run).
- KEINE `message_id` im Body — Scope ist immer Workspace, nicht Einzel-Message.
- Rate-Limit: `mailbox_accounts.last_reparse_at < NOW() - INTERVAL '5 min'` (per
  Workspace-Owner-Account). Sonst 429.

Idempotent. Batched (200/Aufruf, max 5min CPU).

### 5.4 Schritt 4: Amazon-Backfill-Reversion
```sql
UPDATE public.parsed_messages
SET parsed_payload =
      jsonb_set(parsed_payload, '{tracking}', 'null'::jsonb)
      || jsonb_build_object('tracking_confidence', 'none',
                             'tracking_needs_review', true)
WHERE shop_key ILIKE 'amazon%'
  AND parsed_payload->>'carrier' = 'Amazon Logistics'
  AND parsed_payload->>'tracking' ~ '^[0-9]{8,20}$';
```

---

## 6. UI + l10n-Keys

### 6.1 Screens betroffen
- `lib/screens/inbox_screen.dart` — Detail-Sheet.
- `lib/screens/deal_detail_screen.dart` — Tracking-Block.
- `lib/screens/add_edit_deal_screen.dart` — manuelle Eingabe.
- **NEU (Council-Finding #10, Bottom-Nav-Entscheidung)**: KEIN neuer Top-Level-Screen.
  Stattdessen Filter `needs_review=TRUE` auf bestehender Deals-Liste +
  Banner-CTA aus Inbox/Deals + Counter-Badge auf Inbox-Tab.
- `lib/screens/settings_screen.dart` — Re-Parse-Button.

### 6.2 Widgets
- Neu: `lib/widgets/tracking_status_block.dart` — render 3 States:
  1. **Strong / manual**: Tracking-Nr + Carrier-Badge + „Verfolgen".
  2. **None + needs-review**: Banner + „Manuell eingeben" + „Ignorieren".
  3. **None + no-review**: dezenter Placeholder.
- Erweitert: `lib/widgets/inbox_suggestion_card.dart` — gelber Indikator bei `needs_review`.
- Erweitert: Bestehende Deals-Liste bekommt Filter-Chip „Prüfen ({count})" für
  `tracking_needs_review = TRUE`.

### 6.3 l10n-Keys (DE + EN, Council-Finding #8: 18 Keys statt 10)

| Key | DE | EN |
|---|---|---|
| `trackingNoneDetectedTitle` | Keine Sendungsnummer erkannt | No tracking number detected |
| `trackingNoneDetectedSubtitle` | Wir konnten in dieser Mail keine eindeutige Sendungsnummer finden. | We could not find a verified tracking number in this message. |
| `trackingEnterManuallyCta` | Manuell eingeben | Enter manually |
| `trackingReviewNeededBadge` | Prüfen | Review |
| `trackingReviewAcceptCta` | Übernehmen | Accept |
| `trackingReviewDismissCta` | Verwerfen | Dismiss |
| `trackingAmazonShipmentIdHint` | Amazon-interne Shipment-ID — kein vollwertiges Carrier-Tracking | Amazon-internal shipment ID — not a real carrier tracking number |
| `trackingCarrierUnknown` | Unbekannter Versender | Unknown carrier |
| `trackingCarrierAmazonLogisticsHintShort` | Amazon Logistics | Amazon Logistics |
| `trackingReparseRunning` | Sendungsnummern werden neu bewertet… | Re-evaluating tracking numbers… |
| `trackingReparseFailed` | Neubewertung fehlgeschlagen | Re-evaluation failed |
| `trackingReparseSuccessCount` (ICU plural) | `{count, plural, =0{Keine Sendungsnummer aktualisiert} =1{1 Sendungsnummer aktualisiert} other{{count} Sendungsnummern aktualisiert}}` | `{count, plural, =0{No tracking number updated} =1{1 tracking number updated} other{{count} tracking numbers updated}}` |
| `trackingReparseCta` | Sendungsnummern neu bewerten | Re-evaluate tracking numbers |
| `trackingReparseConfirmTitle` | Neubewertung starten? | Start re-evaluation? |
| `trackingReparseConfirmBody` | Bestehende Sendungsnummern werden mit der verbesserten Erkennung neu geprüft. Manuelle Einträge bleiben unverändert. | Existing tracking numbers will be re-checked with the improved detector. Manual entries stay untouched. |
| `trackingReparseOffline` | Keine Verbindung — bitte später erneut versuchen | No connection — please try again later |
| `trackingBannerImprovedDetection` | Wir haben die Tracking-Erkennung verbessert. Bitte einmal in „Prüfen" schauen. | We improved tracking detection. Please review the items in "Review". |
| `trackingConfidenceLabelStrong` | Verifiziert | Verified |
| `trackingConfidenceLabelManual` | Manuell | Manual |
| `trackingConfidenceLabelNone` | Unklar | Unclear |
| `trackingStatusBlockA11yLabel` | Sendungsnummern-Status | Tracking status |

(Tabelle nennt jetzt 21 Keys; T8 plant „18+" um Sub-Varianten Spielraum zu geben.)

---

## 7. Tests

### 7.1 Fixtures (Deno-Tests in `inbox_adapters_test.ts`)
Negativ-Cases (Pflicht `tracking === undefined`):
- `neg_order_id_only`, `neg_random_20digit`, `neg_iban_fragment`, `neg_plz_in_address`,
  `neg_phone_number`, `neg_tracking_word_but_orderid`, `neg_amazon_shipmentid_only`.

Positiv-Cases (Pflicht `tracking_confidence === 'strong'`):
- `pos_ups_1z_with_checksum`, `pos_ups_1z_with_spaces` (Whitespace-Normalisierung),
  `pos_dhl_jjd_anchor`, `pos_amazon_tba_html`, `pos_de_dhl_anchor`,
  `pos_dhl_20_digit_with_anchor_and_valid_checksum` (Council-Finding #6),
  `pos_multi_packages`.

Edge:
- `edge_strong_and_weak` — STRONG durchgereicht, WEAK in `tracking_candidates[]`.
- `edge_anchormatched_max_50chars` — Assertion: kein `tracking_candidates[*].*` > 50 chars
  (Council-Finding #7 PII-Schutz).

jkeen-Test-Numbers: alle Test-Numbers aus den vendoren JSON-Files laufen als Fixture.

### 7.2 Dart-Unit-Tests
- `inbox_match_service_test.dart`: forward-only blockt bei `confidence === 'none'`,
  ABER überschreibt bei `currentTrackingNeedsReview == true`.
- `tracking_status_block_test.dart`: 3 Render-Pfade.

### 7.3 Coverage-Ziel
- `inbox_adapters.ts` Tracking-Pfad: ≥ 85%.
- `tracking_validators.ts`: 100%.
- `tracking_status_block.dart`: ≥ 70%.

### 7.4 Browser-Smoke
`/test-ui smoke-inbox` ergänzen um „Klick auf Inbox-Item ohne Tracking → sieht
'Keine Sendungsnummer erkannt'-Block + 'Manuell eingeben'".

---

## 8. Risiken

1. **User-Wahrnehmung: „App hat mein Tracking verloren!"** Mitigation:
   `trackingBannerImprovedDetection`-Banner in Inbox/Deals (Council-Finding #8).
2. **Pattern zu eng → echte Trackings geblockt.** Mitigation: T1-Forensik-Baseline
   gegen Sample-Workspace VOR T2/T3-Rollout (Council-Finding #5).
3. **Checksum-Validatoren falsch.** Mitigation: jkeen-DB statt Eigenbau (T2b);
   Test-Numbers aus jkeen als Falsifikator.
4. **Amazon-Reversion löscht legitime Werte.** Sehr unwahrscheinlich (Filter ist
   pure-numerisch + Carrier='Amazon Logistics').
5. **Re-Parse überschreibt manuelle User-Trackings.** Mitigation:
   `tracking_confidence = 'manual'` blockt Schreiben (Migration-Guard +
   Service-Layer-Check).
6. **Negativ-Liste zu aggressiv.** Mitigation: Reject-Hits werden geloggt
   (`tracking_candidates[].validation.rejectedBy`), nicht silent dropped.
7. **`tracking_needs_review` kollidiert mit Forward-Only.** Mitigation: explizite
   Logik in `inbox_match_service.dart` (Council-Finding #2).
8. **ReDoS bei großen Mail-Bodies.** Mitigation: `MAX_BODY_LEN = 256 KB`-Cap +
   Reject-Patterns laufen nur gegen den 3–30-char-Token (Council-Empfehlung).
9. **Plain-Text-only-Mails regression.** Mitigation: Re-Parse liest BEIDE Quellen
   (`_raw_html` + `_raw.text`) — Council-Finding #1.
10. **Rate-Limit-Bypass.** Mitigation: `mailbox_accounts.last_reparse_at` +
    5min-Cooldown serverseitig (nicht clientseitig).

---

## 9. Out-of-Scope

- **Live-Cross-Check via Carrier-API**. `tracking-poll` macht das später.
- **Confidence-Schwellen-Switch im Setting.** Default ist `strong`.
- **OCR von Tracking-Barcodes aus Attachments**.
- **Sprach-Erweiterung über DE/EN/FR/IT/ES/PL hinaus.**
- **Migration auf `deals.tracking`-JSONB-Spalte** (Schema-Stabilität wichtiger).
- **Eigenständiger `tracking_review_screen.dart` als Top-Level-Route**
  (Council-Finding #10: Filter + Banner-CTA reichen).

---

## 10. Tasks

> Format: `[Tx] <Titel>` · `agent:` · `depends:` · `est:`
> Atomic = jeder Task einzeln mergebar. 1 Story-Point = 2h.

- **[x]** Forensik-Baseline: Sample-Workspace dump 100 Tracking-Werte
  (anonymisiert) + Klassifikation gegen neue Confidence-Tabelle. **Pflicht-Predecessor
  für T2/T3 (Council-Finding #5).** Validatoren werden gegen echte Sample-Trackings
  falsifiziert.
  Output: `docs/inbox-forensics/tracking-confidence-baseline-2026-05.md`.
  `agent: flutter-coder` · `depends: []` · `est: 2h` (1 SP)

- **[T2a]** Vendor jkeen-DB: `supabase/functions/_shared/tracking_data/` mit JSON-Files,
  LICENSE, README (upstream-SHA). Statisches Snapshot, kein npm/git-Submodule.
  `agent: edge-fn-coder` · `depends: [T1]` · `est: 1h` (0.5 SP)

- **[T2b]** jkeen-Interpreter in `tracking_validators.ts`: ~80 LOC Deno-Code, der
  `regex_group_format` + `validation.checksum` (mod10, mod7, s10,
  sum_product_with_weightings_and_modulo) ausführt. Deno-Unit-Tests gegen alle
  Test-Numbers aus den JSON-Files.
  `agent: edge-fn-coder` · `depends: [T2a]` · `est: 2h` (1 SP)

- **[T3a]** Negativ-Liste (`REJECT_PATTERNS`) + Reject-Logging in
  `tracking_candidates[].validation.rejectedBy`. ReDoS-safe: Pattern laufen nur
  gegen 3–30-char-Token.
  `agent: edge-fn-coder` · `depends: [T1]` · `est: 1.5h` (0.75 SP)

- **[T3b]** `TrackingCandidate`-Typ + Pattern-Tabelle (`{ pattern, requiresAnchor,
  validator, defaultConfidence, carrier, source }`). `findAllTrackings()` gibt
  sortierte Candidates.
  `agent: edge-fn-coder` · `depends: [T1, T2b]` · `est: 2h` (1 SP)

- **[T3c]** Anchor-Pflicht-Refactor: `STRONG_TRACKING_PATTERNS` abgeschafft.
  Whitespace-Normalisierung vor Pattern-Match. `gateTracking()` mit
  `minConfidence`-Param. Body-Cap `MAX_BODY_LEN = 256 KB`.
  `agent: edge-fn-coder` · `depends: [T3b]` · `est: 2h` (1 SP)

- **[T4]** Amazon-Sonderfall: `orderingShipmentId` → `confidence: 'medium'`,
  `source: 'amazon-shipment-id'`. Tests in `inbox_forensics_test.ts` anpassen.
  `agent: edge-fn-coder` · `depends: [T3c]` · `est: 1h` (0.5 SP)

- **[T5]** DB-Migration: neue Spalten auf `pending_deal_suggestions` + `deals`
  (`tracking_confidence` mit korrekten CHECK-Constraints, `tracking_needs_review`),
  `mailbox_accounts.last_reparse_at`, Index `deals_needs_tracking_review_idx`,
  Re-Klassifikation mit `<> 'manual'`-Guard.
  `agent: db-migrator` · `depends: [T3c]` · `est: 1.5h` (0.75 SP)

- **[T6]** Backfill-Reversion: Amazon-`orderingShipmentId`-Werte in
  `parsed_messages` nullen (pure-numerisch + Amazon Logistics).
  `agent: db-migrator` · `depends: [T5]` · `est: 1h` (0.5 SP)

- **[x]** Dart: `InboxMessage` + `Deal` Modelle + Repository um
  `trackingConfidence`/`trackingNeedsReview` erweitern. `inbox_match_service.dart`
  Forward-Only aufbrechen — überschreibt bei `currentTrackingNeedsReview == true`
  ODER `currentTracking` leer (Council-Finding #2). Schreiben bleibt blockiert
  für `confidence == 'manual'`.
  `agent: flutter-coder` · `depends: [T5]` · `est: 2.5h` (1.25 SP)

- **[T8]** l10n: 21 neue ARB-Keys DE + EN in `app_de.arb` + `app_en.arb`
  (ICU-Plural für `trackingReparseSuccessCount`). `flutter gen-l10n`.
  `agent: ui-builder` · `depends: []` · `est: 1h` (0.5 SP)

- **[T9]** UI-Widget `lib/widgets/tracking_status_block.dart` mit 3 States.
  Widget-Tests.
  `agent: ui-builder` · `depends: [T7, T8]` · `est: 2h` (1 SP)

- **[T10]** Inbox-Detail + Deal-Detail binden `TrackingStatusBlock` ein.
  `inbox_suggestion_card.dart` zeigt gelben Indikator bei `needs_review`.
  Browser-Smoke `smoke-inbox` grün.
  `agent: ui-builder` · `depends: [T9]` · `est: 1.5h` (0.75 SP)

- **[T11]** Banner-CTA + Sub-Route + Counter-Badge (Council-Finding #10, KEIN
  Top-Level-Screen): Filter-Chip „Prüfen ({count})" auf bestehender Deals-Liste
  für `tracking_needs_review = TRUE`. `trackingBannerImprovedDetection`-Banner
  in Inbox + Deals. Counter-Badge auf Inbox-Bottom-Nav-Tab.
  Page-Registry: Eintrag als **Sub-Route**, nicht Top-Level.
  `agent: ui-builder` · `depends: [T9]` · `est: 2h` (1 SP)

- **[T12]** Re-Parse-Mode in bestehender `inbox-parse`-Function (Council-Finding #6:
  KEINE neue Function). Neuer Body-Flag `reparse_low_confidence: true`. Liest BEIDE
  Body-Quellen `_raw_html` + `_raw.text` (Council-Finding #1) — auch in den
  bestehenden Modi `reparse_no_tracking` als Bugfix. Endpoint-Contract:
  `workspace_id` nur aus `auth.uid()`-Scope, kein `message_id` im Body, Rate-Limit
  via `mailbox_accounts.last_reparse_at` (5min Cooldown → 429). Setting-Button in
  `settings_screen.dart` mit Confirm-Dialog + Offline-State.
  `agent: edge-fn-coder` · `depends: [T3c, T5]` · `est: 3h` (1.5 SP)

- **[x]** Fixtures + Negativ-Tests in `inbox_adapters_test.ts` (7 Negativ +
  7 Positiv inkl. `pos_ups_1z_with_spaces` + `pos_dhl_20_digit_with_anchor` +
  2 Edge inkl. `edge_anchormatched_max_50chars`).
  `agent: flutter-coder` · `depends: [T3c, T4]` · `est: 3h` (1.5 SP)

- **[T14]** Page-Registry + Handbuch + Help-Page (`/update-docs --apply` +
  `/update-help --apply`). Page-Registry: Sub-Route, nicht Top-Level.
  `agent: ui-builder` · `depends: [T11]` · `est: 30min` (0.25 SP)

- **[T15]** `smoke-full-app-audit` als Pre-Ship-Gate. Bei roten Findings
  Auto-Followup-Items im Inbox.
  `agent: ui-builder` · `depends: [T10, T11]` · `est: 1h` (0.5 SP)

- **[T16]** `tracking-poll`-Skip-Logik (Council-Empfehlung): Skippen wenn
  `tracking_needs_review = TRUE` UND `tracking_confidence = 'none'`. Verhindert
  unnötige API-Calls gegen Null-Trackings.
  `agent: edge-fn-coder` · `depends: [T5]` · `est: 30min` (0.25 SP)

**Kritischer Pfad:** T1 → T2a → T2b → T3a/b/c → T5 → T7 → T9 → T10 → T15.

**Geschätzter Gesamt-Aufwand:** 14.5 Story Points (~29h) auf 17 Tasks verteilt.

---

## 11. Offene Fragen — geklärt durch Council

1. **`inbox_service.reparseAll()` heute?** Nein, Re-Parse läuft in Edge Function
   (bestätigt durch `inbox-parse/index.ts`). T12 erweitert sie, baut keine neue.
2. **`deals.tracking` Spaltenname?** `tracking` (bestätigt).
3. **`tracking_confidence = 'manual'` als Enum-Wert?** Ja, einzelner Enum-Wert auf
   derselben Spalte (Single-Source-of-Truth).
4. **`tracking-poll` Verhalten bei `needs_review = TRUE`?** Skippen — als T16
   eingebaut.
5. **UI-Position „Trackings prüfen"?** Sub-Route mit Filter-Chip auf Deals-Liste
   + Banner-CTA + Counter-Badge auf Inbox-Tab. KEIN 11ter Bottom-Tab
   (Council-Finding #10, final).
