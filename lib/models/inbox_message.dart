/// Status einer geparsten Mail. Spiegelt den DB-CHECK aus `parsed_messages`.
enum ParsedMessageStatus {
  pending,
  matched,
  suggested,
  unclassified,
  failed,
  dismissed,
}

ParsedMessageStatus _statusFromString(String? value) {
  switch (value) {
    case 'matched':
      return ParsedMessageStatus.matched;
    case 'suggested':
      return ParsedMessageStatus.suggested;
    case 'unclassified':
      return ParsedMessageStatus.unclassified;
    case 'failed':
      return ParsedMessageStatus.failed;
    case 'dismissed':
      return ParsedMessageStatus.dismissed;
    default:
      return ParsedMessageStatus.pending;
  }
}

/// Eine Mail, die `inbox-poll` geholt und `inbox-parse` verarbeitet hat.
/// Volltext-Body bleibt nicht persistent; das Modell enthält nur Header
/// + extrahiertes JSON.
class ParsedMessage {
  final String id;
  final String workspaceId;
  final String accountId;
  final String? fromAddress;
  final String? subject;
  final String? messageId;
  final DateTime receivedAt;
  final String? shopKey;
  final ParsedMessageStatus status;
  final int? matchDealId;
  final Map<String, dynamic>? parsedPayload;
  final String? error;
  final DateTime? processedAt;

  const ParsedMessage({
    required this.id,
    required this.workspaceId,
    required this.accountId,
    required this.receivedAt,
    required this.status,
    this.fromAddress,
    this.subject,
    this.messageId,
    this.shopKey,
    this.matchDealId,
    this.parsedPayload,
    this.error,
    this.processedAt,
  });

  factory ParsedMessage.fromSupabase(Map<String, dynamic> row) => ParsedMessage(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        accountId: row['account_id'] as String,
        fromAddress: row['from_address'] as String?,
        subject: row['subject'] as String?,
        messageId: row['message_id'] as String?,
        receivedAt: DateTime.parse(row['received_at'] as String),
        shopKey: row['shop_key'] as String?,
        status: _statusFromString(row['status'] as String?),
        matchDealId: (row['match_deal_id'] as num?)?.toInt(),
        parsedPayload: row['parsed_payload'] is Map
            ? Map<String, dynamic>.from(row['parsed_payload'] as Map)
            : null,
        error: row['error'] as String?,
        processedAt: row['processed_at'] != null
            ? DateTime.parse(row['processed_at'] as String)
            : null,
      );
}

/// Off-the-wire-Status einer Bestellung, wie der Adapter ihn aus der Mail
/// abgeleitet hat. Wird auf einen Deal-Status gemappt, wenn der User den
/// Vorschlag annimmt.
enum SuggestionShipStatus { ordered, shipped, delivered, cancelled, refunded }

SuggestionShipStatus? _shipStatusFromString(String? v) {
  switch (v) {
    case 'ordered':
      return SuggestionShipStatus.ordered;
    case 'shipped':
      return SuggestionShipStatus.shipped;
    case 'delivered':
      return SuggestionShipStatus.delivered;
    case 'cancelled':
      return SuggestionShipStatus.cancelled;
    case 'refunded':
      return SuggestionShipStatus.refunded;
    default:
      return null;
  }
}

extension SuggestionShipStatusX on SuggestionShipStatus {
  /// Auf den deutschen Deal-Status (App-intern) gemappt.
  String toDealStatus() {
    switch (this) {
      case SuggestionShipStatus.shipped:
        return 'Unterwegs';
      case SuggestionShipStatus.delivered:
        return 'Angekommen';
      case SuggestionShipStatus.cancelled:
      case SuggestionShipStatus.refunded:
        return 'Done';
      case SuggestionShipStatus.ordered:
        return 'Bestellt';
    }
  }

  String label() {
    switch (this) {
      case SuggestionShipStatus.ordered:
        return 'Bestellt';
      case SuggestionShipStatus.shipped:
        return 'Unterwegs';
      case SuggestionShipStatus.delivered:
        return 'Angekommen';
      case SuggestionShipStatus.cancelled:
        return 'Storniert';
      case SuggestionShipStatus.refunded:
        return 'Erstattet';
    }
  }
}

/// Vom Parser erkannter, noch nicht akzeptierter Deal-Vorschlag.
class PendingDealSuggestion {
  final String id;
  final String workspaceId;
  final String parsedMessageId;
  final String? messageId;
  final String shopKey;
  final String? shopLabel;
  final String? orderId;
  final String? product;
  final int quantity;
  final double? total;
  final String currency;
  /// Primäre Tracking-Nr (gleicht trackings.first wenn nicht leer).
  /// Wird auf den Deal angewendet bei "Tracking auf Deal anwenden".
  final String? tracking;

  /// Vollständige, deduplizierte Liste aller Tracking-Nrn dieser Bestellung.
  /// Bei Sammelversand mit einem Tracking → 1 Eintrag. Bei Split-Shipment
  /// auf mehrere Pakete → mehrere.
  final List<String> trackings;
  final String? carrier;
  final DateTime? eta;
  final SuggestionShipStatus? status;
  final DateTime createdAt;
  final DateTime receivedAt;
  final DateTime? resolvedAt;
  final String? resolvedAction;
  final int? createdDealId;

  const PendingDealSuggestion({
    required this.id,
    required this.workspaceId,
    required this.parsedMessageId,
    required this.shopKey,
    required this.quantity,
    required this.currency,
    required this.createdAt,
    required this.receivedAt,
    this.messageId,
    this.shopLabel,
    this.orderId,
    this.product,
    this.total,
    this.tracking,
    this.trackings = const [],
    this.carrier,
    this.eta,
    this.status,
    this.resolvedAt,
    this.resolvedAction,
    this.createdDealId,
  });

  factory PendingDealSuggestion.fromSupabase(Map<String, dynamic> row) {
    final created = DateTime.parse(row['created_at'] as String);
    final trackingsRaw = row['trackings'];
    final trackings = trackingsRaw is List
        ? trackingsRaw.whereType<String>().toList(growable: false)
        : <String>[];
    final primary = row['tracking'] as String?;
    final mergedTrackings = trackings.isEmpty && primary != null
        ? <String>[primary]
        : trackings;
    return PendingDealSuggestion(
      id: row['id'] as String,
      workspaceId: row['workspace_id'] as String,
      parsedMessageId: row['parsed_message_id'] as String,
      messageId: row['message_id'] as String?,
      shopKey: row['shop_key'] as String,
      shopLabel: row['shop_label'] as String?,
      orderId: row['order_id'] as String?,
      product: row['product'] as String?,
      quantity: (row['quantity'] as num?)?.toInt() ?? 1,
      total: (row['total'] as num?)?.toDouble(),
      currency: row['currency'] as String? ?? 'EUR',
      tracking: primary ?? mergedTrackings.firstOrNull,
      trackings: mergedTrackings,
      carrier: row['carrier'] as String?,
      eta: row['eta'] != null
          ? DateTime.parse(row['eta'] as String)
          : null,
      status: _shipStatusFromString(row['status'] as String?),
      createdAt: created,
      receivedAt: row['received_at'] != null
          ? DateTime.parse(row['received_at'] as String)
          : created,
      resolvedAt: row['resolved_at'] != null
          ? DateTime.parse(row['resolved_at'] as String)
          : null,
      resolvedAction: row['resolved_action'] as String?,
      createdDealId: (row['created_deal_id'] as num?)?.toInt(),
    );
  }
}
