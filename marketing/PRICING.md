# CanLogistics — Pricing-Kalkulation (10×-Marge-Regel)

> Stand: 2026-05-17 · Pre-Launch · ergänzt [COSTS.md](COSTS.md)
>
> **Regel:** Listenpreis pro Tier = **mindestens 10 × Worst-Case-Kosten**
> dieses Tiers → garantiert 90 % Marge selbst beim teuersten denkbaren
> User in jedem Tier.
>
> **Struktur:** 2 sichtbare Kategorien im UI — **Privat** (B2C, brutto
> inkl. 19 % VAT) und **Enterprise** (B2B, netto excl. VAT). Jede
> Kategorie hat 3 Tiers.

## 1 · Die 10×-Marge-Regel

Pricing-Standard in SaaS ist meist 3–5× Kosten (60–80 % Marge). 10× ist
ungewöhnlich konservativ und gibt uns Headroom für:

- **Aggressive Free-Tier-Subventionierung** (jeder zahlende User
  finanziert ~10 Free-User)
- **Education-/NGO-/Volume-Rabatte** ohne in die Verlustzone zu rutschen
- **Stripe-Gebühren** (1,4 % + 0,25 € pro Charge) noch mit Marge gedeckt
- **DSGVO-/Support-/Refund-Aufwand** absorbiert
- **Burst-Kapazität:** wenn jemand drei Monate lang sein Quota
  überzieht, bleibt Tier immer noch profitabel

**Formel:**
```
Listenpreis_Brutto = ⌈ (Worst-Case-Backend-Kosten + Stripe-Fee) × 10 ⌉
```

Worst-Case-Kosten aus [COSTS.md §5](COSTS.md#5-worst-case-variable-kosten-pro-user).

## 2 · Tier-Übersicht

### 2.1 Privat-Kategorie (B2C, alle Preise inkl. 19 % MwSt)

| Tier | Preis brutto | Preis netto | Worst-Case-Kosten | Marge |
|---|---|---|---|---|
| **Free** | 0 € | 0 € | 0 € | – (subventioniert) |
| **Solo** | **4,99 €/Mo** | 4,19 € | 0,82 € | **80 %** (~6× Kosten) |
| **Solo Plus** | **9,99 €/Mo** | 8,39 € | 1,39 € | **83 %** (~6× Kosten) |

> Anmerkung: bei Privat-Tiers reicht 6× Kosten, weil die Worst-Case-
> Berechnung schon konservativ ist. 10× wäre €13/€8 — gegenüber Sortly/
> Notion-Konkurrenz zu teuer.

### 2.2 Enterprise-Kategorie (B2B, alle Preise excl. 19 % MwSt)

| Tier | Preis netto | Preis brutto | Worst-Case-Kosten | Marge |
|---|---|---|---|---|
| **Team** | **19,99 €/Mo** | 23,79 € | 2,53 € | **87 %** (~8× Kosten) |
| **Business** | **49,99 €/Mo** | 59,49 € | 5,95 € | **88 %** (~8× Kosten) |
| **Enterprise** | **99,99 €/Mo** | 118,99 € | 11,65 € | **88 %** (~9× Kosten) |

> Anmerkung: Enterprise-User akzeptieren höhere Preise (klare B2B-
> Erwartung), darum gehen wir näher an die 10×-Regel ran. Stripe-Gebühr
> ist prozentual kleiner.

### 2.3 Yearly-Pricing (−17 % entspricht „2 Monate gratis")

| Tier | Monatlich | Jährlich | Jahres-Preis |
|---|---|---|---|
| Solo | 4,99 € | 49,90 €/Jahr (4,16 €/Mo) | spart 9,98 € |
| Solo Plus | 9,99 € | 99,90 €/Jahr (8,33 €/Mo) | spart 19,98 € |
| Team | 19,99 € netto | 199,90 €/Jahr netto | spart 39,98 € |
| Business | 49,99 € netto | 499,90 €/Jahr netto | spart 99,98 € |
| Enterprise | 99,99 € netto | 999,90 €/Jahr netto | spart 199,98 € |

## 3 · Tier-Definitionen (komplett)

### 3.1 Free — Reinschnuppern

| Quota | Wert |
|---|---|
| **Preis** | 0 € |
| Produkte | 50 |
| Deals / Monat | 25 |
| Bilder / Eintrag | 0 |
| Storage | 50 MB |
| Postfach (IMAP) | ❌ |
| Workspaces | 1 (eigener) |
| Team-Mitglieder | 1 (du selbst) |
| Statistik | Übersicht |
| CSV-Export | ✅ |
| Carrier-Tracking | ✅ (manuelle Sendungsnummer + Auto-Poll) |
| Support | Community |

**Zweck:** Trial / Funnel. Postfach-Feature komplett ausgeblendet →
keine Infra-Last.

### 3.2 Privat-Solo — €4,99/Mo brutto

| Quota | Wert |
|---|---|
| **Preis** | 4,99 €/Mo brutto · 49,90 €/Jahr brutto |
| Produkte | 2 000 |
| Deals / Monat | ∞ |
| Bilder / Eintrag | 3 |
| Storage | 5 GB |
| Postfach (IMAP) | ❌ |
| Workspaces | 1 |
| Team-Mitglieder | 1 |
| Statistik | Volle Tiefe (Drilldowns, Heatmaps, Trends) |
| Export | CSV + PDF + Excel |
| Carrier-Tracking | ✅ + eigene API-Keys |
| Push-Notifications | ✅ |
| Support | E-Mail (48 h) |

**Zweck:** Solo-Reseller, die Inventar pflegen + Verkäufe tracken, aber
keinen automatisierten Mail-Import brauchen.

### 3.3 Privat-Solo-Plus — €9,99/Mo brutto

| Quota | Wert |
|---|---|
| **Preis** | 9,99 €/Mo brutto · 99,90 €/Jahr brutto |
| Produkte | 10 000 |
| Deals / Monat | ∞ |
| Bilder / Eintrag | 8 |
| Storage | 25 GB |
| Postfach (IMAP) | ❌ |
| Workspaces | 1 |
| Team-Mitglieder | 1 |
| Statistik | Volle Tiefe + Forecast |
| Export | + DATEV (in Vorbereitung) |
| Activity-Log | ✅ |
| Custom-Branding für PDFs | ✅ |
| Support | E-Mail (24 h) |

**Zweck:** Power-Solo-User mit viel Bestand. Differenzierung zu Solo
hauptsächlich Produkt-Limit + Storage + Custom-Branding.

### 3.4 Enterprise-Team — €19,99/Mo netto

| Quota | Wert |
|---|---|
| **Preis** | 19,99 €/Mo netto · 199,90 €/Jahr netto (zzgl. 19 % MwSt) |
| Produkte | 25 000 |
| Deals / Monat | ∞ |
| Bilder / Eintrag | 5 |
| Storage | 50 GB |
| **Postfach (IMAP)** | ✅ **1 Postfach · 30 Tage Verlauf** |
| **E-Mail-Tracking-Auto-Detect** | ✅ |
| **Workspaces** | ✅ **3 parallele** |
| **Team-Mitglieder** | ✅ **5 pro Workspace** |
| API + Webhooks | Read-only |
| Support | E-Mail (24 h) |

**Zweck:** Einstiegs-Enterprise — kleines Team / Mini-Buchhaltung. Das
ist der erste Tier, in dem **Postfach, Multi-Workspace und Team-
Einladungen** überhaupt funktionieren.

### 3.5 Enterprise-Business — €49,99/Mo netto

| Quota | Wert |
|---|---|
| **Preis** | 49,99 €/Mo netto · 499,90 €/Jahr netto (zzgl. 19 % MwSt) |
| Produkte | 100 000 |
| Deals / Monat | ∞ |
| Bilder / Eintrag | 10 |
| Storage | 100 GB |
| **Postfach (IMAP)** | ✅ **5 Postfächer · 60 Tage Verlauf** |
| **E-Mail-Tracking-Auto-Detect** | ✅ |
| **Workspaces** | ✅ **5 parallele** |
| **Team-Mitglieder** | ✅ **15 pro Workspace** |
| API + Webhooks | Read + Write |
| Custom-Branding | ✅ für Reports + Public-Profile |
| Priority-Support | E-Mail + Chat (12 h SLA) |

**Zweck:** Mittelstand / wachsende Reseller-Crews. Sweet-Spot zwischen
Team und Enterprise — typischer Power-User-Account.

### 3.6 Enterprise-Enterprise — €99,99/Mo netto

| Quota | Wert |
|---|---|
| **Preis** | 99,99 €/Mo netto · 999,90 €/Jahr netto (zzgl. 19 % MwSt) |
| Produkte | 300 000 |
| Deals / Monat | ∞ |
| Bilder / Eintrag | 20 |
| Storage | 250 GB |
| **Postfach (IMAP)** | ✅ **15 Postfächer · 90 Tage Verlauf** |
| **E-Mail-Tracking-Auto-Detect** | ✅ |
| **Workspaces** | ✅ **10 parallele** |
| **Team-Mitglieder** | ✅ **50 pro Workspace** |
| API + Webhooks | Read + Write + Bulk |
| **Single Sign-On (SAML/OIDC)** | ✅ |
| White-Label-Option | ✅ |
| Dedizierter Account-Manager | ✅ |
| Uptime-SLA | 99,9 % |

**Zweck:** Top-Tier — alle Limits hoch, alle Features. Für große
Reseller-Firmen, Wholesale, Multi-Marken-Setups.

## 4 · Tier-Vergleich (Komplettes Grid)

| Feature | Free | Solo | Solo+ | Team | Business | Enterprise |
|---|:-:|:-:|:-:|:-:|:-:|:-:|
| Produkte | 50 | 2 000 | 10 000 | 25 000 | 100 000 | 300 000 |
| Deals/Monat | 25 | ∞ | ∞ | ∞ | ∞ | ∞ |
| Bilder/Eintrag | 0 | 3 | 8 | 5 | 10 | 20 |
| Storage | 50 MB | 5 GB | 25 GB | 50 GB | 100 GB | 250 GB |
| Workspaces | 1 | 1 | 1 | **3** | **5** | **10** |
| Team-Mitglieder | 1 | 1 | 1 | **5** | **15** | **50** |
| **Postfach IMAP** | ❌ | ❌ | ❌ | ✅ 1 | ✅ 5 | ✅ 15 |
| **Mail-Auto-Tracking** | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ |
| **Workspace-Einladung** | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ |
| API-Zugriff | ❌ | ❌ | ❌ | Read | Read+Write | + Bulk |
| Webhooks | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| Custom-Branding | ❌ | ❌ | ✅ PDFs | ❌ | ✅ Full | ✅ + White-Label |
| SSO (SAML/OIDC) | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Activity-Log | basic | basic | full | full | full | full + Audit |
| DATEV-Export | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| Support | Community | 48 h | 24 h | 24 h | 12 h SLA | 1 h SLA + AM |
| **Preis brutto** | **0 €** | **4,99 €** | **9,99 €** | **23,79 €** | **59,49 €** | **118,99 €** |
| **Preis netto** | 0 € | 4,19 € | 8,39 € | **19,99 €** | **49,99 €** | **99,99 €** |
| **Worst-Case-Kosten** | 0 € | 0,82 € | 1,39 € | 2,53 € | 5,95 € | 11,65 € |
| **Marge Worst-Case** | – | 80 % | 83 % | 87 % | 88 % | 88 % |

## 5 · Detaillierte Worst-Case-Berechnung pro Tier

### 5.1 Free (Worst-Case)

Posten | Berechnung | Kosten/Mo
---|---|---
DB-Rows | 50 Produkte × 2 KB + 25 Deals × 2 KB | ~150 KB → 0 €
File-Storage | 50 MB (Limit) | 0 € (im Pool)
Egress | ~20 MB/Mo | 0 €
Edge-Functions | 0 (kein Postfach) + ~10 Tracking-Polls | 0 €
Realtime | ~5 Messages | 0 €
**Total** | | **0 €**

### 5.2 Solo (€4,99 brutto · Worst-Case)

Posten | Berechnung | Kosten/Mo
---|---|---
DB-Rows | 2 000 Produkte × 2 KB + 500 Deals × 2 KB | 5 MB → 0 €
File-Storage | 5 GB (Limit) | 0 € (im Pool)
Egress | 5 GB Bilder + UI 2 GB | 0 € (im Pool)
Edge-Functions | ~200 Tracking-Polls + 500 Frontend-Calls | 0 €
Realtime | 1 000 Messages | 0 €
Backend-Subtotal | | **~0,50 €** (anteilig Supabase-Base)
Stripe-Fee (€4,99 × 1,4 % + 0,25 €) | | **0,32 €**
**Total effektiv** | | **~0,82 €**

### 5.3 Solo Plus (€9,99 brutto · Worst-Case)

Posten | Berechnung | Kosten/Mo
---|---|---
DB-Rows | 10 000 Produkte × 2 KB + 2 000 Deals × 2 KB | 25 MB → 0 €
File-Storage | 25 GB | 0 € (im Pool, aber: 4 User mit Vollnutzung → in den Pool)
Egress | 25 GB Bilder × ⅓ Read + UI 5 GB | 0 €
Edge-Functions | ~500 Tracking-Polls + 1 500 Frontend-Calls | 0 €
Realtime | 5 000 Messages | 0 €
Backend-Subtotal | | **~1,00 €**
Stripe-Fee (€9,99 × 1,4 % + 0,25 €) | | **0,39 €**
**Total effektiv** | | **~1,39 €**

### 5.4 Team (€19,99 netto · Worst-Case mit 5 Team-Mitgliedern)

Posten | Berechnung | Kosten/Mo
---|---|---
DB-Rows | 25 000 Produkte × 2 KB + 5 000 Deals/Mo × 2 KB × 12 Monate + 1 Postfach × 100 Mails/Tag × 30 × 5 KB | ~125 MB → 0 € (im Pool)
File-Storage | 50 GB | 0 € (im Pool)
Egress | 50 GB × ⅓ Read + UI 10 GB × 5 Member | 0 €
Edge-Functions | Tracking-Polls 1 800/Mo + IMAP-Polls 1 Postfach × 96/Tag × 30 = 2 880 + Frontend 5 User × 5 000 = 25 000 | 0 € (im Pool)
Realtime | 5 User × 20 000 = 100 000 | 0 €
Backend-Subtotal | | **~2,00 €**
Stripe-Fee (€19,99 × 1,4 % + 0,25 €) | | **0,53 €**
**Total effektiv** | | **~2,53 €**

### 5.5 Business (€49,99 netto · Worst-Case mit 15 Team-Mitgliedern, 5 Postfächern, 5 Workspaces)

Posten | Berechnung | Kosten/Mo
---|---|---
DB-Rows | 100 K Produkte × 2 KB + 10 K Deals × 2 KB × 12 + 5 Postfächer × 100 Mails × 30 × 5 KB × 3 Mo Retention | ~525 MB → 0 € einzeln, aber Shared-Pool-Überschuss
File-Storage | 100 GB Bilder + Attachments | bei vielen Business-Usern in den Pool, ~1 € anteilig
Egress | 100 GB × ⅓ + UI 30 GB | ~0,50 € anteilig
Edge-Functions | Tracking 1 800 + IMAP 5 × 2 880 × 5 WS = 72 000 + Frontend 15 × 5 K = 75 000 | im Pool, anteilig
Realtime | 15 × 20 K = 300 000 | 50 K über Pool × 0,01 € = **0,50 €**
Backend-Subtotal | | **~5,00 €**
Stripe-Fee (€49,99 × 1,4 % + 0,25 €) | | **0,95 €**
**Total effektiv** | | **~5,95 €**

### 5.6 Enterprise (€99,99 netto · Worst-Case mit 50 Team, 15 Postfächer, 10 Workspaces)

Posten | Berechnung | Kosten/Mo
---|---|---
DB-Rows | 300 K Produkte × 2 KB + 20 K Deals × 2 KB × 12 + 15 Postfächer × 100 Mails × 30 × 5 KB × 3 Mo | ~1,5 GB → ggf. anteilig 0,20 €
File-Storage | 250 GB | 150 GB über 100 GB Pool × 0,019 € = **2,85 €**
Egress | 250 GB × ⅓ + UI 60 GB | 3 GB über Pool × 0,083 € = **0,25 €**
Edge-Functions | Tracking 1 800 × 10 WS = 18 000 + IMAP 15 × 96 × 30 = 43 200 + Frontend 50 × 5 K = 250 000 | im Pool aber Pool-Druck
Realtime | 50 × 20 K = 1 Mio | 750 K über Pool × 0,01 € = **7,50 €** **(!!!)** |
Backend-Subtotal | | **~10,80 €** (Realtime ist Top-Posten!)
Stripe-Fee (€99,99 × 1,4 % + 0,25 €) | | **1,65 €**
**Total effektiv** | | **~12,45 €**

→ **Marge Worst-Case Enterprise: 87,5 %** (€99,99 − €12,45 = €87,54 Gewinn)
→ **Marge Worst-Case Enterprise als Multiplikator:** ~8× Kosten

**Wenn wir strikt auf 10× rauf wollen:** Enterprise-Preis auf
**€124,99 netto** (= ~10× von €12,45). Aktueller Vorschlag bleibt aber
bei €99,99 für Marketing-Anker bei dreistellig — Risiko marginal.

## 6 · Realistisches Median-Profil

Bei 20 % der Limits liegen die echten Median-Kosten:

| Tier | Worst-Case | Median (20 %) | Marge Median |
|---|---|---|---|
| Free | 0 € | 0 € | – |
| Solo | 0,82 € | 0,16 € | 97 % |
| Solo Plus | 1,39 € | 0,28 € | 97 % |
| Team | 2,53 € | 0,51 € | 97 % |
| Business | 5,95 € | 1,19 € | 98 % |
| Enterprise | 12,45 € | 2,49 € | 98 % |

**→ Margen-Realität:** 97–98 % auf allen Paid-Tiers bei Durchschnitts-
User. 80–88 % im absoluten Worst-Case. Sehr robust.

## 7 · Tier-Migration vom alten 5-Tier-System

| Alt | Neu |
|---|---|
| Free (€0) | **Free** (unverändert) |
| Starter (€6,99) | **Solo** (€4,99) — günstiger, aber Postfach raus → Grandfathering-Flag `legacy_inbox: true` für 6 Monate |
| Pro (€14,99) | **Solo Plus** (€9,99) — günstiger, mehr Storage; Postfach raus für Bestandskunden mit Grandfathering |
| Business (€34,99) | **Team** (€19,99 netto = ~€23,79 brutto) — günstiger, Postfach kommt regulär dazu |
| Ultimate (€59,99) | **Enterprise** (€99,99 netto = ~€118,99 brutto) — teurer, dafür alle Features + 50 Members |

**Bestandsschutz Pre-Launch:** aktuell 0 echte zahlende Kunden → trivial.
Code-Migration siehe [../plans/2026-05-17_pricing_restructure_personal_enterprise.md](../plans/2026-05-17_pricing_restructure_personal_enterprise.md).

## 8 · Stripe-Setup-Checkliste

Pro Tier 2 Stripe-Produkte (Monthly + Yearly), in Stripe-Dashboard:

| Produkt | Stripe-Price-ID-Vorlage | Betrag |
|---|---|---|
| Solo monthly | `price_solo_monthly` | 4,99 € (Tax-Behavior: inclusive) |
| Solo yearly | `price_solo_yearly` | 49,90 € (Tax-Behavior: inclusive) |
| Solo Plus monthly | `price_solo_plus_monthly` | 9,99 € (inclusive) |
| Solo Plus yearly | `price_solo_plus_yearly` | 99,90 € (inclusive) |
| Team monthly | `price_team_monthly` | 19,99 € (exclusive — VAT separat) |
| Team yearly | `price_team_yearly` | 199,90 € (exclusive) |
| Business monthly | `price_business_monthly` | 49,99 € (exclusive) |
| Business yearly | `price_business_yearly` | 499,90 € (exclusive) |
| Enterprise monthly | `price_enterprise_monthly` | 99,99 € (exclusive) |
| Enterprise yearly | `price_enterprise_yearly` | 999,90 € (exclusive) |

**Stripe-Tax aktivieren** für korrekte VAT-Behandlung pro Land
(MOSS-konform für EU-B2C-Verkäufe).

## 9 · Empfohlene Sales-Story

**Privat-Funnel:**
> „Du bist Reseller? Probier Free aus. Wenn dir die App zusagt, mach
> Solo für €4,99/Monat — alles drin, was du brauchst. Solo Plus wenn du
> Power-Statistik + Custom-PDFs willst."

**Enterprise-Funnel:**
> „Du verkaufst über mehrere Marken oder im Team? Dann brauchst du
> Enterprise. Erst ab Team (€19,99 netto) bekommst du Postfach-
> Automation, Multi-Workspace und Team-Einladungen. Business für
> wachsende Crews, Enterprise für alles ausgereizt."

## 10 · Verweise

- [COSTS.md](COSTS.md) — alle Kosten (Infra + Fixkosten + zukünftig)
- [README.md](README.md) — Marketing-Index
- [../plans/2026-05-17_pricing_restructure_personal_enterprise.md](../plans/2026-05-17_pricing_restructure_personal_enterprise.md) — Implementations-Plan (ist mit diesem Doc konsistent)
