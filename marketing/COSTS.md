# CanLogistics — Vollständige Kostenrechnung

> Stand: 2026-05-17 · Author: Claude Opus 4.7 · Pre-Launch-Phase
>
> **Zweck:** Single-Source-of-Truth über alle Geld-raus-Posten — sowohl
> nutzerunabhängige Fixkosten als auch usage-skalierende Backend-Kosten.
> Dient als Grundlage für [PRICING.md](PRICING.md) und Investor-/
> Co-Founder-Gespräche.
>
> Alle Preise in EUR (USD→EUR mit Kurs **1.00 USD = 0.92 EUR**).
> Alle Werte sind Listenpreise vor Verhandlung, ohne Education-/
> Open-Source-/Startup-Rabatte.

## 1 · Übersicht (TL;DR)

| Kategorie | Pre-Launch-Minimum | Live-Betrieb (Jahr 1) |
|---|---|---|
| **Fixkosten / Jahr** | ~270 € | ~1 200 € |
| **Variable Kosten / aktiver User / Monat** | n/a (0 User) | 0,10–6,50 € (Plan-abhängig) |
| **Fixkosten / Monat (gerundet)** | **~22 €** | **~100 €** |

→ **Break-Even-Punkt** Jahr 1: ab ca. **15 Solo-Usern (€4.99/Mo)** oder
**2 Enterprise-Usern (€99/Mo)** sind die Fixkosten gedeckt; jeder
weitere User produziert Gewinn (Marge-Details in [PRICING.md](PRICING.md)).

## 2 · Fixkosten — nutzerunabhängig

Diese laufen, egal ob 0 oder 10.000 User die App benutzen.

### 2.1 Pflicht (heute schon nötig)

| Posten | Anbieter | Preis | Anmerkung |
|---|---|---|---|
| Domain canlogistics.com | Namecheap / Cloudflare | ~12 €/Jahr | Inkl. WHOIS-Privacy |
| Domain-Varianten (.de, .app) | dito | ~25 €/Jahr | Marken-Schutz |
| Supabase Pro-Plan-Base | Supabase | $25/Mo = ~23 €/Mo = **276 €/Jahr** | Inkl. 8 GB DB, 100 GB Egress, 100 GB Storage |
| GitHub Pro (private Repos + Codespaces) | GitHub | $4/Mo = **~44 €/Jahr** | Free-Plan hat private Repos, aber Pro hat Advanced-Security + höhere Codespaces-Quota |
| Apple Developer Program | Apple | **99 €/Jahr** | Pflicht für iOS-App-Store, Push-Notification-Certs |
| Google Play Developer | Google | **22 € einmalig** (~2 €/Jahr amortisiert) | One-Time-Fee für lebenslangen Google-Play-Zugang |
| **Pflicht-Summe** | | **~470 €/Jahr** (~39 €/Mo) | |

### 2.2 Empfohlen (Pre-Launch oder kurz danach)

| Posten | Anbieter | Preis | Anmerkung |
|---|---|---|---|
| Marken-Registrierung "CanLogistics" | DPMA (Deutschland) | **290 € einmalig** (für 10 Jahre, 3 Klassen) | Schützt den Brand-Namen — sinnvoll vor Launch |
| EU-Marken-Registrierung | EUIPO | 850 € einmalig (3 Klassen) | Optional; nationale DPMA-Marke reicht für DACH-Start |
| Trademark Class 9 (Software) + 35 (Dienstleistung) | DPMA | im 290 € enthalten | |
| Datenschutz-Hinweis-Generator | iubenda / Legal-Vorlage | 0–99 €/Jahr | Generator-Tools für DSGVO-Pflicht-Texte |
| AGB-Erstellung | Anwalt einmalig | 200–600 € einmalig | Kann auch via Generator oder Vorlage |
| Steuerberater (Kleinunternehmen) | Lokaler Berater | ~500 €/Jahr | Jahresabschluss + USt-VA monatlich |
| **Empfohlen-Summe** | | **~800 €/Jahr** | |

### 2.3 Live-Betrieb (mit echten Usern)

| Posten | Anbieter | Preis | Anmerkung |
|---|---|---|---|
| E-Mail-Hosting support@canlogistics.com | Cloudflare Email Routing | **0 €** (Forwarding) ODER | Free-Tier reicht für Empfangen + Weiterleiten |
| Google Workspace Business Starter | Google | 6 €/User/Mo = **72 €/Jahr** | Für „echte" Postfächer + Calendar + Drive — optional |
| Status-Page | BetterUptime / UptimeRobot | 0 €–24 €/Mo | UptimeRobot-Free reicht für 50 Monitors |
| Sentry (Error-Monitoring) | Sentry.io | 0 €–26 €/Mo | Free-Tier: 5K Errors/Mo — reicht bis ~50 User |
| Analytics | Plausible / PostHog | 9–19 €/Mo | Privacy-friendly, GDPR-konform |
| Newsletter-Tool | MailerLite / Beehiiv | 0 €–40 €/Mo | Free bis ~1K Subscriber |
| Customer-Support-Tool | Crisp / Help-Scout | 0 €–25 €/Mo | Crisp-Free hat 2 Agents |
| **Live-Betrieb-Range** | | **0–180 €/Mo** | Stark abhängig von gewählten Tools |

### 2.4 Fix-Posten-Gesamtkalkulation Jahr 1

| Szenario | Beträge |
|---|---|
| **Minimum Pre-Launch** | Pflicht (470 €) + Marken-Registrierung (290 €) = **760 € erstes Jahr** |
| **Empfohlen Pre-Launch** | + AGB (400 €) + Steuerberater (500 €) = **1 660 € erstes Jahr** |
| **Live-Betrieb Jahr 2+** | Pflicht (470 €) + Steuerberater (500 €) + Sentry+Status+Analytics (~600 €) = **~1 600 €/Jahr** |

## 3 · Variable Backend-Kosten — pro User skalierend

Diese steigen mit der Anzahl + Aktivität der User. Basis: Supabase Pro
inkl. Pool (8 GB DB, 100 GB Storage, 100 GB Egress, 2 Mio Edge-Functions,
250 K Realtime-Messages). Alles darüber:

| Posten | Über-Pool-Preis | Wer treibt das? |
|---|---|---|
| DB-Storage | $0.125/GB/Mo (~0.115 €) | Power-User mit vielen Produkten + Mails |
| File-Storage (Bilder) | $0.021/GB/Mo (~0.019 €) | User mit vielen Produktbildern |
| Egress | $0.09/GB/Mo (~0.083 €) | User die Reports/Bilder oft laden |
| Edge-Function-Invocations | $2/Mio (~1.84 €) | IMAP-Polling (Postfach-Feature) |
| Realtime-Messages | $10/Mio (~9.20 €) | Live-Sync zwischen Team-Mitgliedern |

### 3.1 Carrier-API-Kosten

| Carrier | Preis | Wer zahlt? |
|---|---|---|
| DHL Sendungsverfolgung-API | Free Developer-Tier: 1 000 Calls/Stunde · Production: vertraglich, ~0,01 € pro Call | **User** (User hinterlegt eigenen API-Key in Settings → Carriers) |
| Hermes / DPD / UPS / etc. | variable, oft Volume-Verträge | **User** (gleicher Mechanismus) |
| → Konsequenz | **0 € für CanLogistics** | Wir routen nur, User trägt Carrier-Vertrag |

### 3.2 Push-Notifications

| Anbieter | Preis | Anmerkung |
|---|---|---|
| Firebase Cloud Messaging | **0 €** (unbegrenzt) | FCM ist komplett kostenlos, auch bei Mio Pushes/Mo |
| Apple Push Notification Service | **0 €** (via Apple-Developer-Programm inkludiert) | Cert-Verwaltung kommt aus dem 99 €/Jahr-Topf |

### 3.3 Stripe Zahlungs-Gebühren

Pro abgewickelte Subscription-Charge:

| Posten | Preis |
|---|---|
| Europäische Karten (EUR) | 1,4 % + 0,25 € pro Transaktion |
| Nicht-europäische Karten | 2,9 % + 0,25 € pro Transaktion |
| SEPA-Lastschrift | 0,8 % (capped bei 5 €) |
| **Worst-Case-Beispiel:** €99 Enterprise-Subscription/Mo | 1,4 % × 99 + 0,25 = **1,64 €** Stripe-Cut/Mo |
| **Best-Case-Beispiel:** €4,99 Solo-Subscription/Mo | 1,4 % × 4,99 + 0,25 = **0,32 €** Stripe-Cut/Mo |

→ **Stripe nimmt prozentual mehr von kleinen Tiers** (Fixed-Fee-Anteil). Solo
hat ~6 % Stripe-Cut, Enterprise nur ~1,7 %. Marge-Kalkulation in
[PRICING.md](PRICING.md) zieht das ab.

### 3.4 Zukünftige Kosten (geplant aber noch nicht angefallen)

| Posten | Anbieter | Geschätzter Preis | Wann ungefähr |
|---|---|---|---|
| AI/LLM für Mail-Parsing-Optimierung | OpenAI / Anthropic API | ~0,01 €/Mail bei GPT-4o-mini | sobald >1000 Mails/Tag |
| Image-AI für Produktfoto-Analyse | OpenAI Vision | ~0,002 €/Bild | Q3 2026 (optional) |
| Webhook-/API-Quota (Enterprise-Feature) | Eigene Edge Functions | im Edge-Function-Pool | mit Enterprise-Launch |
| White-Label-Custom-Domains (Enterprise) | Vercel / Cloudflare for SaaS | ~$20/Mo flat | Q4 2026 (optional) |
| **Annahme bis Jahr 2:** | | **0 € zusätzlich** | Aktuell alle Features ohne LLM-Aufwand möglich |

## 4 · Fixkosten-Tabelle (alphabetisch)

Für die Buchhaltung und steuerliche Geltendmachung:

| Posten | Frequenz | Jahresbetrag | Notiz |
|---|---|---|---|
| Apple Developer Program | jährlich | 99 € | Pflicht iOS |
| Domain canlogistics.com | jährlich | 12 € | + Renewals |
| Domain canlogistics.de | jährlich | 13 € | DACH-Markt |
| GitHub Pro | monatlich | 44 € | $4/Mo × 12 |
| Google Play Developer | einmalig | 22 € (Jahr 1) | One-Time |
| Marken-DPMA "CanLogistics" | einmalig | 290 € (Jahr 1) | 10 Jahre Schutz |
| Steuerberater (Kleinbetrieb) | jährlich | 500 € | Variabel |
| Supabase Pro-Base | monatlich | 276 € | $25/Mo × 12 |
| **Pflicht-Jahres-Total Jahr 1** | | **~1 256 €** | |
| **Pflicht-Jahres-Total Jahr 2+** | | **~944 €** | (Marken-/Play-Fees einmalig weg) |

## 5 · Worst-Case-Variable-Kosten pro User

Aus [PRICING.md §5](PRICING.md) zusammengefasst — Worst-Case bedeutet
„User reizt alle Quotas seines Tiers zu 100 % aus über 12 Monate":

| Tier | Variable Backend-Kosten/Mo | + Stripe-Fee | **Effektive Kosten/Mo** |
|---|---|---|---|
| Free | 0 € | 0 € | **0 €** |
| Privat-Solo (€4,99) | 0,50 € | 0,32 € | **0,82 €** |
| Privat-Pro (€9,99) | 1,00 € | 0,39 € | **1,39 €** |
| Enterprise-Team (€19,99 netto) | 2,00 € | 0,53 € | **2,53 €** |
| Enterprise-Business (€49,99 netto) | 5,00 € | 0,95 € | **5,95 €** |
| Enterprise-Ultimate (€99,99 netto) | 10,00 € | 1,65 € | **11,65 €** |

## 6 · Steuerliche Behandlung in DE

| Posten | USt-Pflicht | Vorsteuer-Abzug |
|---|---|---|
| Supabase / GitHub / Apple / Google (US/IE) | Reverse-Charge (kein USt-Ausweis) | Nicht relevant für Kleinunternehmer |
| Domain (Namecheap/Cloudflare) | dito | dito |
| DPMA-Marken-Anmeldung (DE) | umsatzsteuerfrei (Behörde) | – |
| Steuerberater (DE) | + 19 % USt | abziehbar wenn USt-pflichtig |
| **Empfehlung** | Kleinunternehmer-Regelung §19 UStG nutzen, solange Jahresumsatz < 25 000 € | Sobald > 25 000 € → Regelbesteuerung wählen, Vorsteuer-Abzug nutzen |

## 7 · Co-Founder- / Investor-View

| KPI | Wert |
|---|---|
| **Cash-Out Jahr 1 (Minimum-Setup)** | ~760 € |
| **Cash-Out Jahr 1 (Empfohlen-Setup)** | ~1 660 € |
| **Cash-Out Jahr 2+ (eingeschwungen)** | ~944 €/Jahr Pflicht + variabel |
| **Break-Even Solo-Tier** | 16 zahlende Solo-User (€4,99 × 12 = €60/Jahr → 16 × 60 = 960 €/Jahr deckt Pflicht-Setup Jahr 2) |
| **Break-Even Enterprise-Tier** | 1 zahlender Enterprise-Ultimate-User (€99,99 × 12 × 0,9 Marge = €1 080/Jahr deckt alles) |

→ **Wirtschaftlich sehr robust** — Pre-Launch-Burn-Rate vernachlässigbar,
selbst kleine User-Base ist Cashflow-positiv.

## 8 · Verweise

- [PRICING.md](PRICING.md) — Tier-Definitionen mit 10×-Marge-Regel
- [README.md](README.md) — Marketing-Ordner-Index
- [../plans/2026-05-17_pricing_restructure_personal_enterprise.md](../plans/2026-05-17_pricing_restructure_personal_enterprise.md) — Implementations-Plan für die 2-Kategorien-Restruktur
