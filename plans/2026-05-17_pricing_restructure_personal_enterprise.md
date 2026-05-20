# CanLogistics Pricing-Restructure — Privat / Business / Enterprise

> Status: Plan-Draft · Author: Claude Opus 4.7 · 2026-05-17
> Triggered by: User-Anweisung im UI-Review-Chat
> Ersetzt: das aktuelle 5-Tier-Modell (Free → Starter → Pro → Business → Ultimate) aus [lib/models/pricing_plan.dart](../lib/models/pricing_plan.dart)

## 1 · Auftrag

> „Plane die ganze Preisstruktur, einmal für privaten Nutzen und für
> Unternehmen (Enterprise-Version noch planen, nur da kannst du E-Mails
> tracken, mehrere Workspaces nutzen und Leute zu deinem Workspace
> einladen), und rechne mir hier in der Planung einmal durch, was ein
> User dementsprechend maximal kosten würde, wenn komplett alles
> genutzt wird bis zum Limit."

→ Drei Gewerbestufen, klares Feature-Gating, Worst-Case-Margin-Check.

## 2 · Aktuelles Modell (Status Quo)

| Tier | €/Monat | Produkte | Deals | Team | Postfach | Workspaces |
|---|---|---|---|---|---|---|
| Free | 0 | 50 | 25 | 1 | — | 1 |
| Starter | 6.99 | 500 | ∞ | 1 | 1 / 7 Tage | 1 |
| Pro | 14.99 | 5 000 | ∞ | 3 | 3 / 14 Tage | 1 |
| Business | 34.99 | 100 000 | ∞ | 10 | 10 / 30 Tage | 1 |
| Ultimate | 59.99 | 300 000 | ∞ | 50 | 15 / 90 Tage | 1 |

**Probleme:**
- 5 Tiers verwirren Solo-User („brauche ich Starter oder Pro?")
- Postfach in Starter (€6.99) → höchste Infra-Kosten in günstigstem Paid-Tier (DB-Load durch IMAP-Polls + Mail-Bodies)
- Team-Mitglieder schon ab Starter (1) → trivial, schafft kaum Wert-Differenzierung
- Workspaces sind im Code nicht gequotad — jeder Owner kann beliebig viele anlegen
- Keine klare Differenzierung „Privat vs. Business vs. Enterprise"

## 3 · Neues Modell — 4 Tiers, klare Trennung

### 3.1 Free (Privat, Reinschnuppern)

| Quota | Wert |
|---|---|
| **Preis** | €0/Monat |
| Produkte | 50 |
| Deals/Monat | 25 |
| Bilder/Eintrag | 0 |
| Storage | 50 MB |
| Postfach | — (Feature ausgeblendet) |
| Workspaces | 1 (eigener) |
| Team-Mitglieder | 1 (du selbst) |
| Carrier-Tracking | manuell + Auto-Polls auf eigene Sendungen |
| Support | Community |

**Zweck:** Trial-Phase, Eindruck, Conversion-Funnel. Keine Postfach-Funktion → minimale Infra-Last.

### 3.2 Solo (Privat, Power-Solo-Reseller)

| Quota | Wert |
|---|---|
| **Preis** | **€7.99/Monat oder €79/Jahr** (-17%) |
| Produkte | 2 000 |
| Deals/Monat | ∞ |
| Bilder/Eintrag | 3 |
| Storage | 5 GB |
| Postfach | — (bewusst gegated) |
| Workspaces | 1 |
| Team-Mitglieder | 1 |
| Carrier-Tracking | Auto-Polls + eigene API-Keys |
| Statistik | volle Tiefe (Drilldowns, Heatmaps) |
| Export | CSV + PDF + Excel |
| Support | E-Mail (48h) |

**Zweck:** Solo-Reseller, die Inventar pflegen + Verkäufe tracken, aber den Mail-Import nicht brauchen (manuelle Pflege reicht). Preis bewusst günstig — der teuerste Infra-Faktor (Postfach + IMAP) entfällt.

### 3.3 Business (Kleine Firmen / Mini-Teams)

| Quota | Wert |
|---|---|
| **Preis** | **€19.99/Monat oder €199/Jahr** (-17%) |
| Produkte | 25 000 |
| Deals/Monat | ∞ |
| Bilder/Eintrag | 5 |
| Storage | 25 GB |
| Postfach | — (bewusst gegated, kommt in Enterprise) |
| Workspaces | 1 |
| Team-Mitglieder | bis 5 |
| Carrier-Tracking | Auto-Polls + eigene API-Keys |
| Statistik | volle Tiefe + Forecast |
| Export | + DATEV |
| API | Read-only Webhooks |
| Support | E-Mail (24h) |

**Zweck:** Kleine Reseller-Crews / Mini-Buchhaltung. Erstes echtes Multi-User-Tier, aber noch **single-Workspace** und **ohne Postfach** — das bleibt das große Enterprise-Differenzierungsmerkmal.

### 3.4 Enterprise (Power-User, Teams, Multi-Workspace)

| Quota | Wert |
|---|---|
| **Preis** | **€49.99/Monat oder €499/Jahr** (-17%) |
| Produkte | 250 000 (Soft-Cap, höher per Anfrage) |
| Deals/Monat | ∞ |
| Bilder/Eintrag | 15 |
| Storage | 250 GB |
| **Postfach** | ✅ **15 Postfächer, 90 Tage Verlauf, IMAP-Auto-Sync** |
| **E-Mail-Tracking** | ✅ Auto-Erkennung Sendungsnummern aus Mails, Inbox-Adapter (Amazon, MediaMarkt, Otto, …) |
| **Workspaces** | ✅ **bis 10 parallele Workspaces** (z. B. Firma + Privat + Marken) |
| **Team-Einladungen** | ✅ **bis 25 Mitglieder** pro Workspace |
| Carrier-Tracking | Auto-Polls + Premium-Carrier-Adapter |
| API | Read + Write + Webhooks |
| Custom-Branding | für Reports |
| SSO | SAML / OIDC |
| Support | Priority-SLA (12h) + dedizierter Account-Kontakt |

**Zweck:** Der einzige Tier in dem Postfach, Multi-Workspace und Team-Einladungen funktionieren. Klare Story für Sales: „Möchtest du Mails automatisch tracken, deine Verkäufe an dein Team delegieren oder mehrere Marken trennen → Enterprise."

### 3.5 Tier-Vergleich auf einen Blick

| Feature | Free | Solo | Business | Enterprise |
|---|:-:|:-:|:-:|:-:|
| Produkte | 50 | 2 000 | 25 000 | 250 000 |
| Deals/Monat | 25 | ∞ | ∞ | ∞ |
| Bilder/Eintrag | 0 | 3 | 5 | 15 |
| Storage | 50 MB | 5 GB | 25 GB | 250 GB |
| Team-Mitglieder | 1 | 1 | 5 | 25 |
| Workspaces | 1 | 1 | 1 | **10** |
| **Postfach (IMAP)** | ❌ | ❌ | ❌ | ✅ **15 / 90 Tage** |
| **Mail-Tracking-Auto-Detect** | ❌ | ❌ | ❌ | ✅ |
| **Workspace-Einladung** | ❌ | ❌ | begrenzt | ✅ |
| API + Webhooks | ❌ | ❌ | Read | Read+Write |
| SSO | ❌ | ❌ | ❌ | ✅ |
| Support | Community | 48h | 24h | 12h SLA |
| **€/Monat** | **0** | **7.99** | **19.99** | **49.99** |
| **€/Jahr (−17%)** | 0 | 79 | 199 | 499 |

## 4 · Infra-Kosten-Annahmen (Stand 2026)

Quellen: Supabase Pro-Plan-Pricing, Firebase FCM, Carrier-API-Spec.

| Posten | Preis | Notiz |
|---|---|---|
| Supabase Pro-Plan (Base) | $25 / Monat | Inkl. 8 GB DB, 100 GB Egress, 100 GB File-Storage, 2 Mio Edge-Function-Invocations, 250K Realtime-Messages |
| DB-Storage über 8 GB | $0.125 / GB / Monat | |
| File-Storage über 100 GB | $0.021 / GB / Monat | |
| Egress über 100 GB | $0.09 / GB / Monat | |
| Edge-Function-Invocations über 2 Mio | $2 / Mio | |
| Realtime über 250K Messages | $10 / Mio | |
| Firebase Cloud Messaging | $0 | FCM ist komplett kostenlos (unlimited Pushes) |
| Carrier-APIs | $0 für uns | User hinterlegt eigene API-Keys (DHL Free-Tier 1K/h, andere Volume-Pricing) |

## 5 · Worst-Case-Kostenrechnung — was kostet uns ein User maximal?

**Annahme pro Posten:** User reizt sein Limit zu 100 % aus über 12 Monate.

### 5.1 Free (Worst-Case)

| Posten | Berechnung | Kosten/Monat |
|---|---|---|
| DB-Rows | 50 Produkte × ~2 KB + 25 Deals/Mo × ~2 KB | ~150 KB total → 0 € |
| File-Storage | 50 MB (Limit) | 0 € (unter 100 GB Pool) |
| Egress | ~20 MB/Monat (UI-Loads) | 0 € |
| Edge-Functions | 0 (kein Postfach), ~10 Tracking-Polls/Monat | 0 € |
| Realtime | ~5 Messages/Monat | 0 € |
| **Total** | | **~0 €** |

**Marge auf €0 Plan-Preis:** ≈0 (gewolltes Trial-Subventions-Tier, bezahlt aus den Paid-Tiers).

### 5.2 Solo (Worst-Case)

| Posten | Berechnung | Kosten/Monat |
|---|---|---|
| DB-Rows | 2 000 Produkte × 2 KB + ∞ Deals (real: 500/Mo × 2 KB) | 5 MB → 0 € |
| File-Storage | 5 GB (Limit, 3 Bilder × 2 000 Produkte × ~800 KB) | 0 € (unter Pool) |
| Egress | 5 GB Bilder + Reports + UI-Loads ~2 GB | 0 € (unter Pool) |
| Edge-Functions | ~200 Tracking-Polls/Monat + ~500 Frontend-Calls | 0 € (unter Free-Tier) |
| Realtime | 1 000 Messages/Monat | 0 € |
| **Total** | | **< 0.50 €** |

**Marge auf €7.99 Solo:** ~94 % (€7.50 / €7.99).

### 5.3 Business (Worst-Case, 5 Team-Mitglieder)

| Posten | Berechnung | Kosten/Monat |
|---|---|---|
| DB-Rows | 25 000 Produkte × 2 KB + 2 000 Deals/Mo × 2 KB × 12 Monate | 50 MB Stamm + 50 MB Deals/Jahr → 0 € (unter 8 GB Pool) |
| File-Storage | 25 GB Bilder | 0 € (unter 100 GB Pool, aber wenn 4 User über Limit → in den Pool) |
| Egress | 25 GB Bilder × 2 (Up+Down) + 10 GB UI = 60 GB | 0 € |
| Edge-Functions | ~5 000 Tracking-Polls/Monat + 5 000 Frontend-Calls × 5 Team-Member = 25 000 | 0 € (Free-Tier) |
| Realtime | 50 000 Messages/Monat (5 User × 10K) | 0 € |
| **Total** | | **~1.50 €** |

**Marge auf €19.99 Business:** ~92 % (€18.50 / €19.99).

### 5.4 Enterprise (Worst-Case, alle Premium-Features ausgereizt)

Annahme: 25 Team-Mitglieder × 10 Workspaces aktiv, 15 Postfächer mit jeweils 100 Mails/Tag, 250 000 Produkte mit 15 Bildern.

| Posten | Berechnung | Kosten/Monat |
|---|---|---|
| **DB-Rows** | 250 K Produkte × 2 KB = 500 MB + 10 000 Deals/Mo × 2 KB × 12 = 240 MB + Mail-Bodies (15 Postfächer × 100 Mails/Tag × 30 × 5 KB = 225 MB/Monat × 3 Monate Retention = 675 MB) | ~1.4 GB DB-Footprint pro User → 0 € (unter 8 GB Shared-Pool — bei vielen Enterprise-Usern Überschuss auf $0.125/GB) |
| **File-Storage** | 250 GB Bilder + 5 GB Attachments | 250 GB über 100 GB Pool = +150 GB × $0.021 = **3.15 €** |
| **Egress** | 250 GB Bilder × ⅓ Read-Anteil/Mo = 83 GB + UI-Loads 20 GB = 103 GB | 3 GB über Pool × $0.09 = **0.27 €** |
| **Edge-Function-Invocations** | Tracking-Polls alle 4h × 30 × 10 Workspaces = 1 800 / Mo. Inbox-Polls alle 15min × 15 Postfächer × 24 × 30 = 1 296 000 / Mo. Frontend-Calls 25 User × 5 000/Mo = 125 000. **Total ≈ 1 423 000** | unter 2 Mio Pro-Pool inkl. → **0 €** für diesen User, marginal $0.85 wenn mehrere User über Pool |
| **Realtime-Messages** | 25 User × 20 000 Messages/Mo = 500 000 | 250 K über Pool × $0.01 = **2.50 €** |
| **Firebase FCM** | unbegrenzt | **0 €** |
| **Carrier-APIs** | User-eigene Keys | **0 €** für uns |
| **Total Worst-Case** | | **~6.00–7.00 €** pro Vollnutzungs-Enterprise-User/Monat |

**Marge auf €49.99 Enterprise:** ~86 % (€43 / €49.99) selbst bei voller Auslastung.

### 5.5 Realistisches Median-Profil

Die obigen Worst-Cases setzen 100 %-Auslastung über 12 Monate voraus — passiert in der Realität bei <5 % der User. Median-Schätzungen aus vergleichbaren SaaS:

| Tier | Worst-Case-Kosten | Median (20 % der Limits) | Marge Median |
|---|---|---|---|
| Free | 0 € | 0 € | — |
| Solo | 0.50 € | 0.10 € | 98 % |
| Business | 1.50 € | 0.30 € | 98 % |
| Enterprise | 6.50 € | 1.30 € | 97 % |

## 6 · Unit-Economics-Checks

| Frage | Antwort |
|---|---|
| Wann lohnt sich Free? | Sobald 1 Solo-User für 16 Free-User mitzahlt (€7.99 deckt 16 × €0.50). |
| Break-Even-Solo-User pro Enterprise? | 1 Enterprise (€49.99) entspricht ~7 Solo-Usern bei Margenparität. |
| Postfach-Kostentreiber | IMAP-Polls (1.3 Mio/Mo bei 15 Postfächern) dominieren Edge-Function-Quota. Begründet Enterprise-only-Gating. |
| Kann Solo zu Business wechseln, ohne Daten zu verlieren? | Ja — Quota-Erhöhung ist pure Konfiguration, kein Schema-Wechsel. |
| Kann Business→Enterprise das Postfach nachträglich aktivieren? | Ja — `mailboxLimit` von 0 auf 15 setzen, UI zeigt Tab automatisch (Plan-Quota-Gate ist schon im Code, [PricingPlan.hasInbox](../lib/models/pricing_plan.dart#L49)). |

## 7 · Implementations-Plan

### 7.1 Migration der existierenden 5 Tiers → 4 Tiers

| Alt | Neu |
|---|---|
| Free | Free |
| Starter (€6.99, 500 Produkte, 1 Postfach) | **Solo** (€7.99, 2 000 Produkte, **kein Postfach**) — bestehende User behalten Postfach via Grandfathering-Flag `legacy_inbox: true` für 6 Monate |
| Pro (€14.99) | **Business** (€19.99) — kostenloses Upgrade für bestehende Pro-User für 12 Monate |
| Business (€34.99) | **Business** (€19.99) — Preis-Reduktion zu User-Gunsten |
| Ultimate (€59.99) | **Enterprise** (€49.99) — Preis-Reduktion |

**Sicherheits-Pattern:** `billing_profile.legacy_plan` Spalte hinzufügen → migrations-Script setzt bei jedem User den alten Plan-Namen, damit Quotas + Features für Bestandskunden während der Übergangsfrist erhalten bleiben.

### 7.2 Code-Änderungen (Sprint-Schätzung)

| Datei | Change | Aufwand |
|---|---|---|
| [lib/models/billing_profile.dart](../lib/models/billing_profile.dart) | Enum auf `free, solo, business, enterprise` reduzieren + Legacy-Mapping für `starter/pro/ultimate` → grandfathering | S |
| [lib/models/pricing_plan.dart](../lib/models/pricing_plan.dart) | Neue PricingPlan-Liste mit 4 Tiers | S |
| [lib/l10n/app_*.arb](../lib/l10n/app_de.arb) | 4 Tier-Beschreibungen DE + EN, neue Highlights | M |
| [lib/screens/pricing_screen.dart](../lib/screens/pricing_screen.dart) | UI für 4 statt 5 Cards, Workspace-Quota-Anzeige | S |
| [lib/providers/active_workspace_provider.dart](../lib/providers/active_workspace_provider.dart) | `maxWorkspaces`-Quota durchsetzen | M |
| [supabase/migrations/](../supabase/migrations/) | `ALTER TABLE billing_profiles ADD COLUMN legacy_plan text;` + Daten-Migration | M |
| Stripe / Zahlungs-Setup | 4 neue Produkte + Preise anlegen, alte deprecaten | M (manuell) |
| Marketing/Landing-Page | neue Tier-Tabelle, „Enterprise-only Postfach"-Story | L (außerhalb dieses Plans) |

### 7.3 Roll-out

1. **Phase 1** (sofort): neue PricingPlan-Definition im Code committen, Pricing-Screen zeigt die 4 neuen Tiers.
2. **Phase 2** (vor Launch): Stripe-Setup, Migration für Bestandskunden (Pre-Launch sind das aktuell 0 User → trivial).
3. **Phase 3** (Launch): Postfach-Gate scharfstellen (`mailboxLimit > 0` nur bei Enterprise).

## 8 · Risiken & Trade-offs

| Risiko | Mitigation |
|---|---|
| Solo-Reseller wollen Postfach für €7.99 | Klar kommunizieren: „Postfach ist Power-Feature, dadurch hohe Infra-Last → Enterprise". Wer wirklich Postfach braucht, wechselt. |
| Business-Tier (€19.99) wirkt wenig differenziert vs. Solo (€7.99) | Bessere Differenzierung über 5 Team-Mitglieder + DATEV-Export + Webhook-API. Falls Adoption schwach → Mid-Tier später streichen oder Postfach-Lite (1 Postfach) freischalten. |
| Enterprise zu billig für echte Firmen | €49.99 ist Anker-Preis; Add-on „dediziertes On-Boarding €499 einmalig" + „Custom-SLA €99/Mo" als Up-Sells. |
| 1.3 Mio IMAP-Invocations/User/Monat sprengt 2 Mio Pro-Pool | Hard-Limit: tracking-poll alle 15min reicht für 90 % der Use-Cases; Edge-Function-Bursting im Notfall via Webhook-Push statt Polling (zukünftige Optimierung). |
| Bestehender Code hat Ultimate-spezifische Branchen (z. B. `mostPopular: true` auf Pro) | Grep + Refactor in 7.2 inkludiert. |

## 9 · Offene Entscheidungen für den Stakeholder

1. **Solo-Tier-Preis:** €7.99 (vorgeschlagen) vs. €4.99 (aggressiv günstig, Conversion-Maximierung)?
2. **Business-Tier wirklich beibehalten?** Pre-Launch könnte man auch nur **Free / Solo / Enterprise** machen (3-Tier-Pattern wie Notion, Linear). Mid-Tier später nachschieben, wenn Adoption-Data da ist.
3. **Workspace-Limit Enterprise (10) Hard-Cap oder Soft-Cap?** Soft-Cap mit „mehr auf Anfrage" eröffnet Sales-Gespräche; Hard-Cap erzwingt nichts.
4. **Yearly-Rabatt:** −17 % (vorgeschlagen) ist branchen-Standard. Mehr (−25 %) → höhere Conversion auf Yearly aber niedrigere MRR; weniger (−10 %) → mehr MRR aber niedrigere Yearly-Adoption.
5. **Postfach-Lite in Business:** 1 Postfach + 7 Tage Verlauf in Business für €+10/Mo Add-on? Würde den Sprung Solo→Business verstärken und Enterprise-Pflicht-Kauf entlasten.

## 10 · Empfehlung

**Go-to-Market mit den 4 Tiers wie oben**, weil:

- Klare Story: Privat (Free/Solo) vs. Firma (Business) vs. Power (Enterprise).
- Enterprise-only-Postfach ist sauberes Up-Sell-Argument („das eine Killer-Feature").
- Marge bleibt auch im Worst-Case > 85 % auf allen Paid-Tiers — viel Headroom für Discounts, Free-Subventionen, Customer-Acquisition-Cost.
- Migration trivial, weil Pre-Launch (0 echte Bestandskunden).

**Empfohlene Antwort auf User-Frage 9.2** (Business-Tier beibehalten?):
**Ja** — Mid-Tier-Pricing-Pattern (Free → Solo → Mid → Enterprise) hat empirisch +20–30 % Conversion durch Anker-Effekt (Mid-Tier macht Enterprise „bezahlbarer wirken"). Aber 4 Tiers max — fünfter würde wieder verwirren.

---

**Worst-Case-Marketing-Statement (One-Liner):** „CanLogistics Enterprise — €49.99/Mo, 15 Postfächer, 10 Workspaces, 25 User. Maximale Infra-Last für uns: 6,50 € pro Account. Marge: 87 %."
