---
slug: tests-services-coverage
priority: 9
plan: false
budget_usd: 5
---

Test-Coverage für Service-Layer ausbauen, Ziel: ≥30% in dem Lauf.

Vorgehen:
1. `find lib/services -name '*.dart'` — Liste aller Services.
2. Pro Service prüfen, ob `test/services/<name>_test.dart` existiert.
3. Für die 5 wichtigsten ohne Test: Happy-Path + 2 Edge-Cases schreiben.
   Mock-Daten ohne externe Mock-Pakete (Plain Dart-Klassen die das
   Service-Interface nachbauen).

Priorisierung (nach Reseller-Workflow-Wert):
1. `inventory_calculator_service.dart` (Profit-Berechnung)
2. `pricing_service.dart` (VK-Vorschläge)
3. `tax_service.dart` (USt-Logik)
4. `tracking_service.dart` (Carrier-Detection — bereits Tests, ergänzen)
5. `notification_service.dart` (Push-Routing)

Pro Test:
- Pure-Dart, keine Flutter-Widget-Tree-Abhängigkeit
- Keine Live-Supabase-Calls — Repository als Konstruktor-Parameter
  injizieren, Mock-Repo lokal definieren
- 1 Happy-Path + 2 Edge-Cases (z.B. leere Eingabe, Negativ-Werte,
  Decimal-Rundung)

Coverage messen am Ende:
```bash
flutter test --coverage
lcov --summary coverage/lcov.info | grep services/
```

Wenn unter 30%: weitere Tests bis Schwelle erreicht. Wenn 5 Services
abgedeckt sind und Coverage immer noch <30%: dokumentiere im Run-Log,
welche Services als nächstes drankommen.

`flutter analyze` + `flutter test` müssen grün sein.
