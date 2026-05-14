import '../models/inbox_message.dart';
import '../models/tracking_confidence.dart';

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

  /// Entscheidet, ob [newTracking] auf den Deal geschrieben werden soll.
  ///
  /// Regeln (in Priorität):
  /// 1. [currentTracking] ist null/leer → **immer schreiben** (alter Default).
  /// 2. [currentConfidence] == `manual` → **NIE überschreiben** (User-Eingabe
  ///    ist heilig).
  /// 3. [currentNeedsReview] == true UND [newConfidence] == `strong`
  ///    → **überschreiben** (korrigiert bekannt-schlechten Wert).
  /// 4. [currentConfidence] == `strong` UND [newConfidence] == `strong` UND
  ///    Werte unterschiedlich → **skip** (Konflikt, alten Wert behalten).
  /// 5. Sonst kein Downgrade → **skip**.
  static bool shouldWriteTracking({
    required String? currentTracking,
    required TrackingConfidence? currentConfidence,
    required bool currentNeedsReview,
    required String? newTracking,
    required TrackingConfidence? newConfidence,
  }) {
    // Kein neuer Wert — nichts zu schreiben.
    if (newTracking == null || newTracking.isEmpty) return false;

    // Regel 1: aktuell leer → immer schreiben (unabhängig von confidence).
    if (currentTracking == null || currentTracking.isEmpty) return true;

    // Regel 2: manual ist sakrosankt.
    if (currentConfidence == TrackingConfidence.manual) return false;

    // Regel 3: needs_review + neuer strong → Korrektur erlaubt.
    if (currentNeedsReview && newConfidence == TrackingConfidence.strong) {
      return true;
    }

    // Regel 4: Beide strong, aber unterschiedliche Werte → Konflikt, skip.
    if (currentConfidence == TrackingConfidence.strong &&
        newConfidence == TrackingConfidence.strong &&
        currentTracking != newTracking) {
      // Warn-Log: zwei Strong-Quellen widersprechen sich.
      // ignore: avoid_print
      print(
        '[InboxMatchService] Tracking-Konflikt: '
        'current=$currentTracking vs new=$newTracking — behalte alten Wert.',
      );
      return false;
    }

    // Regel 5: kein Upgrade durch schwächere Confidence → skip.
    return false;
  }

  /// Berechnet die Felder, die auf den Deal geschrieben werden sollen.
  ///
  /// Tracking-Forward-Only mit Confidence-Logik:
  ///   - `tracking` nur wenn [shouldWriteTracking] true ergibt.
  ///   - `arrival_date` nur wenn aktuell leer.
  ///   - `status` nur wenn der neue Rank > alter Rank ist.
  ///
  /// [currentTrackingConfidence] und [currentTrackingNeedsReview] werden für
  /// die neue Tracking-Schreib-Logik benötigt; sie werden aus dem Deal
  /// übergeben und dürfen `null`/`false` sein (Legacy-Deals).
  ///
  /// `mailReceivedAt` wird verwendet, wenn die Mail "delivered" ist, aber
  /// keine explizite ETA mitliefert — dann gilt das Mail-Empfangsdatum
  /// als Lieferdatum.
  static DealUpdateDiff computeDealUpdate({
    required String currentStatus,
    required String? currentTracking,
    required DateTime? currentArrivalDate,
    String? parsedTracking,
    TrackingConfidence? parsedConfidence,
    SuggestionShipStatus? parsedShipStatus,
    DateTime? parsedEta,
    DateTime? mailReceivedAt,
    // Legacy-Felder, die bisher nicht übergeben wurden, bleiben optional.
    TrackingConfidence? currentTrackingConfidence,
    bool currentTrackingNeedsReview = false,
  }) {
    final updates = <String, Object?>{};
    final changes = <String>[];

    final writeTracking = shouldWriteTracking(
      currentTracking: currentTracking,
      currentConfidence: currentTrackingConfidence,
      currentNeedsReview: currentTrackingNeedsReview,
      newTracking: parsedTracking,
      newConfidence: parsedConfidence,
    );

    if (writeTracking && parsedTracking != null) {
      updates['tracking'] = parsedTracking;
      // Schreibe confidence + review-Flag nur wenn confidence gesetzt.
      if (parsedConfidence != null) {
        updates['tracking_confidence'] = parsedConfidence.toJson();
        updates['tracking_needs_review'] = false;
      }
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
      changes.add(
        'Lieferdatum ${arrival.toUtc().toIso8601String().substring(0, 10)}',
      );
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
