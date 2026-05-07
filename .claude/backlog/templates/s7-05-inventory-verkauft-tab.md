---
slug: inventory-verkauft-tab
priority: 7
plan: true
budget_usd: 5
---

In `lib/screens/inventory_screen.dart`: "Verkauft"-Filter wird zum
**eigenen primären Tab**, nicht mehr nur eine Filter-Option.

Tab-Layout:
- **Lager** (status NOT IN ('Verkauft','Versandt'))
- **Verkauft** (status IN ('Verkauft','Versandt'))

Verkauft-Tab-Header: eigener Bereich oben mit
- Anzahl verkaufter Items
- Gesamt-Profit (sum(VK) − sum(EK))
- Top-3-Käufer (mit Anzahl Items)

Mobile-First-Pflicht (s. CLAUDE.md):
- Tab-Switcher als Material-TabBar oder CupertinoSegmentedControl,
  je nach Plattform-Look.
- Header-Cards horizontal scrollbar wenn Phone, Grid auf Tablet.

`flutter analyze` + `flutter test` müssen grün sein.
