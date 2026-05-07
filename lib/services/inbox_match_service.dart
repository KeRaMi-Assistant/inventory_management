import '../models/inbox_message.dart';

/// Reine Mapping-/Diff-Logik für die "Mail aus dem Postfach updated einen
/// bestehenden Deal"-Pipeline.
///
/// Die Edge-Function `inbox-parse` (Deno/TypeScript) wendet exakt dieselbe
/// Logik an. Wir spiegeln sie hier in Dart, damit
///   1. das UI ("Tracking auf Deal anwenden", Suggestion-Akzeptanz) sich
///      konsistent verhält und
///   2. die Forward-Only-Garantien per `flutter test` abgesichert sind.
///
/// Die Klasse hat keinen State und keine Supabase-Calls — nur Pure
/// Functions, damit Unit-Tests ohne Mocks reichen.
class InboxMatchService {
  InboxMatchService._();

  /// Lifecycle-Reihenfolge der Deal-Status. Höherer Wert = "weiter
  /// fortgeschritten". Wird verwendet, um Status-Downgrades durch
  /// verspätete Mails zu verhindern (Versandbestätigung kommt nach
  /// Zustellungsbenachrichtigung).
  static const Map<String, int> statusRank = {
    'Bestellt': 1,
    'Unterwegs': 2,
    'Angekommen': 3,
    'Rechnung gestellt': 4,
    'Done': 5,
  };

  /// Mappt den vom Mail-Adapter abgeleiteten Versand-Status auf einen
  /// Deal-Status. `null` heißt "Mail liefert keinen Status-Hinweis"
  /// (z.B. reine Bestellbestätigung).
  static String? mapShipStatusToDeal(SuggestionShipStatus? s) {
    switch (s) {
      case SuggestionShipStatus.shipped:
        return 'Unterwegs';
      case SuggestionShipStatus.delivered:
        return 'Angekommen';
      case SuggestionShipStatus.cancelled:
      case SuggestionShipStatus.refunded:
        return 'Done';
      case SuggestionShipStatus.ordered:
      case null:
        return null;
    }
  }

  /// Berechnet die Felder, die auf den Deal geschrieben werden sollen.
  /// Forward-Only-Semantik:
  ///   - `tracking` nur wenn aktuell leer.
  ///   - `arrival_date` nur wenn aktuell leer.
  ///   - `status` nur wenn der neue Rank > alter Rank ist.
  /// `mailReceivedAt` wird verwendet, wenn die Mail "delivered" ist, aber
  /// keine explizite ETA mitliefert — dann gilt das Mail-Empfangsdatum
  /// als Lieferdatum.
  static DealUpdateDiff computeDealUpdate({
    required String currentStatus,
    required String? currentTracking,
    required DateTime? currentArrivalDate,
    String? parsedTracking,
    SuggestionShipStatus? parsedShipStatus,
    DateTime? parsedEta,
    DateTime? mailReceivedAt,
  }) {
    final updates = <String, Object?>{};
    final changes = <String>[];

    if (parsedTracking != null
        && parsedTracking.isNotEmpty
        && (currentTracking == null || currentTracking.isEmpty)) {
      updates['tracking'] = parsedTracking;
      changes.add('Tracking $parsedTracking');
    }

    final target = mapShipStatusToDeal(parsedShipStatus);
    if (target != null) {
      final currentRank = statusRank[currentStatus] ?? 0;
      final newRank = statusRank[target] ?? 0;
      if (newRank > currentRank) {
        updates['status'] = target;
        changes.add('Status $currentStatus → $target');
      }
    }

    DateTime? arrival = parsedEta;
    if (parsedShipStatus == SuggestionShipStatus.delivered && arrival == null) {
      arrival = mailReceivedAt;
    }
    if (arrival != null && currentArrivalDate == null) {
      updates['arrival_date'] = arrival.toUtc().toIso8601String();
      // ISO ohne Uhrzeit für die Aktivitäts-Zeile.
      changes.add('Lieferdatum ${arrival.toUtc().toIso8601String().substring(0, 10)}');
    }

    return DealUpdateDiff(updates: updates, changes: changes);
  }
}

/// Was sich aus einer Mail für einen Deal ändert. Leer wenn die Mail
/// keine relevante Information mitbringt (z.B. doppelt eingegangen oder
/// Bestellbestätigung für einen Deal, der schon weiter fortgeschritten ist).
class DealUpdateDiff {
  final Map<String, Object?> updates;
  final List<String> changes;

  const DealUpdateDiff({required this.updates, required this.changes});

  bool get isEmpty => updates.isEmpty;
  bool get isNotEmpty => updates.isNotEmpty;
}
