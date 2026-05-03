class Deal {
  final int id;
  final String product;
  final int quantity;
  final String shippingType;
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
  final String status;
  final String? lexware;
  final String beleg;
  final String? note;
  final double? taxRate;
  final String currency;
  final List<String> inventoryItemIds;

  const Deal({
    required this.id,
    required this.product,
    required this.quantity,
    required this.shippingType,
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
    this.status = 'Bestellt',
    this.lexware,
    this.beleg = 'Nein',
    this.note,
    this.taxRate,
    this.currency = 'EUR',
    this.inventoryItemIds = const [],
  });

  /// Sentinel id used for deals not yet persisted (server assigns BIGSERIAL).
  static const int unsavedId = 0;

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
        'shippingType': shippingType,
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
        'status': status,
        'lexware': lexware,
        'beleg': beleg,
        'note': note,
        'taxRate': taxRate,
        'currency': currency,
        'inventoryItemIds': inventoryItemIds,
      };

  factory Deal.fromJson(Map<String, dynamic> json) => Deal(
        id: json['id'] as int,
        product: json['product'] as String,
        quantity: json['quantity'] as int,
        shippingType: json['shippingType'] as String,
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
        status: json['status'] as String? ?? 'Bestellt',
        lexware: json['lexware'] as String?,
        beleg: json['beleg'] as String? ?? 'Nein',
        note: json['note'] as String?,
        taxRate: (json['taxRate'] as num?)?.toDouble(),
        currency: json['currency'] as String? ?? 'EUR',
        inventoryItemIds: (json['inventoryItemIds'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );

  // ── Supabase (PostgreSQL, snake_case) ─────────────────────────────────────

  Map<String, dynamic> toSupabaseInsert() => {
        'product': product,
        'quantity': quantity,
        'shipping_type': shippingType,
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
        'status': status,
        'lexware': lexware,
        'beleg': beleg,
        'note': note,
        'tax_rate': taxRate,
        'currency': currency,
      };

  factory Deal.fromSupabase(
    Map<String, dynamic> row, {
    List<String> inventoryItemIds = const [],
  }) =>
      Deal(
        id: (row['id'] as num).toInt(),
        product: row['product'] as String,
        quantity: (row['quantity'] as num).toInt(),
        shippingType: row['shipping_type'] as String,
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
        status: row['status'] as String? ?? 'Bestellt',
        lexware: row['lexware'] as String?,
        beleg: row['beleg'] as String? ?? 'Nein',
        note: row['note'] as String?,
        taxRate: (row['tax_rate'] as num?)?.toDouble(),
        currency: row['currency'] as String? ?? 'EUR',
        inventoryItemIds: inventoryItemIds,
      );

  Deal copyWith({
    int? id,
    String? product,
    int? quantity,
    String? shippingType,
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
    String? status,
    Object? lexware = _sentinel,
    String? beleg,
    Object? note = _sentinel,
    Object? taxRate = _sentinel,
    String? currency,
    List<String>? inventoryItemIds,
  }) =>
      Deal(
        id: id ?? this.id,
        product: product ?? this.product,
        quantity: quantity ?? this.quantity,
        shippingType: shippingType ?? this.shippingType,
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
        status: status ?? this.status,
        lexware: lexware == _sentinel ? this.lexware : lexware as String?,
        beleg: beleg ?? this.beleg,
        note: note == _sentinel ? this.note : note as String?,
        taxRate: taxRate == _sentinel ? this.taxRate : taxRate as double?,
        currency: currency ?? this.currency,
        inventoryItemIds: inventoryItemIds ?? this.inventoryItemIds,
      );
}

const Object _sentinel = Object();
