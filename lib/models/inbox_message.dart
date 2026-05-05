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

/// Vom Parser erkannter, noch nicht akzeptierter Deal-Vorschlag.
class PendingDealSuggestion {
  final String id;
  final String workspaceId;
  final String parsedMessageId;
  final String shopKey;
  final String? shopLabel;
  final String? orderId;
  final String? product;
  final int quantity;
  final double? total;
  final String currency;
  final String? tracking;
  final String? carrier;
  final DateTime? eta;
  final DateTime createdAt;
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
    this.shopLabel,
    this.orderId,
    this.product,
    this.total,
    this.tracking,
    this.carrier,
    this.eta,
    this.resolvedAt,
    this.resolvedAction,
    this.createdDealId,
  });

  factory PendingDealSuggestion.fromSupabase(Map<String, dynamic> row) =>
      PendingDealSuggestion(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        parsedMessageId: row['parsed_message_id'] as String,
        shopKey: row['shop_key'] as String,
        shopLabel: row['shop_label'] as String?,
        orderId: row['order_id'] as String?,
        product: row['product'] as String?,
        quantity: (row['quantity'] as num?)?.toInt() ?? 1,
        total: (row['total'] as num?)?.toDouble(),
        currency: row['currency'] as String? ?? 'EUR',
        tracking: row['tracking'] as String?,
        carrier: row['carrier'] as String?,
        eta: row['eta'] != null
            ? DateTime.parse(row['eta'] as String)
            : null,
        createdAt: DateTime.parse(row['created_at'] as String),
        resolvedAt: row['resolved_at'] != null
            ? DateTime.parse(row['resolved_at'] as String)
            : null,
        resolvedAction: row['resolved_action'] as String?,
        createdDealId: (row['created_deal_id'] as num?)?.toInt(),
      );
}
