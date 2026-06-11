import 'live_tracking_status.dart';

/// Ein einzelner Carrier-Scan/Event aus `tracking_events` (Klarna-Style-
/// Timeline, Paket 1). Geschrieben ausschließlich vom tracking-poll-Backend;
/// der Client liest workspace-scoped via RLS.
class TrackingEvent {
  final int id;
  final int dealId;

  /// Tracking-Nummer, zu der dieser Event gehört (Multi-Parcel-fähig).
  final String tracking;

  /// Carrier-Id (`'dhl'`, `'dpd'`, …) oder null.
  final String? carrier;

  /// Zeitpunkt des Scans beim Carrier.
  final DateTime occurredAt;

  /// Normalisierter Status zum Event-Zeitpunkt. `null` = nicht zuordenbar.
  final LiveTrackingStatus? status;

  /// Roher Carrier-Code (z.B. DHL `"ZU"`), nur für Debug/Anzeige-Details.
  final String? rawCode;

  /// Event-Text ("In Zustellung", "Im Paketzentrum eingetroffen").
  final String description;

  /// Scan-Ort (Stadt), soweit der Carrier ihn liefert.
  final String? location;

  /// Quelle: `'poll'` | `'mail'` | `'manual'`.
  final String source;

  const TrackingEvent({
    required this.id,
    required this.dealId,
    required this.tracking,
    required this.occurredAt,
    required this.description,
    this.carrier,
    this.status,
    this.rawCode,
    this.location,
    this.source = 'poll',
  });

  factory TrackingEvent.fromSupabase(Map<String, dynamic> row) =>
      TrackingEvent(
        id: (row['id'] as num).toInt(),
        dealId: (row['deal_id'] as num).toInt(),
        tracking: row['tracking'] as String,
        carrier: row['carrier'] as String?,
        occurredAt: DateTime.parse(row['occurred_at'] as String),
        status: LiveTrackingStatus.fromString(row['status'] as String?),
        rawCode: row['raw_code'] as String?,
        description: row['description'] as String? ?? '',
        location: row['location'] as String?,
        source: row['source'] as String? ?? 'poll',
      );
}
