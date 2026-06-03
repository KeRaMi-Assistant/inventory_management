# Tracking-Rebuild — Algorithmische Detection (DHL/Amazon/DPD) + VAT-Filter + 13-Uhr-Poll

**Datum:** 2026-06-03
**Author (Draft):** Opus (Workflow-Synthese aus 9 Research/Design/Critique-Agenten)
**Status:** `[Committee-Approved 2026-06-03]` — 5-Reviewer-Council durchlaufen
(Architekt ⚠️, Bug-Hunter KRITISCH, External-Scout EIGENBAU, Security warn,
UX ⚠️). Alle 🔴-Pflicht-Findings sind eingearbeitet (markiert mit
`[Council-Fix]`). Phase 0.5 validate-plan: exit 1 / 10 Mismatches — alle
spurious (SQL-Funktions-/Schema-/Extension-Namen als Tabellen fehlgelesen),
per Moderator overruled. Phase 1.5 übersprungen (Security-Marker → volles
Phase 2 Pflicht).
**Original-User-Wunsch (DE, verbatim):**
> „plane nochmal das tracking, nach altem stil wo mit einem algorithmus die
> trackings ermittelt werden. Filtere dabei die Umsatzsteuernummer raus, dhl
> tracking und umsatzsteuernummer sehen ähnlich aus aber problematisch für den
> algorithmus, eine umsatzsteuernummer hat immer 2 buchstaben und neun ziffern,
> bei bestehenden eingepflegten tickets soll das tracking gegen die api geprüft
> werden und gucken ob es ein update gab beim tracking, geschieht jeden tag 13
> Uhr und immer einmal wenn das produkt das tracking bekommen hat. Das Mail
> tracking soll absolut funktionieren und nichts falsches machen"

**Geklärte Stakeholder-Entscheidungen (2026-06-03):**
1. **Von Grund auf neu bauen** — „der alte Ansatz ging nie". Kein bloßes
   Reaktivieren der alten Pipeline.
2. **Carrier-Scope: nur DHL, Amazon (Logistics), DPD.**
3. **Tracking wird IMMER gespeichert**, auch ohne konfigurierten Carrier-API-Key
   (Detection ist rein algorithmisch; Live-Status wird später nachgezogen).
4. **Täglicher Poll exakt 13:00 Europe/Berlin** (DST-sicher).

**Leitprinzip (User-Direktive):** „nichts falsches machen". Ein Falsch-Positiv
(USt-IdNr./IBAN/Telefon wird zum Tracking) korrumpiert einen echten Deal →
**Falsch-Positive-Budget = 0 (harter Merge-Blocker).** Ein Falsch-Negativ
(verpasste Sendungsnummer) ist erholbar (Re-Parse / manuelle Eingabe).

---

## 0. Warum der aktuelle Ansatz scheitert (Problemanalyse)

Belegt durch Code-Lesung (alle Pfade verifiziert):

1. **Detection ist an einen Live-DHL-API-Probe gekoppelt.**
   [`inbox_parse_runner.ts`](../supabase/functions/_shared/inbox_parse_runner.ts) →
   `applyDhlValidation` → [`tracking_validation.ts:165-171`](../supabase/functions/_shared/tracking_validation.ts)
   `enrichWithDhlValidation`. **Ohne DHL-API-Key wird JEDES Tracking gelöscht**
   (Short-Circuit). Das ist die Hauptursache, warum „nichts ankommt".
2. **VAT-Kollision real & bestätigt.** Das Pattern `dhl-de-prefix`
   `\bDE\d{8,14}\b` ([`inbox_adapters.ts:294`](../supabase/functions/_shared/inbox_adapters.ts))
   matcht eine deutsche USt-IdNr `DE123456789` (DE + 9 Ziffern, 9 ∈ [8,14]).
   Das ist exakt der vom User beschriebene Bug.
3. **DHL-only Pattern-Tabelle.** UPS/Amazon/S10/DPD wurden in #84 entfernt;
   übrig sind nur DHL-Pattern, die final ein API-Call gated. Multi-Carrier-
   Detection existiert nicht mehr im Produktiv-Pfad.

**Es existiert bereits brauchbare Substanz, die wiederverwendet wird:**
- [`tracking_validators.ts`](../supabase/functions/_shared/tracking_validators.ts)
  `_internal.{checkS10, checkMod10, checkMod37_36}` — **numerisch verifizierte**
  Checksum-Primitiven (Beweise siehe §11 Research-Anhang). Wir rufen die
  Primitiven direkt auf (nicht den JSON-getriebenen `validateTrackingNumber`).
- `ANCHOR_WORDS`, `findAnchorBefore`, `stripHtml`, `MAX_BODY_LEN`,
  `TrackingCandidate` aus `inbox_adapters.ts` — bleiben, werden re-exportiert.
- [`tracking_adapters.ts`](../supabase/functions/_shared/tracking_adapters.ts)
  `dhlAdapter` (Parcel-DE XML) + `dpdAdapter` für das **Status-Polling**.

---

## 1. Ziel + Scope

**Ziel:** Zwei sauber getrennte Belange, die heute fälschlich verflochten sind:

| Belang | Mechanismus | API nötig? |
|---|---|---|
| **A. Detection (Mail → Tracking)** | Reiner, synchroner Algorithmus (Pattern + Checksum + Anchor + Reject) | **Nein** — speichert immer |
| **B. Status-Polling (bestehende Deals → Carrier-API)** | `tracking-poll` Edge-Function, getriggert (1) täglich 13:00 Berlin, (2) sofort bei Tracking-Zuweisung | **Ja** — aber nur für Live-Status, nie für Detection |

**In Scope:** DHL (JJD/JVGL, 20-stellig Sendungsnummer, 12-stellig Identcode,
S10 international), Amazon Logistics (TBA, detection-only), DPD (14-stellig,
nur via URL/Anchor).

**Out of Scope (explizit dokumentiert, nicht still verschluckt):**
- **DHL Express 10–11-stellig (mod7).** mod7 hat 1/7 ≈ 14 % Falsch-Akzeptanz →
  zu unsicher für den „nichts falsches"-Anspruch. Manuelle Eingabe.
- **UPS, GLS, Hermes, FedEx, USPS** etc. — kein Detection-Promote, kein Poll.
- **Amazon Live-Status-Polling** — Amazon Logistics hat **keine öffentliche
  Status-API** (Research R2, bestätigt). Amazon-Trackings werden erkannt &
  gespeichert, aber nie gepollt.

---

## 2. Teil A — Detection-Algorithmus (neues Modul)

**Neue Datei:** `supabase/functions/_shared/tracking_detection.ts`
Self-contained `detect(input): DetectionResult`. Importiert Checksum-Primitiven
aus `tracking_validators.ts` + Anchor-Helper aus `inbox_adapters.ts`.

### 2.1 Scan-Haystack (Critique-Fix C1-#2/#7 eingearbeitet)

- **Numerische & S10-Pattern scannen NUR den sichtbaren Body-Text**
  (`subject + "\n" + text + "\n" + stripHtml(html)`, gecappt auf `MAX_BODY_LEN`).
  **NICHT** Query-Strings / href-Attribute — dort leben Google-Analytics-
  Client-IDs, Tracking-Pixel-IDs etc., die sonst die `\d{20}`-/`\d{12}`-Pattern
  füttern (verifiziert: eine GA-cid `12345678901234567890` passiert die
  20-stellige mod-10-Checksum).
- **HTML-hrefs werden SEPARAT** mit Carrier-Domain-gescopten Patterns gescannt
  (track.amazon, dhl, dpd) — siehe §2.4.
- **KEIN globaler Whitespace-Strip + Re-Scan** für numerische/S10-Pattern
  (Critique C1-#7): das konkateniert unverwandte Tokens über Zeilen/Tabellen-
  zellen und fabriziert Geister-Nummern (z. B. `DE123456789` + benachbartes
  `DE` → falsches S10 `DE123456789DE`). Whitespace wird nur **innerhalb eines
  bereits gematchten, alpha-präfigierten Tokens** (JJD/TBA) normalisiert
  (Index-Map-Ansatz wie heute), nie body-weit.

### 2.2 Reject-/VAT-Filter — läuft ZUERST, auf dem normalisierten Token

Jeder Kandidat wird normalisiert (`raw.replace(/\s+/g,'').toUpperCase()`) und
gegen die Reject-Liste geprüft, **bevor** Carrier-Klassifikation/Checksum läuft.
Alle Pattern sind `^…$`-anchored auf dem isolierten 3–30-Zeichen-Token →
O(Token-Länge), ReDoS-sicher (nie gegen den Body).

```ts
export const REJECT_PATTERNS: Array<{ name: string; re: RegExp }> = [
  // ── DER KERN: EU-VAT (DE/EL/EE/…) — exakt 2 Buchstaben + exakt 9 Ziffern.
  //    Ein echtes S10 hat 2 NACHGESTELLTE Länder-Buchstaben (13 Zeichen) →
  //    matcht NICHT. Research R4 beweist: kein gültiges DHL/Amazon/DPD-Format
  //    hat die Form ^[A-Z]{2}\d{9}$ → Reject ist 100 % zerstörungsfrei.
  { name: 'vat_eu',            re: /^[A-Z]{2}\d{9}$/ },
  // IBAN (DE = DE + 20 Ziffern; generisch = 2 Buchst + 2 Prüf + 11-30 alnum).
  { name: 'iban_de',           re: /^DE\d{20}$/ },
  { name: 'iban_any',          re: /^[A-Z]{2}\d{2}[A-Z0-9]{11,30}$/ },
  // Amazon-Order-ID 3-7-7 (kein Tracking).
  { name: 'amazon_order_id',   re: /^\d{3}-\d{7}-\d{7}$/ },
  // Telefon — NUR mit literalem '+' (Critique C1-#1 BLOCKER: die lose
  //   R4-Variante ^\+?\d…$ matcht JEDE rein-numerische Sendungsnummer und
  //   würde — weil Reject vor Klassifikation droppt — 100 % der numerischen
  //   Trackings auslöschen. NIEMALS digit-count-basiert rejecten.).
  { name: 'phone_intl',        re: /^\+\d{2,4}\d{3,}$/ },
  { name: 'plz_phone_combo',   re: /^\d{5}\s\d{6,12}$/ },
  { name: 'plz_only',          re: /^\d{5}$/ },
  // Zu kurz: echte in-scope Numerik ist ≥12 Ziffern.
  { name: 'too_short_numeric', re: /^\d{1,7}$/ },
  { name: 'generic_order_3block', re: /^\d{6}-\d{6}-\d{6}$/ },
]
```
> `vat_de` (`^DE\d{9}$`) ist eine Teilmenge von `vat_eu` und wird **weggelassen**
> (Critique C1-#9; höchstens als Log-Label behalten). Der eigentliche VAT-Schutz
> liegt NICHT primär hier (die Strong-Pattern extrahieren `DE123456789` ohnehin
> nie als Kandidaten, da `dhl-de-prefix` gelöscht wird) — sondern darin, dass
> (a) `dhl-de-prefix` ersatzlos verschwindet und (b) S10 die Länder-Code-/
> Service-Prefix-Validierung erzwingt (§2.5). `vat_eu` bleibt als Defense-in-Depth.

### 2.3 Strong-Pattern (alpha-präfigiert / format-eindeutig)

```ts
type CarrierId = 'dhl' | 'amazon' | 'dpd'
const STRONG_PATTERNS = [
  // DHL JJD/JVGL/J[A-Z]{2} — 3-4 Buchstaben Prefix, kann nie VAT sein.
  { id:'dhl-jjd',   re:/\bJ[A-Z]{2,3}\d{10,21}\b/g, carrier:'dhl',
    requiresAnchor:false, validator:'jjd-prefix' },
  // DHL S10 international: 2 Service + 9 Ziffern + 2 ISO-Land (13 Zeichen).
  { id:'dhl-s10',   re:/\b[A-Z]{2}\d{9}[A-Z]{2}\b/g, carrier:'dhl',
    requiresAnchor:true, validator:'s10-checksum' },   // Anchor: Critique C1-#3
  // Amazon Logistics: TB[ACM] + exakt 12 Ziffern (15 Zeichen). KEINE Checksum.
  { id:'amazon-tba',re:/\bTB[ACM]\d{12}\b/g,         carrier:'amazon',
    requiresAnchor:false, validator:'tba-source-gate' }, // Gate: §2.6
]
```

### 2.4 HTML-href-Pattern (Carrier-Domain → strong)

```ts
const HREF_PATTERNS = [
  // Amazon: nur TB[ACM]\d{12} aus dem Pfad promoten; sonst „Amazon erkannt,
  //   Tracking unbekannt" (detection-only Marker, KEINE Nummer) — Critique C1-#8.
  { re:/track\.amazon\.[a-z.]+\/(?:tracking\/)?(TB[ACM]\d{12})\b/i, carrier:'amazon', source:'html-href' },
  { re:/[?&]trackingId=(TB[ACM]\d{12})\b/i,                          carrier:'amazon', source:'html-href' },
  { re:/[?&]orderingShipmentId=(\d{8,20})/i,                         carrier:'amazon', source:'amazon-shipment-id' }, // medium, NIE primary
  // DHL
  { re:/[?&]piececode=([A-Z0-9]{8,30})/i,                            carrier:'dhl', source:'html-href' },
  { re:/nolp\.dhl\.[a-z.]+\/.*?[?&]idc=([A-Z0-9]{10,30})/i,          carrier:'dhl', source:'html-href' },
  { re:/dhl\.[a-z.]+\/.*?\/track[^?]*\?(?:trackingNumber|tracking)=([A-Z0-9]{8,30})/i, carrier:'dhl', source:'html-href' },
  // DPD — inkl. der ?query=-Form, die die App selbst erzeugt (Research R3-Lücke)
  { re:/tracking\.dpd\.[a-z.]+\/parcelstatus\?(?:[^&]*&)*query=(\d{10,20})/i, carrier:'dpd', source:'html-href' },
  { re:/dpd\.[a-z.]+\/.*?[?&]parcelno(?:r)?=(\d{10,20})/i,           carrier:'dpd', source:'html-href' },
  { re:/(?:track\.)?dpd\.[a-z.]+\/parcels?\/(\d{10,20})/i,           carrier:'dpd', source:'html-href' },
]
```
Ein href-Capture ist `strong` für seinen Carrier (Domain ist das starke Signal).
`orderingShipmentId` bleibt `medium`/`amazon-shipment-id` und wird **nie** primary
(bewahrt das Verhalten, das `amazon_live_test.ts` testet).

### 2.5 Anchor-gated numerische Pattern (Critique C1-#2 BLOCKER-Fix)

Reine `\d{12}`/`\d{20}` haben **nur ~10 % Checksum-Falsch-Akzeptanz** (gemessen
auf 200k Random-Strings: 10.02 % / 10.00 %). Eine 10-%-Checksum ist ein
90-%-Müllfilter, **kein** Strong-Signal. Darum: **`requiresAnchor: true`** —
ein Tracking-Anchor-Wort muss im 80-Zeichen-Fenster davor stehen.

```ts
const ANCHORED_PATTERNS = [
  { id:'dhl-20', re:/\b\d{20}\b/g, carrier:'dhl', requiresAnchor:true, validator:'dhl20-mod10' }, // mod-10 3/1
  { id:'dhl-12', re:/\b\d{12}\b/g, carrier:'dhl', requiresAnchor:true, validator:'dhl-identcode-mod10' }, // mod-10 4/9
  // DPD: NUR via href (§2.4) oder expliziten „DPD"-Anchor; NIE aus reiner
  //   14-stelliger Zahl (kollidiert mit DHL — Research R3). Kein bare-\d{14}.
  { id:'dpd-14', re:/\b\d{14}\b/g, carrier:'dpd', requiresAnchor:true, validator:'dpd-name-anchor' },
]
```

### 2.6 Klassifikation + Validierung (pro überlebendem Kandidaten)

Deterministisch. Validator **bestätigt** (→ strong), ist **prefix-/source-
eindeutig** (→ strong), oder **scheitert** (→ Kandidat DROP, nie geraten).

```
'jjd-prefix':          // J[A-Z]{2,3}\d{10,21} — keine öffentliche Checksum
   accept STRONG, carrier=dhl  (3+ Buchstaben → nie VAT)

's10-checksum':        // [A-Z]{2}\d{9}[A-Z]{2}, requiresAnchor=true
   country = letzte 2 Buchstaben
   if country NICHT in ISO-3166-Liste:                 DROP   (Critique C1-#3)
   if leadingPrefix == country  AND  country in {DE,EL,EE,…VAT}: DROP // VAT+Land-Artefakt
   serial = die 8 Ziffern nach den 2 Service-Buchstaben; check = 9. Ziffer
   if checkS10(serial, check):  accept STRONG, carrier=dhl
   else:                        DROP

'dhl20-mod10':         // \d{20}, requiresAnchor=true
   if checkMod10(first19, d20, {evens_multiplier:3, odds_multiplier:1}):
        accept STRONG, carrier=dhl
   else DROP

'dhl-identcode-mod10': // \d{12}, requiresAnchor=true
   if checkMod10(first11, d12, {evens_multiplier:4, odds_multiplier:9}):
        accept STRONG, carrier=dhl
   else DROP

'tba-source-gate':     // TB[ACM]\d{12} — KEINE Checksum. Sicheres Gate:
   accept STRONG iff:
     - source == html-href (track.amazon / trackingId=)              ODER
     - Mail-Absender-Domain ∈ @amazon.<tld>                          ODER
     - (Tracking-Anchor im Fenster  UND  Amazon-Kontext-Token im Fenster
        {„Amazon", „amazon.de", „Amazon Logistics"})  // Critique C1-#4
   else: keep MEDIUM + needs_review (bare TBA in Nicht-Amazon-Mail)
   carrier=amazon → DETECTION-ONLY (nie gepollt)

'dpd-name-anchor':     // \d{14} aus href ODER mit DPD-spezifischem Anchor
   accept STRONG iff: DPD-href ODER („DPD"/„Paketnummer"+„DPD" im Fenster)
   else: DROP als DPD  (bare \d{14} fällt NICHT automatisch auf DPD; default
         DHL via dhl-12/Leitcode-Pfad — Research R3-Kollisionsregel)
   carrier=dpd
   // mod-37/36 NICHT als Gate (Research R3: Anwendbarkeit auf die bare
   //   14-stellige Kundennummer UNVERIFIZIERT). Gate nur über URL/Anchor.
```

### 2.7 Gating — „right or none, never random"

```
detect(input):
  if status ∈ {ordered, cancelled, refunded}:
     return NONE                       // Tracking nur bei shipped/delivered
  candidates = strongPatterns(bodyText) + hrefPatterns(rawHtml) + anchored(bodyText)
  candidates = candidates.map(normalize).filter(c => checkReject(c.value)==null)
  accepted   = candidates.map(classify).filter(c => c != DROP)
  strong     = accepted.filter(c => c.confidence=='strong' && c.source!='amazon-shipment-id')
  if strong.length == 0:
     return { tracking:null, confidence:'none',
              needsReview: (status∈{shipped,delivered}) && accepted.length>0,
              candidates: accepted.slice(0,10) }
  byValue = uniqueByValue(strong)
  if distinctCarriers(byValue) > 1:     // Cross-Carrier-Widerspruch
     return { tracking:null, confidence:'none', needsReview:true,
              candidates: accepted.slice(0,10) }   // lieber keins als falsch
  primary = pickBySourcePriority(byValue)          // html-href > strong-pattern
  return { tracking:primary.value, trackings:byValue.map(v=>v.value),
           carrier:primary.carrier, confidence:'strong', needsReview:false,
           candidates: accepted.slice(0,10) }
```

**Output-Shape** (füttert `ParsedOrder` wie heute):
```ts
export interface DetectionResult {
  tracking: string | null
  trackings: string[]
  carrier: 'dhl' | 'amazon' | 'dpd' | null
  confidence: 'strong' | 'none'
  needsReview: boolean
  candidates: TrackingCandidate[]   // ≤10, forensisch
}
```

### 2.8 Verdrahtung — API-Gate entfernen (User-Anforderung „immer speichern")

- `resolveTrackingForAdapter` ([`inbox_adapters.ts:901`](../supabase/functions/_shared/inbox_adapters.ts))
  delegiert künftig an `tracking_detection.detect()` und mappt das Ergebnis in
  die `ParsedOrder`-Tracking-Felder. Die 18 Adapter-Call-Sites laufen durch
  diesen einen Helper.
- **`[Council-Fix]` Detection ist NICHT der einzige Chokepoint — ZWEI
  `applyDhlValidation`-Call-Sites löschen** (Architekt-Finding): nicht nur
  `inbox_parse_runner.ts:199`, sondern AUCH **`inbox-parse/index.ts:565`**
  (Re-Parse-Pfad). Wird die zweite vergessen, löscht der Re-Parse frisch
  erkannte Trackings wieder (kein Key → drop). → `inbox-parse/index.ts` in §5
  aufnehmen (inkl. `stampPipelineHeartbeat`-Import beibehalten).
- **`[Council-Fix]` `carrier` muss tatsächlich an den Deal geschrieben werden**
  (Bug-Hunter KRITISCH #1): `applyUpdateToDeal` (`inbox_parse_runner.ts:354`)
  schreibt heute nur `tracking/status/arrival_date/note` — **nicht `carrier`**.
  Ohne expliziten Edit landet jeder auto-gematchte Deal mit `carrier=NULL` →
  Poller fällt auf `detectAdapter` zurück → genau die DPD→DHL-Fehlrouting, die
  §3.1 verhindern soll. → `applyUpdateToDeal` UND der `pending_deal_suggestions`-
  Pfad UND der manuelle Eingabe-Pfad müssen `carrier` setzen.
- **`[Council-Fix]` Carrier-Casing projektweit auf lowercase** (Bug-Hunter
  KRITISCH #2, Architekt): Bestandscode emittiert `'DHL'`/`'DPD'` (uppercase,
  `inbox_parse_runner.ts:298`, `inbox_adapters.ts:713`, `pending_deal_suggestions`).
  Der neue CHECK ist `('dhl','amazon','dpd')` → jeder uppercase-Write wirft
  `check_violation` und **rollbackt den ganzen Deal-Write**. → `detect()`
  emittiert lowercase; ein `.toLowerCase()`-Guard vor JEDEM `deals.carrier`-Write;
  Negativ-Test „`'DHL'` → Violation" ergänzen.
- **`[Council-Fix]` Manuelle Tracking-Eingabe** (UX-Finding): `updateDealTrackingManually`
  speichert heute roh. **Entscheidung:** manuell getippte Werte laufen durch
  `checkReject` — eine VAT-aussehende Eingabe wird mit Inline-Hinweis abgelehnt
  (nicht als `confidence='strong'`-Tracking gespeichert). Der User kann sie
  bewusst als Notiz behalten, aber sie wird NIE poll-eligible. (Dokumentiert,
  damit „nichts falsches" auch im manuellen Pfad gilt.)
- **Löschen:** `dhl-de-prefix`, `dhl-de-suffix` (→ ersetzt durch S10),
  `context-numeric-10-22` (→ ersetzt durch `dhl-20`/`dhl-12` anchored + href).
- **Löschen:** `enrichWithDhlValidation` + `EnrichOptions` + DHL-Probe-Loop in
  `tracking_validation.ts`; beide `applyDhlValidation`-Call-Sites.
  `stampPipelineHeartbeat`/`normalizeTracking` bleiben (relokalisiert nach
  `tracking_detection.ts`).
- **`[Council-Fix]` PII-Logging:** `tracking_detection.ts` loggt NIEMALS rohe
  Mail-Bodies oder volle Tracking-Nummern (max. `redactTracking`-Pattern wie
  bestehend). Acceptance-Gate: Log-Scan (kein Body/Tracking in `console`/`print`).
- Resultat: ein erkanntes Tracking wird **mit oder ohne Carrier-Key** persistiert
  (`tracking_confidence='strong'`, `carrier` lowercase gesetzt). Live-Status
  füllt der Poller (§3).

---

## 3. Teil B — Status-Polling (täglich 13:00 + bei Zuweisung)

### 3.1 `deals.carrier`-Spalte (Critique C2-#1 BLOCKER)

Existiert heute **nicht**. Wird gebraucht für Poller-Carrier-Präferenz +
Amazon-Skip + Live-Status-Seed.

```sql
ALTER TABLE public.deals
  ADD COLUMN IF NOT EXISTS carrier text
  CHECK (carrier IS NULL OR carrier IN ('dhl','amazon','dpd'));
```
Detection persistiert `carrier` (**lowercase**, §2.8 Casing-Fix). Poller liest
`carrier` und nutzt `ADAPTERS[deal.carrier] ?? detectAdapter(deal.tracking)` —
**`deal.carrier` ist primär, `detectAdapter` nur Fallback** (Critique C1-#5/C2-#1:
bare \d{14} ohne `05`-Prefix würde sonst fälschlich auf DHL geroutet).

**`[Council-Fix]` Schreib-Pfade für `carrier` (sonst tote Spalte, Bug-Hunter #1):**
`applyUpdateToDeal`, der `pending_deal_suggestions`→Deal-Link-Pfad und der
manuelle Eingabe-Pfad müssen `carrier` setzen — nicht nur die Migration.

**`[Council-Fix]` Backfill-Grenze (Bug-Hunter #6):** `parsed_messages`-Bodies
werden nach 30 Tagen via `cleanup_inbox_history` gelöscht. Deals älter als 30d
haben keinen Body mehr → Re-Detection liefert `carrier=NULL` + keinen Anchor.
Für solche Rows: `carrier` aus `detectAdapter`-Heuristik ableiten ODER explizit
`tracking_needs_review=true` setzen — **nie still NULL lassen**. Pre-Launch sind
das wenige Rows; der Backfill ist ein einmaliges Skript/Migration.

### 3.2 Daily-Sweep 13:00 Europe/Berlin (DST-sicher)

pg_cron läuft in **UTC**; Berlin = UTC+1 (Winter) / UTC+2 (Sommer). Lösung
(numerisch über ganz 2026 inkl. beider DST-Wechseltage verifiziert, Critique C2):
Cron feuert an **beiden** UTC-Kandidatenstunden, die Edge-Function gated auf die
echte Berliner Wanduhr-Stunde via `Intl.DateTimeFormat('Europe/Berlin')`.

- 13:00 Berlin = **12:00 UTC (Winter)** / **11:00 UTC (Sommer)**.
- Cron `0 11,12 * * *` → genau **eine** der beiden Feuerungen passiert pro Tag
  den Guard, ganzjährig automatisch über den DST-Wechsel.

```ts
// index.ts — exportierte Pure-Helper (unit-getestet)
export function berlinHourNow(nowMs = Date.now()): number {
  return Number(new Intl.DateTimeFormat('en-GB',
    { timeZone:'Europe/Berlin', hour:'2-digit', hour12:false }).format(new Date(nowMs)))
}
export function dailySweepShouldRun(mode: string|undefined, targetHours: number[], nowMs=Date.now()): boolean {
  if (mode !== 'daily-sweep') return true            // single-deal/manual/service → bypass
  if (!targetHours || targetHours.length === 0) return false   // FAIL-CLOSED (Critique C2-#7)
  return targetHours.includes(berlinHourNow(nowMs))
}
```
Guard-Platzierung: **nach** der Auth-Resolution, **vor** der Workspace-Schleife
(≈ index.ts:214). Off-Hour-Feuerungen geben billig `200 {skipped:'off-hour'}`
zurück (keine DB-Arbeit). `mode`-Parsing strikt getrennt von und nach der
`parseDealIdFromBody`-Validierung. Default-Target server-seitig `[13]` hart
verdrahtet; Body-Feld nur als Override, fail-closed bei leer/invalid.

> **User-Spec = exakt 1×/Tag um 13:00.** Das ist eine ~6×-Freshness-Reduktion
> ggü. dem alten 4h-Cron für Klarna-Style-Zwischenstatus. Der Event-Trigger
> (§3.3) deckt die Freshness-bei-neuem-Tracking. **Optionaler Opt-in (NICHT
> Default):** zusätzlicher 19:00-Berlin-Sweep → Cron `0 11,12,17,18 * * *`,
> Target `[13,19]`. Entscheidung beim Stakeholder; Default hält die User-Spec
> (nur 13:00).
>
> **`[Council-Fix]` DHL-Quota verifizieren (External-Scout):** Der Repo-Code-
> Kommentar behauptet „Parcel-DE 10 Mio/Tag", der Scout findet aber für die DHL-
> Paket-DE-Sendungsverfolgung ~1.000 Queries/Tag + **3 req/s**. → vor Rollout das
> **tatsächliche Limit des genutzten Public-XML-Query-Endpoints** (PR #108)
> verifizieren. Der bestehende `SPIKE_ARREST_MS`-Mechanismus muss ggf. die
> 3-req/s-Grenze respektieren; Daily-Sweep (`MAX_DEALS_PER_RUN=200`) + Backfill
> + Trigger-Bursts dürfen sie nicht reißen.

Cron-Reschedule (ersetzt `tracking-poll-4h`) — siehe §7 Setup-Schritt C.

### 3.3 Event-Trigger: Poll sofort bei (erstem) Tracking

**Mechanismus: Postgres-`AFTER`-Trigger + `net.http_post`.** Einziger Pfad, der
für **alle Quellen einheitlich** feuert (Inbox-Auto-Assign, manuelle Eingabe,
Re-Parse) — alle schreiben am Ende `deals.tracking`. Client-`retrackDeal` deckt
nur manuelle Speicherung; ein In-Process-Call im Inbox-Runner nur Inbox. Der
DB-Trigger sitzt am einzigen Chokepoint.

```sql
-- [NEW] Funktion + Trigger + private.edge_config-Tabelle + _edge_config()-Reader
--       sind allesamt NEU (Migration …_tracking_poll_event_trigger.sql, §4).
--       (Hinweis: validate-plan.sh flaggt SQL-Funktions-/Schema-/Extension-Namen
--        wie 'net'/'cron'/'public'/'_edge_config' fälschlich als fehlende Tabellen
--        — Heuristik-False-Positive; die einzige echte NEUE Tabelle ist
--        'private.edge_config'.)
CREATE OR REPLACE FUNCTION public.deals_enqueue_tracking_poll()  -- [NEW] Critique C2-#3: umbenannt
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, net, vault, extensions AS $$
DECLARE v_url text; v_secret text;
BEGIN
  IF NEW.tracking IS NULL OR btrim(NEW.tracking) = '' THEN RETURN NEW; END IF;
  IF TG_OP='UPDATE' AND NOT (NEW.tracking IS DISTINCT FROM OLD.tracking) THEN
     RETURN NEW;   -- unveränderter Wert → kein Enqueue
  END IF;
  -- [Council-Fix] Bulk-Re-Parse-Drossel (Security-Finding): "Sendungsnummern neu
  -- prüfen" über N Deals würde N Sofort-Polls auslösen. Der Re-Parse-Pfad setzt
  -- in seiner Transaktion `SET LOCAL app.suppress_tracking_poll = 'on'`; dann
  -- übernimmt der Daily-Sweep statt N Einzel-Enqueues.
  IF current_setting('app.suppress_tracking_poll', true) = 'on' THEN
     RETURN NEW;
  END IF;
  v_url    := public._edge_config('tracking_poll_url');
  v_secret := public._edge_config('cron_secret');
  IF v_url IS NULL OR v_secret IS NULL THEN
     RAISE NOTICE 'tracking-poll enqueue skipped (edge config missing) deal %', NEW.id;
     RETURN NEW;   -- Detection/Speicherung ist schon passiert; Daily-Sweep zieht nach
  END IF;
  -- [Council-Fix] KEIN live_status_updated_at-Stempel hier (Bug-Hunter #3):
  -- ein Stempel würde den 30s-Cooldown auch für DIESEN enqueued Single-Deal-Poll
  -- auslösen und ihn selbst blocken. Stattdessen wird der seltene Doppel-Poll
  -- (Trigger + gleichzeitiger manueller Retrack) als benign akzeptiert — der
  -- Carrier-Read ist idempotent, ein evtl. 429 wird vom Client als
  -- RetrackResult.rateLimited geschluckt (kein Roh-Fehler beim User).
  BEGIN
    PERFORM net.http_post(
      url := v_url,
      headers := jsonb_build_object('Authorization','Bearer '||v_secret,'Content-Type','application/json'),
      body := jsonb_build_object('deal_id', NEW.id),   -- single-deal-Pfad → kein Hour-Guard
      timeout_milliseconds := 60000);
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'net.http_post failed for deal %: %', NEW.id, SQLERRM;  -- load-bearing: darf Deal-Write NIE rollbacken
  END;
  RETURN NEW;
END; $$;
REVOKE EXECUTE ON FUNCTION public.deals_enqueue_tracking_poll() FROM PUBLIC;
DROP TRIGGER IF EXISTS deals_enqueue_tracking_poll_trg ON public.deals;
CREATE TRIGGER deals_enqueue_tracking_poll_trg
  AFTER INSERT OR UPDATE OF tracking ON public.deals
  FOR EACH ROW EXECUTE FUNCTION public.deals_enqueue_tracking_poll();
```

Eigenschaften:
- **`AFTER` + `UPDATE OF tracking` + `IS DISTINCT FROM`** → feuert bei Erst-
  Zuweisung UND bei echter Tracking-Änderung (korrigiertes Tracking → frischer
  Poll = gewolltes Verhalten, Critique C2-#3), nie bei unveränderten Writes
  (Status/Note-Edits).
- **`{deal_id}`** → single-deal-Pfad → **kein** Hour-Guard; erster Poll hat
  `live_status_updated_at=NULL` → Cooldown blockt nicht (Critique C2-#8).
- **`Bearer CRON_SECRET`** → `isCron`-Pfad in `index.ts` → kein `verify_jwt`-401.
- **Kein Infinite-Loop** (verifiziert): `buildLiveStatusUpdate` schreibt nie die
  `tracking`-Spalte, nur `live_status`/`status`/`arrival_date` → Trigger
  re-feuert nicht.
- **`verify_jwt = false` ist Pflicht-Voraussetzung** (Critique C2-#2 BLOCKER):
  `net.http_post` mit `Bearer CRON_SECRET` (kein JWT) wird vom Plattform-Gateway
  abgelehnt, falls `verify_jwt:true` (Default ohne config). → neue Datei
  `supabase/config.toml` mit `[functions.tracking-poll] verify_jwt = false`.
  Smoke: nach Trigger-Feuerung `net._http_response` auf HTTP 200 prüfen.
- **`net._http_response`-Reaper** (Critique C2-#2): wächst unbegrenzt → täglicher
  Cleanup-Job (z. B. in `cleanup.sh`-Analogon oder pg_cron-DELETE > 7 Tage).

**Behalten:** Client-`retrackDeal` (Refresh-Icon im Deal-Detail) als
komplementärer, user-initiierter Pfad. **Kein** zusätzlicher Inbox-Runner-HTTP-
Call (würde mit dem Trigger doppelt feuern).

### 3.4 Amazon = detection-only (sauberer Skip)

- `detectAdapter('TB[ACM]…')` → `null` → Poller `continue` (existiert schon,
  index.ts:309). Zusätzlich defensiver `^TB[ACM]\d{12}$`-Short-Circuit in
  `pollWorkspace` (verbraucht kein Call-Budget).
- **`[Council-Fix]` `pollWorkspace`-Typing** (Architekt, Security): die Carrier-
  Union/Sets sind heute `'dhl'|'dpd'|'ups'`. Der `'amazon'`-Wert muss VOR dem
  `carriers.has()`-Gate short-circuiten; `ADAPTERS` darf **keinen `'amazon'`-Key**
  haben (sonst Lookup-Miss/TS-Fehler). `ADAPTERS[deal.carrier]` nur für
  `'dhl'|'dpd'`; alles andere → Fallback `detectAdapter` bzw. skip.
- **`[Council-Fix]` Amazon-Badge-State sauber** (UX-Finding): `live_status='pending'`
  rendert heute als „Wird vorbereitet" — irreführend für Amazon (kommt nie ein
  Status). Darum **eigener Anzeige-State** + neuer l10n-Key
  `trackingAmazonNoLiveStatusBadge` („Sendung erkannt — Live-Status nicht
  verfügbar"), DE+EN. `live_status_last_event` = l10n-Key (kein hardcoded
  DE-String, Critique C2-#11). `'pending'` bleibt der DB-Wert (im CHECK-Enum,
  keine Enum-Migration), aber die UI-Resolution unterscheidet `carrier=='amazon'`.
- **`[Council-Fix]` Retrack-Disable verdrahten** (UX-Finding): `add_edit_deal_dialog`
  setzt `onRetrack` heute immer. Für `deal.carrier=='amazon'` → Button disabled
  mit Tooltip-l10n-Key `trackingRetrackUnavailableAmazon` (Touch-Target 48dp
  bleibt). Im `TrackingStatusBlock` einen disabled-mit-Tooltip-State (statt
  `onRetrack==null`-Verstecken).
- DE-Praxis-Bonus: Amazon übergibt oft an DHL → dieselbe Mail enthält häufig eine
  JJD/DHL-Nummer, die sehr wohl pollbar ist. Detection erfasst sie als primären
  (pollbaren) Kandidaten; TBA bleibt sekundär in `trackings[]`.

---

## 4. Datenbank-Migrationen

| Migration | Inhalt | RLS / Idempotenz |
|---|---|---|
| `…_deals_carrier_column.sql` | `ALTER TABLE deals ADD COLUMN carrier text CHECK(...)` | `IF NOT EXISTS`; erbt deals-RLS |
| `…_tracking_poll_event_trigger.sql` | `private.edge_config` (RLS default-deny, 0 Policies, REVOKE) + `_edge_config()` SECURITY-DEFINER-Reader + `deals_enqueue_tracking_poll()` + Trigger + idempotenter Vault-NOTICE-Bootstrap | alle DDL `IF NOT EXISTS`/`CREATE OR REPLACE`/`DROP … IF EXISTS`; Vault-`DO` in `EXCEPTION` gewrappt → läuft auf Vault-loser Lokal-Stack grün |
| `…_drop_tracking_validation_cache.sql` | `DROP TABLE IF EXISTS tracking_validation_cache` (toter Code nach Wegfall von `enrichWithDhlValidation` — Critique C2-#6; Pre-Launch safe) | — |
| **`[Council-Fix]` `…_net_http_response_reaper.sql`** | pg_cron-Job `DELETE FROM net._http_response WHERE created < now()-interval '24h'` **UND** `net._http_request` (Security-Finding: hält den `Authorization: Bearer CRON_SECRET`-Header im Klartext!). Eng (≤24h, idealerweise <1h). | idempotenter `cron.schedule` in `DO`-Block |

**`[Council-Fix]` Security-Härtung in `…_tracking_poll_event_trigger.sql`
(Pflicht für `db-migrator`, Security-Findings):**
- `REVOKE EXECUTE ON FUNCTION public._edge_config(text) FROM PUBLIC;` (analog
  `_carrier_master_key`) — sonst könnte `authenticated` die Funktion per RPC
  callen und den Secret abgreifen.
- `REVOKE USAGE ON SCHEMA private FROM anon, authenticated;` +
  `REVOKE ALL ON ALL TABLES IN SCHEMA private FROM anon, authenticated;` +
  `ALTER DEFAULT PRIVILEGES …`. Migrations-Kommentar: **`private` NIEMALS zu den
  PostgREST-exposed-Schemas (`db-schemas`) hinzufügen.**
- **`_edge_config` liefert `cron_secret` AUSSCHLIESSLICH aus Vault** (kein
  Table-/GUC-Fallback für sensible Keys) — sonst landet der Secret als
  Klartext-Row in `private.edge_config` (schwächer als Vault, in DB-Backups).
  Nicht-sensible Config (`tracking_poll_url`) darf den Table-Fallback nutzen.
  Internes Key-Mapping `'cron_secret'` → Vault-Secret `'edge_cron_secret'`
  explizit im Reader.

**`supabase db reset` muss grün laufen** (Pflicht vor Commit). Der Event-Trigger
feuert beim Reset nicht (keine Deals werden eingefügt); selbst wenn → `_edge_config`
liefert NULL → Enqueue geskippt, kein `net.http_post`. **`[Council-Fix]`
Test-Gate:** `net.http_post` auf dem lokalen `db reset`-Stack smoke-testen
(pg_net evtl. nicht installiert → Trigger muss trotzdem grün durchlaufen).

**Cron + Vault-Secret + URL** werden **manuell** im SQL-Console gesetzt (§7) —
sie brauchen die konkrete Projekt-URL + `CRON_SECRET`, die pro Umgebung
differieren und zur Migrations-Zeit unbekannt sind (Präzedenz: bestehende
edge-fn-Cron-Jobs in `SETUP.md`).

---

## 5. Datei-Liste (ADD / MODIFY / DELETE)

**ADD**
- `supabase/functions/_shared/tracking_detection.ts` — `detect()`, Pattern-/
  Reject-Tabellen, `classifyAndValidate()`, ISO-3166-Country-Set, `checkReject()`.
- `supabase/functions/_shared/tracking_detection_test.ts` — Detektor-Unit-Tests.
- `supabase/functions/_shared/checksums_test.ts` — Checksum-Primitiven isoliert
  (DHL mod-10 3/1 + 4/9, S10 mod-11, DPD mod-37/36) inkl. mutated-digit-Negativen.
- `supabase/functions/_shared/inbox_vat_reject_test.ts` — die VAT-Kollisions-Wall
  (das „Reviewer liest diese Datei zuerst"-File).
- `supabase/functions/tracking-poll/daily_1300_trigger_test.ts` — Pure-Tests
  `berlinHourNow`/`dailySweepShouldRun` über DST-Grenzen (Winter 12 UTC / Sommer
  11 UTC), mode-undefined-Bypass, deal_id-Bypass, fail-closed.
- `supabase/config.toml` — `[functions.tracking-poll] verify_jwt = false`.
  **`[Council-Fix]` strikt nur auf tracking-poll scopen** (Security): `inbox-poll`
  NUR ändern, wenn dessen Auth-Matrix (isCron/isService/JWT/401) das verträgt —
  vorher verifizieren, nicht „analog" annehmen.
- **4 Migrationen (§4)** — inkl. `…_net_http_response_reaper.sql`.

**MODIFY**
- `supabase/functions/_shared/inbox_adapters.ts` — `resolveTrackingForAdapter`
  delegiert an `detect()`; `dhl-de-prefix`/`dhl-de-suffix`/`context-numeric-10-22`
  entfernt; Carrier-Strings lowercase `'dhl'|'amazon'|'dpd'`; Anchor-Helper
  re-exportiert.
- `supabase/functions/_shared/inbox_parse_runner.ts` — **erste** `applyDhlValidation`-
  Call-Site (L199) löschen; `stampPipelineHeartbeat`-Call behalten;
  **`[Council-Fix]` `applyUpdateToDeal` schreibt `carrier` (lowercase)**;
  Amazon-Seed (`live_status='pending'` + l10n-`last_event`) bei Speicherung.
- **`[Council-Fix]` `supabase/functions/inbox-parse/index.ts`** — **zweite**
  `applyDhlValidation`-Call-Site (L565) löschen (Re-Parse-Pfad); Re-Parse setzt
  `SET LOCAL app.suppress_tracking_poll='on'` (Bulk-Drossel, §3.3).
- `supabase/functions/_shared/tracking_validation.ts` — `enrichWithDhlValidation`
  + `EnrichOptions` + Cache-Loop löschen; `normalizeTracking`/
  `stampPipelineHeartbeat` behalten/relokalisieren.
- `supabase/functions/_shared/tracking_adapters.ts` — `detectAdapter`: Amazon
  `TB[ACM]\d{12}` → `null` (detection-only); S10/JJD/`\d{20}`/`\d{12,14}` → DHL;
  `05…` → DPD. `ADAPTERS` ohne `'amazon'`-Key.
- `supabase/functions/tracking-poll/index.ts` — `mode`+`target_berlin_hours`-
  Parse; `berlinHourNow`/`dailySweepShouldRun`; Off-Hour-Guard; `carrier` ins
  `pollWorkspace`-Select + `DealRow`; `ADAPTERS[deal.carrier] ?? detectAdapter`;
  Carrier-Union um `'amazon'` + Amazon-Short-Circuit vor `carriers.has()`.
- `supabase/functions/tracking-poll/SETUP.md` — §4 (4h → daily 13:00 Berlin),
  Trigger-Config, Amazon detection-only, key-optional-Speicherung, verify_jwt,
  Reaper.
- **`[Council-Fix]` Client (UX-Findings, alle PFLICHT):**
  - `lib/models/deal.dart` — neues `carrier`-Feld + `fromJson`/`toJson`.
  - `lib/services/carrier_service.dart` — **`_dhlDePrefix` (`^DE\d{8,14}$`)
    entfernen** (Client dupliziert den VAT-Bug → Badge zeigt sonst „DHL" für
    `DE123456789`); Carrier künftig aus `deal.carrier` statt Re-Detect.
  - `lib/widgets/tracking_chip.dart` — Carrier aus `deal.carrier`.
  - `lib/widgets/add_edit_deal_dialog.dart` + `TrackingStatusBlock` —
    Amazon-Retrack disabled + Tooltip; Amazon-no-live-status-Badge-State;
    manuelle Eingabe läuft durch `checkReject` (VAT-Hinweis).
  - `lib/services/supabase_repository.dart` — `carrier` im Deal-Select; manueller
    Tracking-Write setzt `carrier` (lowercase).
- l10n: `lib/l10n/app_de.arb` + `app_en.arb` — neue Keys
  `trackingAmazonNoLiveStatusBadge`, `trackingRetrackUnavailableAmazon`,
  `trackingManualVatRejected` (symmetrisch DE+EN).
- **`[Council-Fix]` `/update-help`** (UX): Hilfe-Keys sagen „alle 4 Stunden" /
  „nur DHL" / „Amazon keine API" → nach Impl. `/update-help --apply` (siehe §10).

**DELETE / REWRITE Tests** (Critique C2-#5 — sonst Compile-Fehler der ganzen Suite)
- `supabase/functions/_shared/tracking_validation_test.ts` — löschen oder auf die
  überlebenden Helper (`normalizeTracking`/`isCacheFresh`/`stampPipelineHeartbeat`)
  reduzieren.
- `tracking_fixtures_test.ts` / `test_fixtures/tracking_fixtures.ts` — neue
  Positiv-/Negativ-Korpora; `Deno.test.ignore`'te TBA/S10/DHL-20-Fälle re-
  authoren.
- `inbox_reject_patterns_test.ts` — `vat_eu`-Asserts + Regression „`DE123456789`
  wird gerejected".
- `amazon_live_test.ts` — **grün halten** als Regression-Anker (orderingShipmentId
  bleibt medium).
- `tracking_real_samples_test.ts` — auf DHL/Amazon/DPD/S10 trimmen, in-scope
  0-Fehler.
- `tracking-poll/poll_eligibility_test.ts` / `single_deal_test.ts` — Amazon nie
  poll-eligible; DHL/DPD-ohne-Key = benigner Skip (0 errors, 0 checked).

---

## 5b. Atomare Task-Liste (mit Abhängigkeiten + `agent:`) `[Council-Fix]`

Reihenfolge = Dependency-Reihenfolge. Jeder Task ist 1 PR-fähiges Increment.

- [x] **T1 — Migration `deals.carrier`** (`agent:db-migrator`). `ALTER TABLE … ADD
  COLUMN carrier text CHECK(... lowercase)`. `supabase db reset` grün. *(keine deps)*
- [x] **T2 — Detection-Modul + Checksum-Tests** (`agent:edge-fn-coder`).
  `tracking_detection.ts` (§2) + `checksums_test.ts` + `tracking_detection_test.ts`
  + `inbox_vat_reject_test.ts`. Rein, kein DB. *(keine deps; parallel zu T1)*
- [x] **T3 — Verdrahtung + Casing + API-Gate-Removal** (`agent:edge-fn-coder`).
  `resolveTrackingForAdapter`→`detect()`; beide `applyDhlValidation`-Sites löschen
  (runner + inbox-parse); `applyUpdateToDeal`/pending/manuell schreiben `carrier`
  lowercase; alte Pattern entfernen; `enrichWithDhlValidation` löschen. *(deps: T1, T2)*
- [x] **T4 — Poller-Anpassung** (`agent:edge-fn-coder`). `index.ts`: `mode`/Hour-
  Guard (`berlinHourNow`/`dailySweepShouldRun`), `carrier`-Select, `ADAPTERS[carrier]
  ?? detectAdapter`, Amazon-Short-Circuit + Union; `detectAdapter`-Rewrite. *(deps: T1)*
- [x] **T5 — Event-Trigger-Migration + config.toml** (`agent:db-migrator`).
  `private.edge_config` + `_edge_config()` (Vault-only Secret, REVOKE) +
  `deals_enqueue_tracking_poll` + Trigger + Bulk-Drossel; `config.toml`
  verify_jwt=false (nur tracking-poll); Reaper-Migration. *(deps: T4)*
- [x] **T6 — `tracking_validation_cache` DROP + Test-Cleanup** (`agent:edge-fn-coder`).
  Drop-Migration; `tracking_validation_test.ts` löschen/reduzieren; `amazon_live_test.ts`
  grün halten; Fixtures/Reject-Tests re-authoren; `deno test` kompiliert. *(deps: T3)*
- [x] **T7 — Client** (`agent:flutter-coder` + `agent:ui-builder`). `Deal.carrier`;
  `carrier_service._dhlDePrefix` raus; `tracking_chip`; Amazon-Retrack-disable +
  Badge-State; manuelle Eingabe `checkReject`; l10n DE+EN. *(deps: T1)*
- [x] **T8 — Backfill `carrier` für Legacy-Deals** (`agent:db-migrator`, in DB-Wave gefaltet).
  Re-Detection wo Body vorhanden; >30d ohne Body → Heuristik/needs_review. *(deps: T3)*
- [x] **T9 — Test-Korpora + Gates grün** (`agent:tester`). flutter analyze clean, flutter test 878/0, deno _shared 268/0 + poll 47/0 + inbox-parse 16/0, db reset grün. §6 Negativ/Positiv,
  DST-Guard, db reset, net.http_post-Smoke. *(deps: T3,T4,T5,T6)*
- [x] **T10 — Security-Review** (`agent:security-reviewer`). verdict: pass — alle 6 Council-Security-Findings im Diff umgesetzt; 2 Low-Nits (Reaper-Kommentar gefixt, Backfill-14-stellig akzeptiert).
  *(deps: T5)*
- [x] **T11 — `/update-help`** + `smoke-full-app-audit` (`agent:help-curator` +
  `agent:browser-tester`). Help: 3 Sektionen + Amazon-FAQ aktualisiert, l10n symmetrisch
  (1602/1602). Smoke: alle 6 Tracking-Checks PASS, 0 Console-Errors, kein Overflow;
  `Result: failed` NUR wegen **pre-existing** Dark-Mode-Leak in `add_edit_deal_dialog.dart`
  (nicht im Tracking-Diff, blame e189c2b) → eigener Auto-Requeue-Followup. *(deps: T7)*
- [ ] **T12 — Setup (manuell) + Rollout** (User/Stakeholder): §7 Schritte A–C,
  Re-Parse-Dry-Run. *(deps: alle)*

---

## 6. Test-Strategie + Acceptance-Gate

**Asymmetrisches Fehlerbudget:** Falsch-Positive = 0 (harter Blocker);
Falsch-Negative = weicher Floor.

### Positiv-Korpus (muss strong + korrekten Carrier liefern)
DHL JJD `JJD000390007299011234`; DHL-20 `00340433836442636597` (mod-10 3/1 ✓);
Identcode `201298452277` (mod-10 4/9 ✓); S10 `RB123456785DE` / `CC473124829DE`
(✓ + ISO-Land); Amazon TBA `TBA651782912737` (mit Amazon-Anchor → strong, ohne
→ medium); Amazon track-URL; DPD via `tracking.dpd.de/parcelstatus?query=…`;
DPD mit „DPD Paketnummer"-Anchor.

### Negativ-Korpus (muss `primary===null` — die Kardinal-Wall)
- **VAT:** `DE123456789`, `DE811569869`, `EL123456789`, `EE123456789`,
  `DE 123 456 789` (mit Spaces), Body „USt-IdNr.: DE123456789".
- **VAT+Land-Artefakt:** `DE123456789DE` (13 Zeichen) → muss als S10
  **gedroppt** werden (kein valider ISO-Service-Prefix-Kontext / Anchor;
  Critique C1-#3).
- **IBAN:** `DE89370400440532013000`, `FR1420041010050500013M02606`.
- **Amazon-Order:** `303-1234567-1234567`; `orderingShipmentId=…` bleibt medium.
- **Telefon:** `+498912345678`, `+49 30 1234567890`.
- **PLZ/Invoice/Customer:** `10115`, `12345678`, `RG-2026-00123`.
- **Anchorlos numerisch (Checksum egal):** GA-cid `12345678901234567890` (kein
  Anchor) → none (beweist Anchor-Pflicht, Critique C1-#2).
- **Checksum-mutiert:** jede valide Nummer mit 1 geflippter Ziffel → none
  (beweist Checksum-Gate).
- **No-Shipment-Mails:** Bestellbestätigung/Rechnung/Newsletter/Passwort-Reset
  → 0 Trackings.

### Acceptance-Gate (GO nur wenn ALLE wahr)
- ✅ 0 Falsch-Positive über das gesamte Negativ-Korpus (Token- UND Body-Ebene).
- ✅ `checkReject('DE123456789')` rejected (alter `dhl-de-prefix` weg) —
  explizite Regression des Original-Bugs.
- ✅ Jede checksum-mutierte Positiv-Nummer → none (Mathe-Wiring bewiesen).
- ✅ Detection funktioniert OHNE Carrier-API-Key (store-without-key bewiesen).
- ✅ Recall ≥ 90 % Floor (Ziel 95 %) auf Positiv-Korpus; jeder Miss ist ein
  expliziter, dokumentierter Test (kein stiller Gap).
- ✅ DST-Guard: `dailySweepShouldRun` feuert exakt 1×/Tag um 13:00 Berlin
  (Winter+Sommer-Tests).
- ✅ RLS/Exposure-Test: authenticated-Rolle kann `private.edge_config` nicht
  lesen und `_edge_config()` nicht callen (Critique C2-#10).
- ✅ `deno test --allow-read supabase/functions/` kompiliert + grün (eine
  dangling import killt die ganze Suite — Critique C2-#5).
- ✅ `supabase db reset` grün; Re-Parse-Dry-Run-Diff über bestehende Mails zeigt
  VAT/IBAN-Falsch-Positive entfernt, **null** neu eingeführt.
- ✅ `smoke-full-app-audit` grün (UI-Pfade: Manual-Deal-VAT, Real-DHL-Poll,
  Deal-Detail-Retrack, **Amazon-Deal disabled-Retrack + Badge**, **Deal mit
  Carrier ohne API-Key → `live_status=none`, kein Fehler**). Phone 360×640 + 390×844.
- ✅ **`[Council-Fix]`** Casing: `deals.carrier` mit `'DHL'` (uppercase)
  → `check_violation` (Negativ-Test); jeder Write-Pfad schreibt lowercase.
- ✅ **`[Council-Fix]`** `carrier` wird tatsächlich geschrieben (auto-match,
  pending-link, manuell) — Test, dass kein neuer Deal `carrier=NULL` hat.
- ✅ **`[Council-Fix]`** Client-VAT: `CarrierService.detect('DE123456789')` ist
  NICHT `Carrier.dhl` (Badge zeigt kein „DHL").
- ✅ **`[Council-Fix]`** Security: `REVOKE EXECUTE ON _edge_config FROM PUBLIC`
  durchgesetzt; `cron_secret` nur aus Vault (nicht aus `private.edge_config`);
  Reaper löscht `net._http_request` **und** `_http_response` (CRON_SECRET-Klartext).
- ✅ **`[Council-Fix]`** `net.http_post`-Smoke auf lokalem `db reset`-Stack (pg_net
  evtl. nicht da → Trigger trotzdem grün); PII-Log-Scan (kein Body/Tracking in Logs).

---

## 7. Manuelle Setup-Schritte (1× pro Umgebung, präzise)

Voraussetzung: `supabase` CLI eingeloggt + Projekt verlinkt; `<PROJECT_REF>` und
der bereits gesetzte `CRON_SECRET` (SETUP.md §2) bekannt.

### Schritt A — `tracking-poll` neu deployen (Hour-Guard + Amazon-Skip + config.toml)
- **Wo:** lokale Shell, Repo-Root. **Voraussetzung:** Code aus §2/§3 + neue
  `supabase/config.toml` (verify_jwt=false) gemergt.
- **Befehl:** `supabase functions deploy tracking-poll --project-ref <PROJECT_REF>`
- **Erfolg:** CLI „Deployed Function tracking-poll". Verify:
  `supabase functions invoke tracking-poll --project-ref <PROJECT_REF>` (ohne Body)
  → `{"ok":true,...}` (kein `mode` → Guard-Bypass, voller Sweep).
- **Fehler:** non-zero Exit / Deno-Compile-Error in der CLI-Ausgabe.

### Schritt B — Trigger-URL + CRON_SECRET provisionieren
- **Wo:** Supabase SQL-Console (Dashboard → SQL Editor).
- **Voraussetzung:** Migrationen aus §4 angewandt (`supabase db push` grün —
  laut CLAUDE.md §Supabase erlaubt).
- **Befehle:**
  ```sql
  INSERT INTO private.edge_config(key, value)
  VALUES ('tracking_poll_url','https://<PROJECT_REF>.functions.supabase.co/tracking-poll')
  ON CONFLICT (key) DO UPDATE SET value=EXCLUDED.value, updated_at=now();

  SELECT vault.create_secret('<CRON_SECRET>', 'edge_cron_secret',
                             'Event-Trigger-Secret für deal-tracking poll');
  ```
- **Erfolg:** `SELECT public._edge_config('tracking_poll_url');` → URL;
  `SELECT length(public._edge_config('cron_secret'));` → 64 (≠ NULL). Smoke:
  ```sql
  UPDATE public.deals SET tracking='00340433836442636597' WHERE id=<test_deal>;
  SELECT status_code, created FROM net._http_response ORDER BY created DESC LIMIT 3;
  -- erwartet: HTTP 200 (NICHT 401 → sonst verify_jwt noch an, Schritt A prüfen)
  ```
- **Fehler:** `_edge_config('cron_secret')` NULL → Vault-Secret falsch benannt
  (muss `edge_cron_secret` heißen). 401 in `net._http_response` → `verify_jwt`
  für tracking-poll noch aktiv → config.toml + Redeploy (Schritt A).

### Schritt C — Cron auf daily 13:00 Berlin umstellen
- **Wo:** SQL-Console. **Voraussetzung:** Schritt A+B fertig.
- **Befehl:**
  ```sql
  SELECT cron.unschedule('tracking-poll-4h');   -- "could not find" ignorieren
  SELECT cron.schedule('tracking-poll-daily', '0 11,12 * * *', $$
    SELECT net.http_post(
      url := 'https://<PROJECT_REF>.functions.supabase.co/tracking-poll',
      headers := jsonb_build_object('Authorization','Bearer <CRON_SECRET>','Content-Type','application/json'),
      body := jsonb_build_object('mode','daily-sweep','target_berlin_hours', jsonb_build_array(13)),
      timeout_milliseconds := 110000);
  $$);
  ```
- **Erfolg:** `SELECT jobname,schedule FROM cron.job WHERE jobname='tracking-poll-daily';`
  → eine Row `0 11,12 * * *`; `tracking-poll-4h` → 0 Rows. Nach dem nächsten
  11/12-UTC-Tick: `cron.job_run_details` → `succeeded`; Off-Hour-Tick gibt
  `{skipped:'off-hour'}`, der 13-Uhr-Berlin-Tick fährt den Sweep.
- **Fehler:** Alle Ticks `skipped:'off-hour'` → `target_berlin_hours`-Mismatch /
  `berlinHourNow()` falsch (Edge-Fn-Log `berlin_hour` prüfen).

> Danach `SETUP.md` aktualisieren (§4 ersetzen, Trigger-Config + verify_jwt +
> `net._http_response`-Reaper dokumentieren).

---

## 8. Rollout-Reihenfolge

1. `deno test --allow-read supabase/functions/_shared/` — Checksum + VAT-Reject +
   Detektor isoliert (kein DB). Gate §6 hier zuerst grün.
2. `deno test --allow-read supabase/functions/tracking-poll/ …/inbox-parse/` —
   Guard/Eligibility/Trigger-Pure-Tests.
3. `supabase db reset` lokal grün (Migrationen).
4. **Re-Parse-Dry-Run** über bestehende gespeicherte Mails: alt-vs-neu-Diff der
   Tracking-Zuweisung. Erwartung: VAT/IBAN-Falsch-Positive entfernt (>0 Opfer
   bereinigt), neue valide DHL/Amazon/DPD-Trackings, **0** neue Falsch-Positive.
5. `supabase db push` + Edge-Deploy + Setup-Schritte A–C.
6. Settings „Sendungsnummern neu prüfen" auf Dev-Workspace; verifizieren: kein
   Deal mit `tracking ~ '^[A-Z]{2}\d{9}$'`, kein `live_status` für Amazon-only.
7. `/test-ui smoke-full-app-audit` (Phone 390×844 zuerst).

---

## 9. Risiken & offene Entscheidungen

| # | Thema | Entscheidung |
|---|---|---|
| R1 | **Freshness vs. User-Spec.** Nur 13:00/Tag = ~6× weniger Zwischenstatus-Updates ggü. altem 4h-Cron. | Default: User-Spec (nur 13:00) + Event-Trigger bei Zuweisung. **Opt-in:** zusätzlicher 19:00-Sweep (Cron `0 11,12,17,18`, Target `[13,19]`). → **Stakeholder bestätigen.** |
| R2 | **`verify_jwt`** muss für tracking-poll aus sein (sonst 401 am Trigger). | `supabase/config.toml` (nur tracking-poll) + Smoke auf `net._http_response` 200. Harter Prereq. App-interne Auth (isCron/JWT-403) bleibt intakt — kein Bypass (Security bestätigt). |
| R3 | **Legacy-Deals ohne `carrier`.** Fallback `detectAdapter` kann DPD-nicht-`05` fälschlich auf DHL routen. | Backfill via Re-Detection; >30d ohne Body → Heuristik/needs_review, nie still NULL (T8). |
| R4 | **DPD-Checksum unverifiziert** für bare 14-stellige Kundennummer. | NICHT auf Checksum gaten; nur URL/Anchor. Bei echten Samples nachschärfen (jkeen-Spec refreshen). |
| R5 | **Amazon track.amazon-Pfad** evtl. opake Tokens statt TBA. | href als Amazon-Kontext-Signal; Nummer nur bei `TB[ACM]\d{12}`, sonst „erkannt, Tracking unbekannt". An echten Samples verifizieren (Critique C1-#8). |
| R6 | **`net._http_request`/`_http_response`** wachsen unbegrenzt + halten CRON_SECRET im Klartext. | Enger Reaper (≤24h, idealerweise <1h) für **beide** Tabellen (Migration §4). |
| R7 **`[Council-Fix]`** | **Trigger statt in-process?** Architekt: viel Infra (pg_net, Vault, RLS, Reaper) für primär den manuellen Dialog-Pfad. | Begründung: Trigger ist der EINZIGE source-agnostische Chokepoint (Inbox+Re-Parse+manuell+künftige Pfade) und umgeht das dokumentierte `verify_jwt`-401-Problem der edge-fn→edge-fn-Service-Calls. In-process würde manuelle Eingabe verfehlen. Bewusst gewählt. |
| R8 **`[Council-Fix]`** | **DHL-Quota unklar** (10M/Tag Code-Kommentar vs. ~1.000/Tag + 3 req/s laut Scout). | Vor Rollout echtes Limit des Public-XML-Endpoints verifizieren; `SPIKE_ARREST`/Batch an 3 req/s anpassen (§3.2). |
| R9 **`[Council-Fix]`** | **DHL mod-10 4/9-Weighting** nicht in `dhl.json`, nur extern hergeleitet. | Gegen ≥3 echte Identcodes gegenchecken (Recall-Risiko, kein FP-Risiko); §11 korrekt als „extern verifiziert" gelabelt. |

---

## 10. Status & Implementierung

**`/council` durchlaufen (2026-06-03)** — Verdict ÜBERARBEITUNG, alle
🔴-Pflicht-Findings sind oben als `[Council-Fix]` eingearbeitet. Implementierung
via `/work` entlang der §5b-Task-Liste:
- `db-migrator` → T1, T5, T6, R6-Reaper (RLS/Vault/REVOKE Pflicht).
- `edge-fn-coder` → T2, T3, T4, T8 (Detection + Verdrahtung + Poller + Backfill).
- `flutter-coder`/`ui-builder` → T7 (Deal.carrier, carrier_service-Fix, Badge,
  Retrack-Disable, l10n).
- `tester` → T9 (Korpora + Gates), `security-reviewer` → T10 (§6 RLS/Secret).
- `help-curator` `/update-help` + `browser-tester` `smoke-full-app-audit` → T11.
- Manuelle Setup-Schritte §7 (A–C) + Re-Parse-Dry-Run → T12 (Stakeholder).

---

## 11. Research-Anhang (verifizierte Fakten — Quelle: Workflow-Agenten 2026-06-03)

**Checksum-Beweise (extern numerisch verifiziert — NICHT alle in `dhl.json`):**
> `[Council-Fix]` Klarstellung (Bug-Hunter #5): `dhl.json` enthält **keine**
> 20-stellige mod-10-3/1- und **keine** 12-stellige mod-10-4/9-Spec. Diese
> Weightings sind **extern** (paketda.de/Wikipedia) verifiziert und werden im
> Detektor **direkt über `_internal.checkMod10`** aufgerufen (nicht über den
> JSON-Validator). Vor Produktiv-Einsatz das 4/9-Identcode-Weighting gegen ≥3
> echte Identcodes gegenchecken (R9; Recall-Risiko, kein FP-Risiko).
- S10 mod-11: `RB123456785DE` (serial 12345678 → 5 ✓), `CC473124829DE` (→ 9 ✓);
  Repo-`checkS10`-MAP ≡ `11 − (S mod 11)` über alle 11 Reste (in `s10.json`).
- DHL Identcode mod-10 4/9: `201298452277` (body sum 253 → 7 ✓) — extern.
- DHL 20-stellig mod-10 3/1: `00340433836442636597` (body sum 163 → 7 ✓) — extern.
- DPD mod-37/36: `09980000020034` → `D` ✓ (Repo-`checkMod37_36` matcht dpd.json).

**VAT-Kollisions-Beweis (R4):** Kein DHL/Amazon/DPD-Format hat die Form
`^[A-Z]{2}\d{9}$`. S10 = 2L+9D+**2L** (13 Zeichen). Amazon Intl = 1L+10D.
JJD = 3-4L. Die „looks-like-VAT-but-is-tracking"-Tabelle ist LEER → Reject
provably zerstörungsfrei. `EL`/`EE`-VATs werden vom generischen Reject
mit-erfasst (Superset der User-Regel, weiterhin sicher).

**Falsch-Akzeptanz-Messungen (Critique, 200k Random-Strings):** mod-10 3/1 =
10.02 %, mod-10 4/9 = 10.00 %, S10 = 10.08 % → reine numerische Pattern MÜSSEN
anchor-gated sein. Amazon TBA = keine Checksum → source/anchor-gate.

**DST-Mapping (exhaustiv 2026 inkl. Wechseltage verifiziert):** Cron
`0 11,12 * * *` UTC + Deno-`Intl`-Berlin-Hour-Guard auf `13` → exakt 1 Sweep/Tag
um 13:00 Berlin, kein Doppel-/Null-Feuer.

**Quellen:** UPU S10-Standard; paketda.de (DHL Prüfziffern); ship24/DPD Parcel
Label Spec 2.4.1 (ISO 7064 MOD 37,36); EU-VAT-Formate (Avalara/Wikipedia);
Amazon SP-API/Business-Docs (bestätigt: keine öffentliche Logistics-Status-API).
