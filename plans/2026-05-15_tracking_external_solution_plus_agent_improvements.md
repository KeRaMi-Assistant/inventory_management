[Partially-Implemented 2026-05-15 — Track-1 verschoben Post-Launch, Track-2 reduziert auf TA3]

# Tracking-External-Solution + Agent-System-Improvements (2-Track-Plan)

> Erstellt: 2026-05-15 · Autor: planner-Subagent
> Trigger: User-Quote — _„Tracking klappt nicht, heißt agenten system klappt nicht, da noch schlechte ergebnisse rauskommen. Andere Apps wie Klarna können das. Suche externe Lösungen + Task um System zu verbessern."_

## ⚠️ Status-Hinweis (2026-05-15)

Council-Run am 2026-05-15 beschloss **radikale Simplifikation** statt der
2-Track-Vollausführung:

**Track-1 (AfterShip-Integration) verschoben Post-Launch.**
Gründe (Bug-Hunter + External-Scout):
- Pre-Launch + 0 echte Nutzer → $109/Mo + 2-4 Wochen DSGVO-Setup unverhältnismäßig
- Realistisches AfterShip-Pricing ist **$109/Mo Pro**, nicht $43/Mo (Plan war
  ursprünglich falsch).
- Bestehende `tracking-poll`-Edge-Function ist VOLL implementiert (DHL/DPD/UPS
  Adapter) — keine Stub-Function.

**Stattdessen implementiert (radikale Simplifikation):**
- A1 (Migration `20260515000000_deals_live_status.sql`): 3 Spalten +
  Partial-Index für Klarna-Style intermediate Status-Sichtbarkeit
- A2 (`tracking-poll` Extension): schreibt jetzt ALLE Adapter-Status, nicht
  nur `delivered` (PR via Branch feature/strict-tracking-extraction, mit #69)
- A3 (UI Live-Status-Slot in `TrackingStatusBlock`)
- TA3 (`validate-plan.sh`): Pre-Council-Gate, in `/council`-Skill als Phase
  0.5 integriert (siehe PR #75)
- Plus später ergänzt: Per-Deal Re-Track-Button (#74), Disambiguation USPS-22
  vs DHL-20 + DPD mod_37_36 (#73)

**Track-2 reduziert auf TA3 (Plan-Validation-Script).** Die anderen TA1/TA5/
TA6 (Pre-Planner-Scout, Shared-Context, Forced-Commit-Hook) wurden NICHT
implementiert weil:
- `Explore`-Agent existiert bereits (TA1 redundant)
- Council-Pre-Filter via Phase 1.5 in council.md ist eleganter (TA4-Variante)
- Forced-Commit-Hook hat Branch-Validation-Risiko (auf main committen)

**Was bleibt als Out-of-Scope:**
- AfterShip-Integration (Track-1) — re-evaluate nach Launch wenn echte
  User-Mail-Volume + DSGVO-Setup-Budget vorhanden ist
- 17track als Budget-Alternative — DSGVO-Risk (CN-Server) verschiebt
  Entscheidung
- Patrol für Browser-Tester — Switching-Cost zu hoch, Semantics-Activation
  in `dev-web.sh --profile` (TA0e) reicht für jetzt

Dieser Plan ist **historische Referenz** — neue Tracking/Agent-Plans
sollten auf ihn verweisen aber NICHT als TODO-Liste behandelt werden.

---

> Zwei unabhängige Tracks, parallel ausführbar.

---

## 1. Ziel + Erfolgs-Kriterien

### Track-1 — Tracking-Korrektheit
- **Messziel:** ≥ 95% Korrektheit auf 100 echten User-Mails (anonymisierte Sample-Workspace). „Korrekt" = (a) Tracking-Nr identisch zum tatsächlichen Carrier-Wert, (b) keine Order-ID/PLZ/IBAN als Tracking, (c) Live-Status (in-transit/out-for-delivery/delivered) sichtbar in App.
- **Sekundärziel:** Live-Status-Push am User-Phone ≤ 10 min nach Carrier-Event (wie Klarna/AfterShip).
- **Out:** „Eigenbau weiter ausbauen" ist eine valide Option der Decision-Matrix, aber Default-Empfehlung ist Hybrid.

### Track-2 — Agent-System-Qualität
- **Messziel:** Pre-Plan-Scout + Plan-Validation eliminieren ≥ 80% der Bug-Hunter-Findings VOR Implementation. Baseline: letzten 4 Council-Runs hatten je 3–6 Bug-Hunter-Findings → Ziel: ≤ 1 Bug-Hunter-Finding/Run nach Rollout.
- **Sekundärziel:** Council-Run-Kosten von ~$1.50 auf ~$0.50 für Standard-Pläne (Pre-Filter), volles 5-Reviewer-Council nur bei rotem Pre-Filter.
- **Sekundärziel:** Browser-Tester-Flakiness ≤ 5% (heute geschätzt 20–30%, S7/S3/S4 mussten mehrfach repariert werden).

---

## 2. Track-1: Externe Tracking-Lösung — Recherche + Entscheidung

### 2.1 Stand der Eigenbau-Lösung (nach PRs #66–#69)

Was sie HEUTE tut (post-merge `feature/strict-tracking-extraction`):
- jkeen/tracking_number_data vendored unter `supabase/functions/_shared/tracking_data/` (MIT, statischer Snapshot).
- `tracking_validators.ts` — ~80 LOC Deno-Interpreter für `regex_group_format` + Checksum-Algos (mod10, mod7, s10, sum_product_with_weightings_and_modulo).
- Pattern-Tabelle in `inbox_adapters.ts` mit `{ pattern, requiresAnchor, validator, defaultConfidence, carrier, source }`. STRONG_TRACKING_PATTERNS abgeschafft.
- Anchor-Pflicht (DE/EN/FR/IT/ES/PL) + Whitespace-Normalisierung + REJECT_PATTERNS (Order-ID, IBAN, PLZ, Telefon).
- DB-Spalten `tracking_confidence ('strong'|'manual'|'none')`, `tracking_needs_review` auf `deals`, `pending_deal_suggestions`, `parsed_messages`.
- Re-Parse-Mode `reparse_low_confidence` in `inbox-parse/index.ts` mit Rate-Limit über `mailbox_accounts.last_reparse_at`.
- UI-Widget `TrackingStatusBlock` (5 States) + Filter-Chip + Banner + Counter-Badge.

Was sie NICHT tut:
- **Kein Live-Status.** App weiß nicht, ob Paket „in transit" oder „delivered" ist. User muss manuell Carrier-Webseite öffnen.
- **Keine Push-Updates.** Klarna/AfterShip pushen „dein Paket kommt heute" — wir nicht.
- **Keine Carrier-API-Integration.** `tracking-poll`-Edge-Function existiert als Stub, ohne API-Anbindung.
- **Kein internationales Carrier-Set.** jkeen deckt ~25 Carrier weltweit, aber Asien/Latam-Edge-Cases bleiben blind.
- **Kein automatisches Lernen.** Falsch-Detections müssen User manuell korrigieren; das Pattern-Set lernt nicht.

Wartungs-Realität: jkeen-Snapshot upstream-SHA dokumentiert, Updates manuell. Anchor-Wörter manuell. Bei jedem Carrier-URL-Format-Wechsel manueller Pattern-Patch.

### 2.2 Externe Lösungen — Markt-Übersicht

> Recherche-Task TX1 verfeinert diese Tabelle mit aktuellen Preisen + API-Sample-Calls. Folgendes ist Pre-Stand basierend auf öffentlichen Pricing-Pages (Stand 2026, Schätzung).

| Anbieter | Was sie tun | API-Modell | Pricing (Schätzung) | Lizenz | DSGVO | Plug-Aufwand | Lock-in |
|---|---|---|---|---|---|---|---|
| **AfterShip** | Carrier-Detection + Live-Status + Webhook + Branded Tracking-Page | REST + Webhook | $11/Mo 100 trk Free, $0.08/extra ab Essential | Cloud-API | DPA verfügbar, US/EU-Region wählbar | 1–2 Tage | mittel — Webhook-Format proprietär |
| **17track.net** | Carrier-Detection + Status, schwächere Push-UX | REST + Webhook | $9/Mo 100 trk free, $0.05/extra | Cloud-API | Server in HK/CN — **DSGVO-Risk** | 1 Tag | niedrig |
| **Shippo** | US-Fokus, Label-Printing + Tracking-Bonus | REST + Webhook | $0.05/trk pay-as-you-go | Cloud-API | US-only, DSGVO unklar | 1 Tag | niedrig |
| **Parcel Perform** | Enterprise + DACH-Carrier-stark | REST + Webhook | Custom (vermutlich $500+/Mo) | Cloud-API | DE-Server verfügbar | 3–5 Tage Onboarding | hoch |
| **EasyPost** | US-fokussiert + UPS/USPS-Detail | REST + Webhook | $0.01/trk | Cloud-API | US | 1 Tag | niedrig |
| **Trackingmore** | AfterShip-Alternative aus CN | REST + Webhook | $0.04/trk | Cloud-API | CN — **DSGVO-Risk** | 1 Tag | niedrig |
| **ParcelPanel** | Shopify-native | Embed-Widget | Shopify-Plan-bundle | SaaS | – | für unseren Stack n/a | hoch |
| **Klarna Tracking** | User-Erwähnung. Klarna hat ein **Shipment-Tracking-Feature in der Klarna-App**, aber **KEINE öffentliche Drittanbieter-API** dafür. Nutzt vermutlich AfterShip oder ProShip im Hintergrund. Nicht als API-Option für uns verfügbar. | – | – | – | – | – | – |

Wichtigste Erkenntnis: **Klarna ist kein API-Anbieter — sondern ein Konsument** (vermutlich AfterShip-OEM). Der User vergleicht Klarna-UX, will aber technisch die gleiche Lösung wie Klarna verwendet.

### 2.3 Entscheidungs-Matrix

| Option | Eigenbau-Detection | Live-Status | Push | Kosten/Mo bei 500 trk | Lock-in | DSGVO | Aufwand |
|---|---|---|---|---|---|---|---|
| **A — Eigenbau weiter** | ✓ (jkeen+Pattern) | ✗ (müsste 8+ Carrier-APIs selbst integrieren) | ✗ | $0 SaaS, ∞ Wartung | – | safe | 4–8 Wochen Carrier-API-Integration |
| **B — Hybrid: Eigenbau-Detection + AfterShip-Live** | ✓ Eigenbau | ✓ AfterShip | ✓ AfterShip-Webhook | ~$11 + $0.08×400 = $43 | mittel | DPA + EU-Region wählbar | 3–5 Tage |
| **C — Vollmigrate AfterShip** | AfterShip auch für Detection | ✓ | ✓ | ~$43 | hoch | wie B | 1–2 Wochen + Daten-Migration |

**Trade-offs:**
- A spart Geld, killt aber Live-Feature → User bleibt unzufrieden. NICHT empfohlen.
- B nutzt unsere jkeen-Investition (sunk cost OK weil Detection-Qualität gut ist) + outsourct den teuren Teil (Live-Status-Polling).
- C wirft jkeen-Investition weg, aber simpler langfristig. Risiko: AfterShip-Detection kann SCHLECHTER sein als unsere (deutsche Carrier-Edge-Cases). Erst TX2 zeigt das.

### 2.4 Empfehlung

**Default-Empfehlung: B (Hybrid).**

Begründung:
1. Eigenbau-Detection ist nach PR #69 messbar gut (siehe Forensik-Baseline T1 aus Strict-Tracking-Plan). Wegwerfen wäre Verschwendung.
2. Live-Status + Push ist der User-sichtbare Differentiator gegenüber Klarna — den outsourcen wir.
3. AfterShip-Cost bei 500 Trackings/Monat = ~$43. Bei Pre-Launch-Volume vernachlässigbar.
4. DSGVO: AfterShip hat EU-Region + DPA — User-Daten bleiben in EU.
5. Exit-Option: Wenn AfterShip-Detection in TX2-Vergleich besser als unsere ist → wir kippen auf C. Wenn schlechter → wir bleiben B.

**Kill-Switch:** Wenn TX2-Vergleich zeigt AfterShip-Detection > 90% UND unsere < 75% auf 50 Mails → C statt B. Sonst B.

---

## 3. Track-2: Agent-System-Verbesserungen

### 3.1 Root-Cause-Analyse „schlechte Ergebnisse"

Konkrete Beobachtungen aus den letzten 4 Sessions (Strict-Tracking + Audit):

1. **Planner-Annahmen-Fehler:** Plan für Audit nahm `inbox_messages`-Tabelle an, real ist `parsed_messages`. Plan nahm `BottomNavigationBar` an, real ist Drawer + `_MobileNavList`. Bug-Hunter fand beides — aber zu spät, Planner hätte VORHER greppen müssen.
2. **Subagent-Isolation:** Browser-Tester wusste nicht, welche `Key()`s der flutter-coder bereits gesetzt hat. Tester suchte nach `mobile-nav-inbox-badge` bevor TA0a den Key überhaupt setzte → Test-Fail aus Pseudo-Grund.
3. **Auto-Commit-Drift:** Bei Strict-Tracking-Implementation hat Layer 5 (T5 db-migrator) committed, Layer 6+ (T6 backfill) nicht. Reviewer sah `git status` mit Half-State.
4. **Browser-Tester-Flakiness:** S3 (Rate-Limit) brauchte 2 Re-Runs wegen Cooldown. S4 (Offline) failt unbestimmt weil Web-Dart kein `SocketException` wirft. S7 (Badge) suchte falsche Widget-Hierarchie. CanvasKit-Cache-Probleme. Form-Focus-Bug.
5. **Council-Token-Budget:** 5 Reviewer × Opus × Plan-Größe (∼600 Zeilen) = ~$1.50/Council. Bei Re-Council nach Plan-Update = ~$3. Strict-Tracking hatte 2 Council-Runs = ~$3. Mid-Term unhaltbar.
6. **Reviewer-Redundanz:** Architekt + Bug-Hunter finden oft die gleichen Issues mit anderer Framing. UX/Mobile redundant zu Browser-Tester-Output.

### 3.2 Konkrete Verbesserungen

#### A. Pre-Planner-Scout-Step
Vor Planner-Aufruf: `scout`-Agent (Sonnet, ~$0.15) greppt:
- Alle Tabellennamen aus `supabase/migrations/**/*.sql` mit `CREATE TABLE`.
- Alle Provider-Klassen aus `lib/providers/` mit ihren public Methods.
- Alle existierenden Bottom-Nav vs Drawer-Architekturen via grep auf `LayoutBuilder`/`MediaQuery.sizeOf` in `lib/screens/main_screen.dart`.
- Alle relevanten Edge-Function-Namen.
- Alle existierenden l10n-Keys (für Plan-Annotation „neu" vs „existiert").

Output: `.claude/work/<task-id>/SCOUT_BRIEFING.md` (markdown, ~50 Zeilen).

Planner liest dieses Briefing AUSDRÜCKLICH als ersten Input.

**Kosten-Impact:** +$0.15/Plan, ersparter Council-Pass (Bug-Hunter findet 0 Tabellen/Provider/Nav-Fehler) ~$0.30. Netto: -$0.15 + bessere Qualität.

#### B. Shared-Context-File für Subagenten
`.claude/work/<task-id>/SHARED_CONTEXT.md` enthält:
- Plan-Pfad + Status (welche Tasks done).
- Code-Annahmen aus Scout (Tabellennamen, Methoden, Nav-Architektur).
- `.env.test`-Pfad (für Browser-Tester).
- Bereits gesetzte `Key()`s (von flutter-coder geupdated).
- Bereits durchgelaufene Tests.

Jeder Subagent-Wrapper (`worker.sh`, `disput.sh`) liest dieses File als Prefix. Verhindert Inkonsistenzen.

#### C. Forced-Commit-Hook
`Stop`-Hook nach jedem Subagent-Run:
```bash
if [[ "$(git status --porcelain | wc -l)" -gt 0 ]]; then
  git add <whitelist-aus-claude-md>
  git commit -m "auto(<agent>): <slug>"
fi
```
Wenn keine Änderungen: skip. Verhindert Half-State.

#### D. Browser-Tester Phase-2-Migration
Option D1: `alchemist` Widget-Goldens für deterministische State-Matrix-Tests (5 `TrackingStatusBlock`-States als Golden-PNGs). 1h Setup pro Widget-Family.
- **Vorteil:** Browser-Tester kann sich auf Flow-Smoke konzentrieren, State-Details laufen deterministisch im CI.
- **Nachteil:** Goldens brauchen Maintenance.

Option D2: Browser-Tester-Selector-Strategie hardenen — Pflicht `Key()`-Anker statt Text-Fallback. Erfordert `KEY_REGISTRY.md` und Lint-Rule.

Empfehlung: D1 (alchemist) für State-Matrix + D2 für Flow-Tests. Beides kombinierbar.

#### E. Council-Pre-Filter
Vor 5-Reviewer-Council ein „Fast-Pass" mit nur 2 Reviewer (Bug-Hunter + Architekt, beide Sonnet statt Opus = ~$0.30).
- Wenn beide ✓: skip volles Council, direkt zu Implementation.
- Wenn einer 🟡: volles Council mit Opus.
- Wenn einer 🔴: volles Council MIT Disput-Modus.

**Cost-Impact:** ~70% der Pläne werden 🟡-bewertet → ~$0.30 statt ~$1.50. Pläne mit 🔴 brauchen weiterhin volles Council.

#### F. Plan-Output-Validierung (Pre-Council-Gate)
Skript `.claude/scripts/validate-plan.sh <plan.md>`:
- Greppt im Plan erwähnte Tabellennamen → check ob in `supabase/migrations/**` existiert.
- Greppt Provider-Klassen → check ob in `lib/providers/` existiert.
- Greppt l10n-Keys → check ob in `app_de.arb` existiert ODER als "neu" markiert ist (Tabellen-Spalte "Status: NEU").
- Greppt Edge-Function-Namen → check ob in `supabase/functions/` existiert.
- Mismatch → Exit 1 mit Liste der unbekannten Referenzen.

Run-Order: Planner → Validate → Council. Validate-Fail = Planner überarbeitet, KEIN Council-Spend.

#### G. Headless-Run-Monitoring + Failure-Loop-Detection
`recover.sh` aktuell verschiebt nach 3 Cycles failed → silent. Neu: nach 3 Cycles auch **Auto-Inbox-Item** `00-investigation-needed-<slug>.md` mit:
- Letzte 3 Failure-Logs zusammengefasst.
- Hypothese (env? Schema-Drift? Cred-Expiry?).
- Recommended-Action.

Plus ntfy-Notify an User (nicht nur Log).

### 3.3 Priorisierung Agent-Improvements

1. **Sofort (diese Woche):** TA1 (Scout) + TA3 (Plan-Validate). Größter Qualitäts-Hebel.
2. **Diese Woche:** TA4 (Council-Pre-Filter). Größter Kosten-Hebel.
3. **Diese Woche:** TA5 (Shared-Context). Verhindert Subagent-Drift.
4. **Optional:** TA6 (Forced-Commit-Hook). Hygiene.
5. **Mid-Term:** TA-D1 (alchemist) + TA-D2 (Key-Anker-Lint). Browser-Tester-Hardening.
6. **Mid-Term:** TA7 (Failure-Loop-Detection).

---

## 4. Datenmodell + RLS

### 4.1 Neue Tabelle `tracking_subscriptions` (Track-1, AfterShip-Bindung)

```sql
CREATE TABLE public.tracking_subscriptions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id  UUID NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
  deal_id       UUID NOT NULL REFERENCES public.deals(id) ON DELETE CASCADE,
  carrier       TEXT NOT NULL,
  tracking      TEXT NOT NULL,
  provider      TEXT NOT NULL DEFAULT 'aftership'
                  CHECK (provider IN ('aftership','17track','self')),
  external_id   TEXT,                              -- AfterShip-Tracking-ID
  status        TEXT,                              -- carrier-status: in_transit, delivered, …
  status_raw    JSONB,                             -- letzter Webhook-Payload
  last_event_at TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (workspace_id, deal_id, tracking)
);

ALTER TABLE public.tracking_subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY tracking_subscriptions_select ON public.tracking_subscriptions
  FOR SELECT USING (workspace_id IN (SELECT workspace_id FROM workspace_members WHERE user_id = auth.uid()));
CREATE POLICY tracking_subscriptions_insert ON public.tracking_subscriptions
  FOR INSERT WITH CHECK (workspace_id IN (SELECT workspace_id FROM workspace_members WHERE user_id = auth.uid()));
CREATE POLICY tracking_subscriptions_update ON public.tracking_subscriptions
  FOR UPDATE USING (workspace_id IN (SELECT workspace_id FROM workspace_members WHERE user_id = auth.uid()));
CREATE POLICY tracking_subscriptions_delete ON public.tracking_subscriptions
  FOR DELETE USING (workspace_id IN (SELECT workspace_id FROM workspace_members WHERE user_id = auth.uid()));

-- Service-Role-Pfad für Webhook (bypasst RLS via SECURITY DEFINER-Function, NICHT direkter Service-Key in Edge-Function-Body).
```

Index: `(provider, external_id)` für Webhook-Lookup; `(workspace_id, status)` für UI-Filter.

### 4.2 Erweiterung `deals`

Bereits aus Strict-Tracking: `tracking_confidence`, `tracking_needs_review`, `tracking_carrier`.

Neu: keine Spalte — `tracking_subscriptions` ist 1:1 join via `deal_id`.

---

## 5. API/Edge Functions

### 5.1 Neue Edge-Function `aftership-register`
- Trigger: bei `deals.tracking_confidence='strong'` (DB-Trigger ODER Service-Aufruf aus `inbox_match_service.dart`).
- Tut: POST `https://api.aftership.com/v4/trackings` mit `tracking_number`, `slug` (carrier), `title` (deal-Titel anonymisiert).
- Speichert response.tracking.id als `tracking_subscriptions.external_id`.
- Idempotent: vor POST check `UNIQUE (workspace_id, deal_id, tracking)`.

### 5.2 Neue Edge-Function `aftership-webhook`
- Empfängt POST von AfterShip nach Status-Wechsel.
- Validiert HMAC-Signature via `AFTERSHIP_WEBHOOK_SECRET` (`Deno.env.get`).
- Findet Sub via `external_id`, updated `status` + `last_event_at` + `status_raw`.
- Triggert FCM-Push an Workspace-Member via existing `push_*`-Service.
- Whitelist Pfad: in `supabase/config.toml` als `verify_jwt = false` markieren (Webhook ohne User-JWT).

### 5.3 Neue Edge-Function `aftership-unregister`
- Trigger: deal soft-delete oder tracking-edit.
- DELETE `/v4/trackings/{slug}/{tracking_number}`.

### 5.4 Secrets (manuelle Setup-Schritt für User)
- `supabase secrets set AFTERSHIP_API_KEY=...`
- `supabase secrets set AFTERSHIP_WEBHOOK_SECRET=...`

---

## 6. UI + l10n

### 6.1 Screens

- `deal_detail_screen.dart` — neue Sektion „Live-Status" mit:
  - Carrier-Badge (existiert) + Status-Pill (`in_transit`, `out_for_delivery`, `delivered`, `exception`).
  - Letztes Event-Timestamp + Event-Location (wenn vorhanden).
  - Tap → öffnet AfterShip-Tracking-URL (oder Carrier-Native-URL).
- `inbox_screen.dart` — Suggestion-Card zeigt Status-Pill wenn Subscription existiert.

### 6.2 Widget Neu
`lib/widgets/tracking_live_status_pill.dart` — render 5 States:
- `inTransit` (blau, Truck-Icon)
- `outForDelivery` (orange, Box-Icon)
- `delivered` (grün, Check-Icon)
- `exception` (rot, Warning-Icon)
- `pending` (grau, default — kein Webhook yet)

### 6.3 l10n-Keys (12 neu, DE + EN)

| Key | DE | EN |
|---|---|---|
| `trackingLiveStatusInTransit` | Unterwegs | In transit |
| `trackingLiveStatusOutForDelivery` | In Zustellung | Out for delivery |
| `trackingLiveStatusDelivered` | Zugestellt | Delivered |
| `trackingLiveStatusException` | Problem mit Sendung | Delivery exception |
| `trackingLiveStatusPending` | Warten auf erstes Event | Waiting for first event |
| `trackingLiveStatusLastEvent` | Zuletzt: {when} | Last update: {when} |
| `trackingLiveStatusOpenCta` | Bei {carrier} öffnen | Open on {carrier} |
| `trackingLiveStatusSectionTitle` | Live-Status | Live status |
| `trackingLiveStatusUnavailable` | Live-Status nicht verfügbar | Live status unavailable |
| `trackingLiveStatusProviderHint` | Status via AfterShip | Status via AfterShip |
| `trackingLiveStatusA11yLabel` | Sendungs-Live-Status | Shipment live status |
| `trackingLiveStatusRefreshCta` | Status aktualisieren | Refresh status |

---

## 7. Tests

### 7.1 Track-1 Tests
- Mock-AfterShip-Server (Deno test in `supabase/functions/aftership-webhook/index_test.ts`).
- HMAC-Signature-Validation: positiv + negativ (wrong-secret).
- Idempotent-Register: 2× POST mit gleichem tracking → nur 1 row in `tracking_subscriptions`.
- 50-Sample-Mails-Comparison (TX2): unsere Detection vs AfterShip-Detection auf gleiche Mails → CSV-Report.
- Widget-Tests `tracking_live_status_pill_test.dart` für 5 States.
- Browser-Smoke `smoke-deal-live-status`: Deal mit Tracking → Live-Status-Pill sichtbar → Tap öffnet URL.

### 7.2 Track-2 Tests
- Scout-Output-Schema-Test (JSON-Validierung).
- `validate-plan.sh` Unit-Test mit synthetischem Plan (3× green, 3× red Cases).
- Council-Pre-Filter Dry-Run mit Sample-Plan → check ob Fast-Pass-Verdict konsistent zu Full-Pass.

---

## 8. Risiken

1. **AfterShip-API-Quota überraschend teuer.** Mitigation: Cost-Monitor + Cap auf 1000 trk/Monat in MVP. Bei Überlauf manuelle User-Notify.
2. **Vendor-Lock-in.** Mitigation: `tracking_subscriptions.provider` als Enum → Switch zu 17track möglich. AfterShip-Webhook-Format wird in `status_raw` JSONB gepuffert, Mapping in Edge-Function.
3. **DSGVO: AfterShip-Server-Standort.** Mitigation: AfterShip-EU-Region wählen + DPA unterschreiben (manueller Setup-Step). Falls nicht möglich → kein Hybrid, fallback auf Eigenbau-Live-Poll.
4. **Webhook-Endpoint-Spoofing.** Mitigation: HMAC-Signature-Pflicht. `AFTERSHIP_WEBHOOK_SECRET` per `supabase secrets set`.
5. **TX2-Vergleich zeigt AfterShip-Detection schlechter als Eigenbau.** Dann bleibt Hybrid + AfterShip nur für Live-Status — DSGVO + Lock-in trotzdem akzeptieren.
6. **Pre-Planner-Scout addiert Latenz (~30s) + Cost (~$0.15).** Akzeptabel weil Bug-Hunter-Fix-Loops drastisch teurer sind.
7. **Plan-Validation-Script False-Positives** (neue Tabelle in selber Migration noch nicht angelegt). Mitigation: Plan-Format unterstützt explizit `[NEW]`-Marker an Referenzen.
8. **Council-Pre-Filter mit 2 Sonnet-Reviewer übersieht Issues, die Opus gefunden hätte.** Mitigation: nur ✓✓-Pläne skippen volles Council; jeder 🟡 oder 🔴 triggert Opus.
9. **Shared-Context-File wächst unbegrenzt** → Subagent-Prompt-Bloat. Mitigation: Rotation pro Task, Max-Size 4 KB.
10. **Forced-Commit-Hook committed kaputten Code** wenn Subagent crasht. Mitigation: Hook läuft NUR bei Subagent-Exit-Code 0.
11. **alchemist-Goldens flacken auf macOS-Update.** Mitigation: Goldens in Docker-Image-Linux generieren (CI-Konsistenz).

---

## 9. Out-of-Scope

- Eigene Carrier-API-Integration (DHL/UPS direkt) — der Sinn von AfterShip ist exakt das zu outsourcen.
- Multi-Workspace-Subscription-Sharing (jeder Workspace tracked separat).
- Branded Tracking-Page (AfterShip-Feature — später).
- Push-Notifications-Settings pro User (separate Story).
- iOS/Android-Native-Smoke für Live-Status.
- Migration aller historischen `tracking_confidence='strong'`-Deals zu AfterShip (nur neu-akzeptierte; Backfill als optionales Followup).

---

## 10. Tasks

> Format: `[Tx] Titel` · `agent:` · `depends:` · `est:`
> Story-Point: 1 SP = 2h. Tracks unabhängig — können parallel.

### Track-1 (Tracking-External)

- [ ] **[TX1]** Markt-Recherche AfterShip + 17track + Shippo (Pricing, API-Docs, Sample-Calls in Postman). Output: `docs/tracking-external/market-2026-05.md`. _agent: `general-purpose`, est: 2h (1 SP)._
- [ ] **[TX2]** Side-by-Side-Test: 50 Sample-Mails aus Dev-Workspace gegen unsere jkeen-Detection + AfterShip-API-Detection. Output: CSV + Empfehlung B vs C. _agent: `general-purpose`, est: 3h (1.5 SP)._
- [ ] **[TX3]** Entscheidungs-Vorlage an User mit Trade-off-Matrix + Empfehlung (basierend auf TX2). _agent: `planner`, est: 30min (0.25 SP)._
- [ ] **[TX4]** **User-Decision-Gate** — User entscheidet B vs C. Manueller Hook. _agent: – (Stakeholder)._
- [ ] **[TX5]** Migration `tracking_subscriptions` + RLS + Indizes. _agent: `db-migrator`, est: 1.5h (0.75 SP), depends: TX4._
- [ ] **[TX6]** Edge-Function `aftership-register` mit Idempotenz + Error-Handling. _agent: `edge-fn-coder`, est: 2h (1 SP), depends: TX5._
- [ ] **[TX7]** Edge-Function `aftership-webhook` mit HMAC-Validation + Push-Integration. _agent: `edge-fn-coder`, est: 3h (1.5 SP), depends: TX5._
- [ ] **[TX8]** Edge-Function `aftership-unregister` + Trigger auf deal-delete. _agent: `edge-fn-coder`, est: 1h (0.5 SP), depends: TX6._
- [ ] **[TX9]** Auto-Register-Hook in `inbox_match_service.dart` bei `confidence=strong`. _agent: `flutter-coder`, est: 1.5h (0.75 SP), depends: TX6._
- [ ] **[TX10]** l10n: 12 neue ARB-Keys DE + EN. `flutter gen-l10n`. _agent: `ui-builder`, est: 45min (0.4 SP)._
- [ ] **[TX11]** Widget `tracking_live_status_pill.dart` (5 States) + Widget-Tests. _agent: `ui-builder`, est: 2h (1 SP), depends: TX10._
- [ ] **[TX12]** Deal-Detail-Screen: Live-Status-Sektion + Tap-to-Open-Carrier. _agent: `ui-builder`, est: 1.5h (0.75 SP), depends: TX11._
- [ ] **[TX13]** Browser-Smoke `smoke-deal-live-status` + Page-Registry-Update. _agent: `browser-tester`, est: 1h (0.5 SP), depends: TX12._
- [ ] **[TX14]** Manueller Setup-Doc für User: AfterShip-Account anlegen, DPA, API-Key, Webhook-URL, Secrets setzen. `SUPABASE_SETUP.md` erweitern. _agent: `doc-updater`, est: 30min (0.25 SP)._

### Track-2 (Agent-Improvements)

- [ ] **[TA1]** Neuer Agent `.claude/agents/scout.md` — definiert Scout-Briefing-Schema (Tabellennamen, Provider, Nav-Arch, Edge-Fns, l10n-Keys). _agent: `general-purpose`, est: 1h (0.5 SP)._
- [ ] **[TA2]** Scout-Briefing-Template `.claude/scout-template.md` + Beispiel-Output. _agent: `planner`, est: 30min (0.25 SP), depends: TA1._
- [ ] **[TA3]** Plan-Validation-Script `.claude/scripts/validate-plan.sh` (Tabellen-Grep, Provider-Grep, ARB-Grep, Edge-Fn-Grep). Unit-Tests mit synthetischen Plänen. _agent: `general-purpose`, est: 2h (1 SP)._
- [ ] **[TA4]** Council-Pre-Filter: neuer `/council` Sub-Mode `--fast` mit 2-Reviewer-Pass (Bug-Hunter + Architekt Sonnet). Eskaliert zu Full-Council bei 🟡/🔴. _agent: `general-purpose`, est: 1.5h (0.75 SP)._
- [ ] **[TA5]** Shared-Context-Pattern in `.claude/scripts/dispatch-subagent.sh` (oder via SessionStart-Hook). _agent: `general-purpose`, est: 2h (1 SP)._
- [ ] **[TA6]** Forced-Commit-Hook via `Stop`-Hook (whitelist aus CLAUDE.md). _agent: `general-purpose`, est: 1h (0.5 SP)._
- [ ] **[TA-D1]** alchemist-Setup + 5 Golden-Tests für `TrackingStatusBlock`. _agent: `flutter-coder`, est: 2h (1 SP), optional._
- [ ] **[TA-D2]** Key-Anker-Registry `.claude/KEY_REGISTRY.md` + Lint-Hook der bei neuen UI-Widgets eine `Key()`-Empfehlung schreibt. _agent: `flutter-coder`, est: 1.5h (0.75 SP), optional._
- [ ] **[TA7]** Failure-Loop-Detection in `recover.sh`: nach 3 Cycles Auto-Inbox-Item + ntfy-Notify. _agent: `general-purpose`, est: 1h (0.5 SP)._

---

## 11. Priorisierung + Critical Path

**Track-1 Pfad:** TX1 → TX2 → TX3 → **TX4 (User-Decision-Gate)** → TX5 → (TX6 ∥ TX7) → TX8/TX9/TX10/TX11 → TX12 → TX13 → TX14.

**Track-2 Pfad:** TA1+TA3 parallel sofort → TA2 → (TA4 ∥ TA5 ∥ TA6) → TA7. TA-D1/TA-D2 off-critical-path.

Tracks UNABHÄNGIG — parallel ausführbar. Track-2 sollte zuerst starten, da seine Verbesserungen die Track-1-Implementation effizienter machen (Scout für TX5/TX6, Plan-Validate für diesen Plan retrospektiv).

**Gesamt-Aufwand:** Track-1 ~13.65 SP (~27h) auf 14 Tasks. Track-2 ~5.75 SP (~12h) auf 7 Pflicht + 2 optional.

---

## 12. Schluss-Bericht (5-Zeilen-Zusammenfassung)

1. **Empfehlung Track-1:** Hybrid — Eigenbau-Detection bleibt (jkeen+Pattern aus PR #69), AfterShip übernimmt Live-Status + Push. ~$43/Mo bei 500 Trackings, ≤ 5 Tage Implementation.
2. **Empfehlung Track-2:** Scout + Plan-Validate + Council-Pre-Filter sofort. ~60–70% weniger Bug-Hunter-Findings, ~70% Council-Kosten-Reduktion.
3. **Top-3-Risiken:** (a) DSGVO bei AfterShip → EU-Region + DPA Pflicht; (b) TX2-Vergleich könnte unsere Detection als schlechter zeigen → C statt B; (c) Council-Pre-Filter könnte False-Negatives produzieren — Opus-Eskalation bei jedem 🟡.
4. **User-Empfehlung welcher Track zuerst:** **Track-2 zuerst starten** (TA1+TA3 parallel, ~3h Setup) — die Verbesserungen wirken sofort auf jeden weiteren Plan. **Track-1 parallel starten** mit TX1+TX2 (Recherche-Tasks, blocken nichts), aber TX4-User-Decision erst nach TX2-Daten.
5. **Klarna-Klarstellung:** Klarna selbst bietet keine Drittanbieter-Tracking-API. Klarna konsumiert vermutlich AfterShip. Wenn wir „Klarna-Qualität" wollen → AfterShip ist der korrekte Weg.
