import 'live_tracking_status.dart';
import 'tracking_confidence.dart';

class Deal {
  final int id;
  final String product;
  final int quantity;
  final bool isDropship;
  final String shop;
  final DateTime orderDate;
  final double? ekNetto;
  final double? ekBrutto;
  final double? vk;
  final String? buyer;
  final String? ticketNumber;
  final String? ticketUrl;
  final String? tracking;
  final DateTime? arrivalDate;
  final DateTime? shippedAt;
  final String status;
  final String? lexware;
  final bool hasReceipt;
  final String? note;
  final double? taxRate;
  final String currency;
  final List<String> inventoryItemIds;
  final List<String> attachmentPaths;

  /// Confidence-Stufe der zuletzt geschriebenen Tracking-Nummer.
  /// `null` = Legacy-Deal vor der Confidence-Migration (behandle wie `none`).
  final TrackingConfidence? trackingConfidence;

  /// `true` wenn die Tracking-Nummer als unzuverlässig markiert ist und vom
  /// User oder Re-Parse korrigiert werden sollte.
  final bool trackingNeedsReview;

  /// Carrier der Sendung, gesetzt vom Detection-Algorithmus oder manuell.
  /// Lowercase: `'dhl'` | `'amazon'` | `'dpd'` | `null`.
  /// `null` = kein Carrier erkannt oder Legacy-Deal.
  final String? carrier;

  /// Live-Status der Sendung, befüllt vom `tracking-poll`-Adapter.
  /// `null` = Legacy-Deal oder noch nie gepollt.
  final LiveTrackingStatus? liveStatus;

  /// Letztes Carrier-Event als Freitext (z.B. "Out for delivery, Berlin").
  /// `null` wenn kein Event bekannt.
  final String? liveStatusLastEvent;

  /// Zeitpunkt des letzten Live-Status-Updates.
  /// `null` wenn noch nie gepollt.
  final DateTime? liveStatusUpdatedAt;

  const Deal({
    required this.id,
    required this.product,
    required this.quantity,
    required this.isDropship,
    required this.shop,
    required this.orderDate,
    this.ekNetto,
    this.ekBrutto,
    this.vk,
    this.buyer,
    this.ticketNumber,
    this.ticketUrl,
    this.tracking,
    this.arrivalDate,
    this.shippedAt,
    this.status = 'Bestellt',
    this.lexware,
    this.hasReceipt = false,
    this.note,
    this.taxRate,
    this.currency = 'EUR',
    this.inventoryItemIds = const [],
    this.attachmentPaths = const [],
    this.trackingConfidence,
    this.trackingNeedsReview = false,
    this.carrier,
    this.liveStatus,
    this.liveStatusLastEvent,
    this.liveStatusUpdatedAt,
  });

  /// Sentinel id used for deals not yet persisted (server assigns BIGSERIAL).
  static const int unsavedId = 0;

  /// Display label for the German UI.
  String get shippingType => isDropship ? 'Dropship' : 'Reship';

  /// Display label for the German UI.
  String get belegLabel => hasReceipt ? 'Ja' : 'Nein';

  double? get profitPerUnit =>
      (vk != null && ekBrutto != null) ? vk! - ekBrutto! : null;
  double? get totalProfit =>
      (profitPerUnit != null) ? quantity * profitPerUnit! : null;
  double? get zuBekommen => vk != null ? vk! * quantity : null;
  double? get ekGesamtNetto => ekNetto != null ? ekNetto! * quantity : null;
  double? get ekGesamtBrutto => ekBrutto != null ? ekBrutto! * quantity : null;

  /// Aus Netto + taxRate berechneter Bruttopreis (pro Einheit). Fällt auf
  /// `ekBrutto` zurück, wenn keine Steuerangabe vorliegt.
  double? get ekNettoPlusMwst {
    if (ekNetto != null && taxRate != null) {
      return ekNetto! * (1 + taxRate!);
    }
    return ekBrutto;
  }

  // ── Local backup JSON (camelCase) ─────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'product': product,
        'quantity': quantity,
        'isDropship': isDropship,
        'shop': shop,
        'orderDate': orderDate.toIso8601String(),
        'ekNetto': ekNetto,
        'ekBrutto': ekBrutto,
        'vk': vk,
        'buyer': buyer,
        'ticketNumber': ticketNumber,
        'ticketUrl': ticketUrl,
        'tracking': tracking,
        'arrivalDate': arrivalDate?.toIso8601String(),
        'shippedAt': shippedAt?.toIso8601String(),
        'status': status,
        'lexware': lexware,
        'hasReceipt': hasReceipt,
        'note': note,
        'taxRate': taxRate,
        'currency': currency,
        'inventoryItemIds': inventoryItemIds,
        'attachmentPaths': attachmentPaths,
        'trackingConfidence': trackingConfidence?.toJson(),
        'trackingNeedsReview': trackingNeedsReview,
        'carrier': carrier,
        'liveStatus': liveStatus?.toJson(),
        'liveStatusLastEvent': liveStatusLastEvent,
        'liveStatusUpdatedAt': liveStatusUpdatedAt?.toIso8601String(),
      };

  factory Deal.fromJson(Map<String, dynamic> json) => Deal(
        id: json['id'] as int,
        product: json['product'] as String,
        quantity: json['quantity'] as int,
        isDropship: _readDropship(json['isDropship'], json['shippingType']),
        shop: json['shop'] as String,
        orderDate: DateTime.parse(json['orderDate'] as String),
        ekNetto: (json['ekNetto'] as num?)?.toDouble(),
        ekBrutto: (json['ekBrutto'] as num?)?.toDouble(),
        vk: (json['vk'] as num?)?.toDouble(),
        buyer: json['buyer'] as String?,
        ticketNumber: json['ticketNumber'] as String?,
        ticketUrl: json['ticketUrl'] as String?,
        tracking: json['tracking'] as String?,
        arrivalDate: json['arrivalDate'] != null
            ? DateTime.parse(json['arrivalDate'] as String)
            : null,
        shippedAt: json['shippedAt'] != null
            ? DateTime.parse(json['shippedAt'] as String)
            : null,
        status: json['status'] as String? ?? 'Bestellt',
        lexware: json['lexware'] as String?,
        hasReceipt: _readReceipt(json['hasReceipt'], json['beleg']),
        note: json['note'] as String?,
        taxRate: (json['taxRate'] as num?)?.toDouble(),
        currency: json['currency'] as String? ?? 'EUR',
        inventoryItemIds: (json['inventoryItemIds'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        attachmentPaths: (json['attachmentPaths'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        trackingConfidence:
            TrackingConfidence.fromString(json['trackingConfidence'] as String?),
        trackingNeedsReview: json['trackingNeedsReview'] as bool? ?? false,
        carrier: json['carrier'] as String?,
        liveStatus:
            LiveTrackingStatus.fromString(json['liveStatus'] as String?),
        liveStatusLastEvent: json['liveStatusLastEvent'] as String?,
        liveStatusUpdatedAt: json['liveStatusUpdatedAt'] != null
            ? DateTime.parse(json['liveStatusUpdatedAt'] as String)
            : null,
      );

  // ── Supabase (PostgreSQL, snake_case) ─────────────────────────────────────

  Map<String, dynamic> toSupabaseInsert() => {
        'product': product,
        'quantity': quantity,
        'is_dropship': isDropship,
        'shop': shop,
        'order_date': orderDate.toIso8601String(),
        'ek_netto': ekNetto,
        'ek_brutto': ekBrutto,
        'vk': vk,
        'buyer': buyer,
        'ticket_number': ticketNumber,
        'ticket_url': ticketUrl,
        'tracking': tracking,
        'arrival_date': arrivalDate?.toIso8601String(),
        'shipped_at': shippedAt?.toIso8601String(),
        'status': status,
        'lexware': lexware,
        'has_receipt': hasReceipt,
        'note': note,
        'tax_rate': taxRate,
        'currency': currency,
        'attachment_paths': attachmentPaths,
        'tracking_confidence': trackingConfidence?.toJson(),
        'tracking_needs_review': trackingNeedsReview,
        'carrier': carrier,
        'live_status': liveStatus?.toJson(),
        'live_status_last_event': liveStatusLastEvent,
        'live_status_updated_at': liveStatusUpdatedAt?.toIso8601String(),
      };

  factory Deal.fromSupabase(
    Map<String, dynamic> row, {
    List<String> inventoryItemIds = const [],
  }) {
    final raw = row['attachment_paths'];
    final paths =
        raw is List ? raw.map((e) => e.toString()).toList() : <String>[];
    return Deal(
      id: (row['id'] as num).toInt(),
      product: row['product'] as String,
      quantity: (row['quantity'] as num).toInt(),
      isDropship: _readDropship(row['is_dropship'], row['shipping_type']),
      shop: row['shop'] as String,
      orderDate: DateTime.parse(row['order_date'] as String),
      ekNetto: (row['ek_netto'] as num?)?.toDouble(),
      ekBrutto: (row['ek_brutto'] as num?)?.toDouble(),
      vk: (row['vk'] as num?)?.toDouble(),
      buyer: row['buyer'] as String?,
      ticketNumber: row['ticket_number'] as String?,
      ticketUrl: row['ticket_url'] as String?,
      tracking: row['tracking'] as String?,
      arrivalDate: row['arrival_date'] != null
          ? DateTime.parse(row['arrival_date'] as String)
          : null,
      shippedAt: row['shipped_at'] != null
          ? DateTime.parse(row['shipped_at'] as String)
          : null,
      status: row['status'] as String? ?? 'Bestellt',
      lexware: row['lexware'] as String?,
      hasReceipt: _readReceipt(row['has_receipt'], row['beleg']),
      note: row['note'] as String?,
      taxRate: (row['tax_rate'] as num?)?.toDouble(),
      currency: row['currency'] as String? ?? 'EUR',
      inventoryItemIds: inventoryItemIds,
      attachmentPaths: paths,
      trackingConfidence:
          TrackingConfidence.fromString(row['tracking_confidence'] as String?),
      trackingNeedsReview: row['tracking_needs_review'] as bool? ?? false,
      carrier: row['carrier'] as String?,
      liveStatus:
          LiveTrackingStatus.fromString(row['live_status'] as String?),
      liveStatusLastEvent: row['live_status_last_event'] as String?,
      liveStatusUpdatedAt: row['live_status_updated_at'] != null
          ? DateTime.parse(row['live_status_updated_at'] as String)
          : null,
    );
  }

  /// Accepts the new boolean OR the legacy "Reship"/"Dropship" string so
  /// pre-migration JSON backups and rows still hydrate cleanly.
  static bool _readDropship(dynamic boolValue, dynamic legacyString) {
    if (boolValue is bool) return boolValue;
    if (legacyString is String) return legacyString.toLowerCase() == 'dropship';
    return false;
  }

  /// Accepts the new boolean OR the legacy "Ja"/"Nein" string.
  static bool _readReceipt(dynamic boolValue, dynamic legacyString) {
    if (boolValue is bool) return boolValue;
    if (legacyString is String) return legacyString.toLowerCase() == 'ja';
    return false;
  }

  Deal copyWith({
    int? id,
    String? product,
    int? quantity,
    bool? isDropship,
    String? shop,
    DateTime? orderDate,
    Object? ekNetto = _sentinel,
    Object? ekBrutto = _sentinel,
    Object? vk = _sentinel,
    Object? buyer = _sentinel,
    Object? ticketNumber = _sentinel,
    Object? ticketUrl = _sentinel,
    Object? tracking = _sentinel,
    Object? arrivalDate = _sentinel,
    Object? shippedAt = _sentinel,
    String? status,
    Object? lexware = _sentinel,
    bool? hasReceipt,
    Object? note = _sentinel,
    Object? taxRate = _sentinel,
    String? currency,
    List<String>? inventoryItemIds,
    List<String>? attachmentPaths,
    Object? trackingConfidence = _sentinel,
    bool? trackingNeedsReview,
    Object? carrier = _sentinel,
    Object? liveStatus = _sentinel,
    Object? liveStatusLastEvent = _sentinel,
    Object? liveStatusUpdatedAt = _sentinel,
  }) =>
      Deal(
        id: id ?? this.id,
        product: product ?? this.product,
        quantity: quantity ?? this.quantity,
        isDropship: isDropship ?? this.isDropship,
        shop: shop ?? this.shop,
        orderDate: orderDate ?? this.orderDate,
        ekNetto: ekNetto == _sentinel ? this.ekNetto : ekNetto as double?,
        ekBrutto:
            ekBrutto == _sentinel ? this.ekBrutto : ekBrutto as double?,
        vk: vk == _sentinel ? this.vk : vk as double?,
        buyer: buyer == _sentinel ? this.buyer : buyer as String?,
        ticketNumber: ticketNumber == _sentinel
            ? this.ticketNumber
            : ticketNumber as String?,
        ticketUrl: ticketUrl == _sentinel ? this.ticketUrl : ticketUrl as String?,
        tracking:
            tracking == _sentinel ? this.tracking : tracking as String?,
        arrivalDate: arrivalDate == _sentinel
            ? this.arrivalDate
            : arrivalDate as DateTime?,
        shippedAt: shippedAt == _sentinel
            ? this.shippedAt
            : shippedAt as DateTime?,
        status: status ?? this.status,
        lexware: lexware == _sentinel ? this.lexware : lexware as String?,
        hasReceipt: hasReceipt ?? this.hasReceipt,
        note: note == _sentinel ? this.note : note as String?,
        taxRate: taxRate == _sentinel ? this.taxRate : taxRate as double?,
        currency: currency ?? this.currency,
        inventoryItemIds: inventoryItemIds ?? this.inventoryItemIds,
        attachmentPaths: attachmentPaths ?? this.attachmentPaths,
        trackingConfidence: trackingConfidence == _sentinel
            ? this.trackingConfidence
            : trackingConfidence as TrackingConfidence?,
        trackingNeedsReview: trackingNeedsReview ?? this.trackingNeedsReview,
        carrier: carrier == _sentinel ? this.carrier : carrier as String?,
        liveStatus: liveStatus == _sentinel
            ? this.liveStatus
            : liveStatus as LiveTrackingStatus?,
        liveStatusLastEvent: liveStatusLastEvent == _sentinel
            ? this.liveStatusLastEvent
            : liveStatusLastEvent as String?,
        liveStatusUpdatedAt: liveStatusUpdatedAt == _sentinel
            ? this.liveStatusUpdatedAt
            : liveStatusUpdatedAt as DateTime?,
      );
}

const Object _sentinel = Object();
