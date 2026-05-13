/// Confidence-Stufe einer erkannten Tracking-Nummer.
///
/// Werte entsprechen dem DB-CHECK-Constraint auf `deals.tracking_confidence`:
///   `CHECK (tracking_confidence IN ('strong','manual','none'))`.
///
/// `pending_deal_suggestions.tracking_confidence` kennt nur `'strong'` und
/// `'none'` (kein `manual`).
enum TrackingConfidence {
  /// Strukturell validierte Tracking-Nummer aus einem Carrier-URL oder einem
  /// Anchor-gebundenen Strong-Pattern.
  strong,

  /// Vom User manuell eingegebene Tracking-Nummer. Niemals maschinell
  /// überschreiben.
  manual,

  /// Keine verifizierte Tracking-Nummer erkannt.
  none;

  static TrackingConfidence? fromString(String? s) => switch (s) {
        'strong' => TrackingConfidence.strong,
        'manual' => TrackingConfidence.manual,
        'none' => TrackingConfidence.none,
        _ => null,
      };

  String? toJson() => name;
}
