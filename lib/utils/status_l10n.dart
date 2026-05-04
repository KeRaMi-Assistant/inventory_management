import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

/// Übersetzt die in der DB persistierten Status-Strings (DE-Enum-Werte) in
/// die jeweils aktive Sprache. Die DB-Werte selbst bleiben unverändert
/// "Bestellt" / "Unterwegs" / … damit bestehende Daten und Filter nicht
/// brechen.
String localizeDealStatus(BuildContext context, String dbStatus) {
  final l10n = AppLocalizations.of(context);
  return switch (dbStatus) {
    'Bestellt' => l10n.dealStatusOrdered,
    'Unterwegs' => l10n.dealStatusShipping,
    'Angekommen' => l10n.dealStatusArrived,
    'Rechnung gestellt' => l10n.dealStatusInvoiced,
    'Done' => l10n.dealStatusDone,
    _ => dbStatus,
  };
}

String localizeInventoryStatus(BuildContext context, String dbStatus) {
  final l10n = AppLocalizations.of(context);
  return switch (dbStatus) {
    'Im Lager' => l10n.inventoryStatusInStock,
    'Reserviert' => l10n.inventoryStatusReserved,
    'Versandt' => l10n.inventoryStatusShipped,
    'Verkauft' => l10n.inventoryStatusSold,
    _ => dbStatus,
  };
}
