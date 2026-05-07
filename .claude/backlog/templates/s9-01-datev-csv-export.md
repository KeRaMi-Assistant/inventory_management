---
slug: datev-csv-export
priority: 9
plan: true
budget_usd: 6
---

Neuer Service `lib/services/datev_export_service.dart`:

Exportiert Buchungssätze als DATEV-konforme CSV (Format:
`Umsatz, Soll/Haben, Gegenkonto, Belegdatum, Belegfeld, Buchungstext, USt`).

Konten-Mapping aus `billing_profiles.tax_account_map` (JSONB), Default:
- Erlöse 19%: 8400
- Erlöse 7%: 8300
- Wareneinkauf: 3300

Methoden:
- `exportQuarter(int year, int quarter) -> Future<List<int>>` (UTF-8 BOM CSV)
- `exportYear(int year) -> Future<List<int>>`

UI: neuer Tab in `lib/screens/settings_screen.dart` oder eigener
`tax_export_screen.dart` mit:
- Range-Picker (Quartal / Jahr)
- "CSV exportieren"-Button → `Share.shareXFiles` mit dem File
- Optional: PDF-Begleitschreiben (als zweiter Button, leer wenn schwer)

Tests in `test/services/datev_export_service_test.dart`:
- Quartal mit 5 Deals → CSV hat 5 Zeilen + Header
- Cents-Rundung korrekt
- USt-Spalte enthält "19" oder "7" je nach Item

l10n-Keys: `tax_export_*` (DE + EN).

Mobile-First-Pflicht: Range-Picker als Bottom-Sheet auf Phone, nicht
Dialog.
