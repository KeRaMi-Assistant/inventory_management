class InventoryItem {
  final String id;
  final String name;
  final String? sku;
  final String? ean;
  final int quantity;
  final int minStock;
  final String? location;
  final double? costPrice;
  final DateTime? arrivalDate;
  final int? dealId;
  final String? supplierId;
  final String? ticketNumber;
  final String? ticketUrl;
  final String? note;
  final String status;

  const InventoryItem({
    required this.id,
    required this.name,
    this.sku,
    this.ean,
    required this.quantity,
    this.minStock = 0,
    this.location,
    this.costPrice,
    this.arrivalDate,
    this.dealId,
    this.supplierId,
    this.ticketNumber,
    this.ticketUrl,
    this.note,
    this.status = 'Im Lager',
  });

  bool get isCritical => quantity < minStock;
  double get stockValue => (costPrice ?? 0) * quantity;

  // ── Local backup JSON (camelCase) ─────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sku': sku,
        'ean': ean,
        'quantity': quantity,
        'minStock': minStock,
        'location': location,
        'costPrice': costPrice,
        'arrivalDate': arrivalDate?.toIso8601String(),
        'dealId': dealId,
        'supplierId': supplierId,
        'ticketNumber': ticketNumber,
        'ticketUrl': ticketUrl,
        'note': note,
        'status': status,
      };

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        id: json['id'] as String,
        name: json['name'] as String,
        sku: json['sku'] as String?,
        ean: json['ean'] as String?,
        quantity: json['quantity'] as int? ?? 0,
        minStock: json['minStock'] as int? ?? 0,
        location: json['location'] as String?,
        costPrice: (json['costPrice'] as num?)?.toDouble(),
        arrivalDate: json['arrivalDate'] != null
            ? DateTime.parse(json['arrivalDate'] as String)
            : null,
        dealId: json['dealId'] as int?,
        supplierId: json['supplierId'] as String?,
        ticketNumber: json['ticketNumber'] as String?,
        ticketUrl: json['ticketUrl'] as String?,
        note: json['note'] as String?,
        status: json['status'] as String? ?? 'Im Lager',
      );

  // ── Supabase (snake_case) ─────────────────────────────────────────────────

  Map<String, dynamic> toSupabaseInsert() => {
        'id': id,
        'name': name,
        'sku': sku,
        'ean': ean,
        'quantity': quantity,
        'min_stock': minStock,
        'location': location,
        'cost_price': costPrice,
        'arrival_date': arrivalDate?.toIso8601String(),
        'deal_id': dealId,
        'supplier_id': supplierId,
        'ticket_number': ticketNumber,
        'ticket_url': ticketUrl,
        'note': note,
        'status': status,
      };

  factory InventoryItem.fromSupabase(Map<String, dynamic> row) => InventoryItem(
        id: row['id'] as String,
        name: row['name'] as String,
        sku: row['sku'] as String?,
        ean: row['ean'] as String?,
        quantity: (row['quantity'] as num?)?.toInt() ?? 0,
        minStock: (row['min_stock'] as num?)?.toInt() ?? 0,
        location: row['location'] as String?,
        costPrice: (row['cost_price'] as num?)?.toDouble(),
        arrivalDate: row['arrival_date'] != null
            ? DateTime.parse(row['arrival_date'] as String)
            : null,
        dealId: (row['deal_id'] as num?)?.toInt(),
        supplierId: row['supplier_id'] as String?,
        ticketNumber: row['ticket_number'] as String?,
        ticketUrl: row['ticket_url'] as String?,
        note: row['note'] as String?,
        status: row['status'] as String? ?? 'Im Lager',
      );

  InventoryItem copyWith({
    String? id,
    String? name,
    Object? sku = _sentinel,
    Object? ean = _sentinel,
    int? quantity,
    int? minStock,
    Object? location = _sentinel,
    Object? costPrice = _sentinel,
    Object? arrivalDate = _sentinel,
    Object? dealId = _sentinel,
    Object? supplierId = _sentinel,
    Object? ticketNumber = _sentinel,
    Object? ticketUrl = _sentinel,
    Object? note = _sentinel,
    String? status,
  }) =>
      InventoryItem(
        id: id ?? this.id,
        name: name ?? this.name,
        sku: sku == _sentinel ? this.sku : sku as String?,
        ean: ean == _sentinel ? this.ean : ean as String?,
        quantity: quantity ?? this.quantity,
        minStock: minStock ?? this.minStock,
        location:
            location == _sentinel ? this.location : location as String?,
        costPrice:
            costPrice == _sentinel ? this.costPrice : costPrice as double?,
        arrivalDate: arrivalDate == _sentinel
            ? this.arrivalDate
            : arrivalDate as DateTime?,
        dealId: dealId == _sentinel ? this.dealId : dealId as int?,
        supplierId: supplierId == _sentinel
            ? this.supplierId
            : supplierId as String?,
        ticketNumber: ticketNumber == _sentinel
            ? this.ticketNumber
            : ticketNumber as String?,
        ticketUrl:
            ticketUrl == _sentinel ? this.ticketUrl : ticketUrl as String?,
        note: note == _sentinel ? this.note : note as String?,
        status: status ?? this.status,
      );
}

class InventoryMovement {
  final String id;
  final String itemId;
  final DateTime date;
  final int quantityChange;
  final String reason;
  final int? dealId;
  final String? ticketNumber;
  final String? note;

  const InventoryMovement({
    required this.id,
    required this.itemId,
    required this.date,
    required this.quantityChange,
    required this.reason,
    this.dealId,
    this.ticketNumber,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'itemId': itemId,
        'date': date.toIso8601String(),
        'quantityChange': quantityChange,
        'reason': reason,
        'dealId': dealId,
        'ticketNumber': ticketNumber,
        'note': note,
      };

  factory InventoryMovement.fromJson(Map<String, dynamic> json) =>
      InventoryMovement(
        id: json['id'] as String,
        itemId: json['itemId'] as String,
        date: DateTime.parse(json['date'] as String),
        quantityChange: json['quantityChange'] as int? ?? 0,
        reason: json['reason'] as String? ?? 'Korrektur',
        dealId: json['dealId'] as int?,
        ticketNumber: json['ticketNumber'] as String?,
        note: json['note'] as String?,
      );

  // ── Supabase (snake_case) ─────────────────────────────────────────────────

  Map<String, dynamic> toSupabaseInsert() => {
        'id': id,
        'item_id': itemId,
        'date': date.toIso8601String(),
        'quantity_change': quantityChange,
        'reason': reason,
        'deal_id': dealId,
        'ticket_number': ticketNumber,
        'note': note,
      };

  factory InventoryMovement.fromSupabase(Map<String, dynamic> row) =>
      InventoryMovement(
        id: row['id'] as String,
        itemId: row['item_id'] as String,
        date: DateTime.parse(row['date'] as String),
        quantityChange: (row['quantity_change'] as num?)?.toInt() ?? 0,
        reason: row['reason'] as String? ?? 'Korrektur',
        dealId: (row['deal_id'] as num?)?.toInt(),
        ticketNumber: row['ticket_number'] as String?,
        note: row['note'] as String?,
      );
}

const Object _sentinel = Object();
