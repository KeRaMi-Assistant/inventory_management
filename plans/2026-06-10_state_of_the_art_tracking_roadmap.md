# State-of-the-Art-Roadmap — Tracking-First (2026-06-10)

> Analyse-Basis: 3 parallele Explore-Audits (Tracking-Pipeline very-thorough,
> UI/UX, Feature/Tech-Gaps) + Audit-Roadmap-Memory 2026-06-04 + Code-Verify.
> Vision des Stakeholders: **State-of-the-Art-App** — Klarna-Style-Tracking
> über alle Einkäufe hinweg, kombiniert mit Reseller-Warenwirtschaft.
> Das gibt es so am Markt nicht (AfterShip = Shop-seitig, Klarna = nur
> Klarna-Käufe, Parcel-Apps = kein Inventory/Profit-Layer).

## Ist-Zustand (Kurzbefund)

**Solide:** 4-Provider-Decomposition fertig (#120–#131), Nav/IA-Redesign fertig
(#121–#127), Tracking-Rebuild live (#112–#116), RLS workspace-scoped, Detection
mit Confidence-Gating (strong/medium/weak) in 6 Sprachen, 15 Shop-Adapter,
DHL-Polling mit Quota-Schutz, Statistiken mit Export, Cmd+K-Suche, Push via FCM.

**Tracking-Lücken (Kern des Plans):**

| Lücke | Beleg |
|---|---|
| Keine Event-Historie — nur `deals.live_status` + 1 Event-Text | `supabase/migrations/20260515000000_deals_live_status.sql`; keine `tracking_events`-Tabelle |
| Nur DHL live gepollt | `lib/models/carrier_credential.dart:49` `enabledCarrierIds = {'dhl'}`; `supportedCarrierIds` = dhl/dpd/ups (Z. 42) |
| GLS fehlt komplett (Detection UND Polling) | `.claude/exampleHtmlMail/pccomponentesGls.txt` enthält GLS-Nr. `11766771249246689455`, kein Pattern matcht; `tracking_adapters.ts` `detectAdapter` kennt kein GLS |
| upsAdapter toter Code | `detectAdapter` liefert für `1Z…` null (bewusst Plan 2026-06-03 §3.4) |
| Carrier 3-fach inkonsistent modelliert | `tracking_detection.ts` (dhl/amazon/dpd) vs. `tracking_adapters.ts` (dhl/dpd/ups) vs. `carrier_credential.dart` (2 Sets) |
| Poll-Frequenz: 1× täglich (Cron `0 11,12 * * *` UTC + Event-Trigger bei Zuweisung) | Provisioning-Migration #113; DHL-Quota 1.000/Tag erlaubt deutlich mehr |
| Kein Push bei Status-Wechsel | tracking-poll schreibt nur DB; send-notifications kennt keinen Status-Change-Typ |
| Kein Carrier-Deep-Link, keine ETA-Anzeige im Tracking-Block | `lib/widgets/tracking_status_block.dart` |
| Trackings mit internen Leerzeichen: Erkennungs-/Persistenz-Pfad unklar | `tracking_detection.ts` normalizeToken vs. rawValue-Persistenz |
| Re-Parse kann falsch zugewiesenes Tracking nicht korrigieren | Roadmap-Rest Audit 2026-06-04 |
| Multi-Parcel: `trackings[]` existiert, UI zeigt nur eins | `tracking_status_block.dart` |

**Sonstige Lücken:** Mail nur IMAP (kein Gmail-OAuth → 2FA-Friction), Billing =
Stub (bewusst, Pre-Launch), Deal-Tabelle ohne Suchfeld/Bulk-Aktionen, Push-Taps
ohne Deep-Link-Routing, Desktop-Deal-Tabelle nicht virtualisiert,
Widget-Test-Coverage dünn.

**Stale-Hinweis:** `.claude/backlog/inbox/00-amazon-tracking-coverage-70pct.md`
(Prio 0, vom 2026-05-09) ist durch #116 (DE-Prefix-STRONG-Pattern) vermutlich
weitgehend erledigt — Coverage einmal live re-messen, dann Item schließen oder
re-scopen, bevor der Overseer es teuer abarbeitet.

---

## Paket 1 — Tracking-Kern: Klarna-Style Event-Timeline (P0)

Das Differenzierungs-Feature. Reihenfolge innerhalb des Pakets = Abhängigkeit.

### 1.1 `tracking_events`-Tabelle [NEW]
- Migration: `tracking_events` [NEW] (deal_id FK, workspace_id, occurred_at,
  status_normalized, raw_carrier_code, description, location, source
  `poll|mail|manual` [NEW]) + RLS workspace-scoped (Muster
  `20260504000500_data_workspace_scope.sql`) + Index `(deal_id, occurred_at desc)`.
- Dedup-Constraint (deal_id, occurred_at, description) gegen Doppel-Inserts
  bei jedem Poll.

### 1.2 tracking-poll persistiert Events
- DHL-Adapter liefert bereits Event-Listen vom Carrier — aktuell wird nur das
  letzte Event in `live_status_last_event` geschrieben. Neu: kompletten
  Event-Array upserten (idempotent), `live_status` bleibt als Aggregat-Spalte
  für Listen-Badges (kein UI-Bruch).

### 1.3 Timeline-Widget (Klarna-Style)
- Neues Widget `tracking_timeline.dart` [NEW] im Deal-Detail unterhalb des
  bestehenden `tracking_status_block.dart`: vertikaler Stepper
  (Bestellt → Versendet → Im Paketzentrum → In Zustellung → Zugestellt),
  echte Events mit Zeit/Ort, aktiver Schritt animiert/farbig
  (`AppTheme`-Tokens), Exception-State rot mit Klartext.
- Mobile-First: 390×844 zuerst; ARB-Keys DE+EN.

### 1.4 Push bei Status-Wechsel
- tracking-poll erkennt `live_status`-Übergang (alt ≠ neu) → Notification-Row
  (ref_kind `tracking_status` [NEW]) → send-notifications pusht sofort
  („Dein Paket ist in Zustellung 📦"). Kein PII im Payload (nur Deal-ID +
  generischer Text), Deep-Link-Route im Data-Payload.
- Settings: Toggle in Push-Preferences (bestehende Preference-Struktur).

### 1.5 Adaptive Poll-Frequenz
- Cron von 1×/Tag auf stündlich stellen; In-Function-Gating nach Status:
  `out_for_delivery` jede Stunde, `in_transit` alle 4 h, `pending` 2×/Tag,
  `delivered/expired` nie. Quota-Wächter: harter Tages-Cap pro Carrier
  (DHL 1.000/Tag, 3 req/s — Throttle existiert schon in `pollWorkspace`).

### 1.6 ETA + Carrier-Link + Copy
- DHL Parcel-DE-Tracking liefert geschätztes Zustellfenster → Spalte
  `deals.live_eta` [NEW] + Anzeige „Kommt heute, 14–17 Uhr" im Block und als
  Chip in der Deal-Tabelle.
- Carrier-URL-Generator (dhl/dpd/gls/ups/amazon) + Copy-Button für die
  Tracking-Nummer im `tracking_status_block.dart`.

**touches:** `supabase/migrations/` (2 neue), `supabase/functions/tracking-poll/index.ts`,
`supabase/functions/_shared/tracking_adapters.ts`,
`supabase/functions/send-notifications/index.ts`, `lib/widgets/tracking_status_block.dart`,
`lib/widgets/tracking_timeline.dart` [NEW], `lib/providers/deals_provider.dart`,
`lib/services/push_service.dart`, `lib/l10n/app_de.arb`, `lib/l10n/app_en.arb`.

**Aufwand:** ~3–4 Worker-Tage. **User-Aktion:** keine (DHL-Key existiert).

---

## Paket 2 — Carrier-Breite + Konsistenz (P1)

### 2.1 Kanonische Carrier-Registry
- EINE Quelle: `supabase/functions/_shared/carriers.ts` [NEW] (id, displayName,
  trackingUrlTemplate, Detection-Patterns-Ref, hasPollAdapter, enabled) +
  Dart-Pendant `lib/models/carriers.dart` [NEW]; Konsistenz-Test (deno) der
  beide Listen vergleicht. Beseitigt die 3-fach-Inkonsistenz und macht
  upsAdapter-Status explizit.

### 2.2 GLS-Support
- Detection: GLS-Pattern (11–14-stellig + Anchor „GLS"/„seguimiento") in
  `tracking_detection.ts` ergänzen, gegen `pccomponentesGls.txt` als
  Real-Fixture testen (Lesson #116: echte Maildaten > Research-Annahmen).
  `CARRIER_DOMAINS`-Blocking für GLS-Mails überdenken (aktuell werden
  GLS-Carrier-Mails komplett ignoriert).
- Polling: GLS hat keinen offiziellen freien Track-API-Zugang — Recherche-Task:
  inoffizieller JSON-Endpoint der GLS-Trackingseite vs. nur Deep-Link.
  Fallback (immer machbar): Detection + Carrier-Link, `live_status` bleibt
  mail-getrieben (Versand-/Zustell-Mails setzen Status).
### 2.3 DPD aktivieren
- Adapter existiert (`dpdAdapter`), nur `enabledCarrierIds` blockt die UI.
  Aktivieren + Settings-UI für DPD-Key. **User-Aktion:** DPD-API-Key beantragen.
### 2.4 UPS entscheiden
- Entweder Poll-Pfad anschließen (1Z-Pattern in detectAdapter) oder Adapter
  löschen (Dead-Code). Empfehlung: löschen bis UPS-Key existiert, Registry
  markiert ihn als `detection-only`.
### 2.5 Roadmap-Reste Tracking-Robustheit
- Leerzeichen-Trackings: Persistenz auf normalisierten Wert vereinheitlichen +
  Test; Re-Parse-Korrektur: Re-Parse darf bestehendes `tracking` ersetzen,
  wenn neuer Kandidat strictly-stronger Confidence hat.
### 2.6 Multi-Parcel-UI
- `trackings[]` als Liste im Deal-Detail (je Eintrag eigener Status-Block),
  Badge in Tabelle zeigt „2 Pakete".

**touches:** `supabase/functions/_shared/` (detection/adapters/carriers [NEW]),
`lib/models/carrier_credential.dart`, `lib/screens/settings_screen.dart`,
`supabase/functions/tracking-poll/index.ts`, Tests (deno + flutter).

**Aufwand:** ~3 Worker-Tage. **User-Aktion:** DPD-Key (optional), GLS-Entscheid
nach Recherche-Ergebnis.

---

## Paket 3 — UX-Quick-Wins (P1, parallelisierbar zu Paket 2)

1. **Deal-Schnellsuche + Filterleiste** über `deal_table.dart` (heute nur Cmd+K).
2. **Inline-live_status-Badge** in der Tracking-Spalte der Deal-Tabelle
   (farbcodierter Dot + Carrier-Icon statt nackter Nummer).
3. **Bulk-Aktionen** — Checkbox-Spalte existiert schon ohne Funktion:
   Multi-Select → Status setzen / löschen (mit Confirm) / CSV-Export.
4. **KPI-Drilldowns**: Dashboard-KPI-Tap → Statistik-Tab mit Pre-Filter.
5. **Push-Deep-Links**: FCM-Data-Payload `route` → Tap landet auf Deal-Detail
   bzw. Inventory-Low-Stock-Filter (heute: App öffnet nur).
6. **Pull-to-Refresh** auf Deals/Inventory (Inbox hat es schon).
7. **Bestand pro Lager inline** im Inventory (expandierbare Zeile statt Klick
   in ProductDetail).

**touches:** `lib/widgets/deal_table.dart`, `lib/screens/dashboard_screen.dart`,
`lib/screens/inventory_screen.dart`, `lib/services/push_service.dart`,
`lib/main.dart` (Route-Handling), ARBs.

**Aufwand:** ~2–3 Worker-Tage gesamt; jedes Item einzeln ship-bar.
**Pflicht:** smoke-full-app-audit vor jedem Ship (UI-Änderungen).

---

## Paket 4 — Funktionale Lücken (P2)

1. **Gmail-OAuth fürs Postfach** (statt IMAP-App-Passwort): größter
   Onboarding-Friction-Killer. Edge-Function-OAuth-Flow + Token-Refresh in
   `inbox-poll`. **User-Aktion:** Google-Cloud-OAuth-Client anlegen (ich
   liefere Schritt-für-Schritt-Anleitung). ~3–5 Tage.
2. **Billing**: bleibt bewusst Stub bis Launch-Entscheidung
   (Stripe vs. RevenueCat) — reine Stakeholder-Entscheidung, kein Code jetzt.
3. **Desktop-Deal-Tabelle virtualisieren**: erst bei >1k Deals relevant —
   post-launch.
4. **Widget-Tests Critical-Path** (Deal anlegen → Tracking → Status): nach
   Paket 1, damit die neuen Tracking-Flows abgedeckt sind.
5. **Security-Hygiene-Reste** (Audit): CRON_SECRET/Tracking-Nr-Redaction in
   Logs, Push-PII — kleines Sammel-PR.

---

## Was ich selbst umsetzen kann vs. User-Aktionen

**Ich (autonom, via flutter-coder/ui-builder/db-migrator/edge-fn-coder):**
alle Migrations, tracking-poll-Erweiterung, Timeline-UI, Push-Trigger,
Carrier-Registry, GLS-Detection (gegen Real-Fixture getestet), alle
UX-Quick-Wins, Deep-Links, Tests, l10n DE+EN, Doku/Hilfe-Sync.

**User-Aktionen (jeweils 1 Schritt, Anleitung liefere ich):**
- DPD-API-Key beantragen (nur für DPD-Live-Polling).
- Google-OAuth-Client (nur für Paket 4.1).
- Billing-Anbieter-Entscheidung (irgendwann vor Launch).

## Empfohlene Reihenfolge

1. **Paket 1** komplett (Timeline + Push + adaptive Polls + ETA) — das ist das
   „sowas gibt es nicht am Markt"-Feature.
2. **Paket 3** Quick-Wins parallel/danach (jedes einzeln ship-bar).
3. **Paket 2** Carrier-Breite (GLS-Recherche früh starten, Rest danach).
4. **Paket 4.1** Gmail-OAuth vor Launch; Rest post-launch.

Plus sofort (5 min): Stale-Backlog-Item `00-amazon-tracking-coverage-70pct`
re-verifizieren/schließen, damit der Overseer keine veraltete Prio-0-Task zieht.

## Risiken

- **DHL-Quota** bei adaptiver Frequenz: Tages-Cap-Guard ist Pflichtteil von 1.5,
  sonst 429-Sperre (Lesson #115).
- **GLS-Polling** evtl. nur über inoffiziellen Endpoint → als optional/Fallback
  designen, nie als Kern-Abhängigkeit.
- **Event-Dedup**: ohne Unique-Constraint wächst `tracking_events` bei jedem
  Poll — Constraint ist Teil von 1.1, nicht nachgelagert.
- **Push-Spam**: nur bei echtem Status-Übergang pushen, nie bei jedem Poll.
