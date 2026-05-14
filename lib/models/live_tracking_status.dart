/// Live-Tracking-Status aus dem externen Adapter-Poll.
///
/// Werte entsprechen dem DB-CHECK-Constraint auf `deals.live_status`:
///   `CHECK (live_status IN
///     ('pending','in_transit','out_for_delivery','delivered','exception','expired'))`.
///
/// Adapter (A2) emittiert heute: `in_transit`, `delivered`, `exception`.
/// Die übrigen Werte sind für zukünftige Adapter reserviert.
enum LiveTrackingStatus {
  /// Sendung noch nicht im Carrier-Netz (z.B. Label gedruckt, nicht übergeben).
  pending,

  /// Sendung unterwegs.
  inTransit,

  /// Sendung befindet sich in der letzten Meile (Zustellfahrzeug).
  outForDelivery,

  /// Sendung wurde zugestellt.
  delivered,

  /// Problem mit der Sendung (z.B. Zustellversuch fehlgeschlagen, Zoll).
  exception,

  /// Status zu alt — kein Carrier-Update mehr erhalten.
  expired;

  /// Parst den DB-snake_case-String. Gibt `null` zurück bei unbekanntem Wert.
  static LiveTrackingStatus? fromString(String? s) => switch (s) {
        'pending' => LiveTrackingStatus.pending,
        'in_transit' => LiveTrackingStatus.inTransit,
        'out_for_delivery' => LiveTrackingStatus.outForDelivery,
        'delivered' => LiveTrackingStatus.delivered,
        'exception' => LiveTrackingStatus.exception,
        'expired' => LiveTrackingStatus.expired,
        _ => null,
      };

  /// Serialisiert zurück in den DB-snake_case-String.
  String toJson() => switch (this) {
        LiveTrackingStatus.pending => 'pending',
        LiveTrackingStatus.inTransit => 'in_transit',
        LiveTrackingStatus.outForDelivery => 'out_for_delivery',
        LiveTrackingStatus.delivered => 'delivered',
        LiveTrackingStatus.exception => 'exception',
        LiveTrackingStatus.expired => 'expired',
      };
}
