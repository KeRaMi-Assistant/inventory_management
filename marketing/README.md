# CanLogistics — Marketing & Business

Dieser Ordner ist die **Single-Source-of-Truth** für alles Geld-,
Pricing-, Positioning- und Sales-Bezogene rund um CanLogistics.

## Inhalt

| Datei | Was steht drin |
|---|---|
| [COSTS.md](COSTS.md) | Alle Posten (Pflicht-Fixkosten, empfohlene Fixkosten, Live-Betrieb, variable Backend-Kosten, Stripe-Gebühren, zukünftige Kosten, Steuer) |
| [PRICING.md](PRICING.md) | 6 Tiers in 2 Kategorien (Privat + Enterprise), mit Worst-Case-Kalkulation pro Tier nach 10×-Marge-Regel |

## Quick-Summary

### Kosten

| Posten | Pre-Launch | Jahr 2+ |
|---|---|---|
| Pflicht-Fixkosten | ~760 € (Jahr 1, inkl. Marke + Apple-Dev) | ~944 €/Jahr |
| Empfohlen-Setup | ~1 660 € | ~1 600 €/Jahr |
| Variable User-Kosten | n/a | 0,10 – 12,45 €/User/Monat |

→ Vollständige Liste mit Anbietern + Quellen siehe [COSTS.md](COSTS.md).

### Pricing (Stand 2026-05-20)

| Kategorie | Tier | Preis | Worst-Case-Kosten | Marge |
|---|---|---|---|---|
| **Privat** (brutto inkl. 19 % MwSt) | Free | 0 € | 0 € | – |
| | Solo | 4,99 €/Mo | 0,92 € | 82 % |
| | **Solo Pro** | **14,99 €/Mo** | 1,51 € | **90 %** |
| **Enterprise** (netto excl. MwSt) | Team | 19,99 €/Mo | 2,53 € | 87 % |
| | Business | 49,99 €/Mo | 5,95 € | 88 % |
| | Enterprise | 99,99 €/Mo | 12,45 € | 88 % |

UI-Layout: **Tabs** (links Privat, rechts Enterprise) statt
übereinandergestapelter Sektionen. Yearly-Toggle zeigt den
effektiven Monatspreis prominent, Jahres-Total klein ausgegraut.

**Feature-Disziplin (2026-05-20):** Pricing-Highlights listen nur
Features die heute im Code existieren oder explizit als „(geplant)"
markiert sind. Keine spekulativen Versprechen wie AI-Kategorisierung,
Premium-Carrier-Adapter, Custom-Branding, SSO, White-Label — alle
entfernt oder als „(geplant)" gekennzeichnet.

→ Komplette Quotas + Feature-Matrix siehe [PRICING.md](PRICING.md).

### Wirtschaftlichkeit Jahr 1

| KPI | Wert |
|---|---|
| Break-Even (Minimum-Pflicht-Setup) | **16 Solo-User** oder **1 Enterprise-Ultimate-User** |
| Burn-Rate Pre-Launch (Cash-Out) | ~63 €/Monat (Pflicht-Anteil amortisiert) |
| Worst-Case-Margin Enterprise | 87,5 % (€87,54 Gewinn pro €99,99 Tier) |
| Median-Margin alle Paid-Tiers | 97–98 % |

## Verwandt im Repo

- [../plans/2026-05-17_pricing_restructure_personal_enterprise.md](../plans/2026-05-17_pricing_restructure_personal_enterprise.md) — Implementations-Plan
- [../lib/models/pricing_plan.dart](../lib/models/pricing_plan.dart) — Code-Definition der Tiers (Single-Source für Quota-Checks)
- [../lib/models/billing_profile.dart](../lib/models/billing_profile.dart) — `BillingPlan`-Enum

## Pflege

- Bei Tier-Änderung: erst PRICING.md updaten, dann Code, dann ARB.
- Bei neuem Service / neuem Kostenposten: COSTS.md erweitern.
- Bei Stripe-Preis-Änderung: hier UND in Stripe-Dashboard UND im
  zugehörigen DB-Mapping ändern.

**Konventionen:**
- Alle Preise in EUR. USD via Kurs $1 = €0,92 umrechnen, dann
  Original-USD im Kommentar belassen.
- Brutto/Netto immer explizit kennzeichnen.
- Worst-Case- und Median-Annahmen dokumentieren, nicht raten.
