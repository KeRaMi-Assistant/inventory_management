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
  final List<String> attachmentPaths;
  final bool isPublic;
  final double? publicPrice;
  final String? publicDescription;

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
    this.attachmentPaths = const [],
    this.isPublic = false,
    this.publicPrice,
    this.publicDescription,
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
        'attachmentPaths': attachmentPaths,
        'isPublic': isPublic,
        'publicPrice': publicPrice,
        'publicDescription': publicDescription,
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
        attachmentPaths: (json['attachmentPaths'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        isPublic: json['isPublic'] as bool? ?? false,
        publicPrice: (json['publicPrice'] as num?)?.toDouble(),
        publicDescription: json['publicDescription'] as String?,
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
        'attachment_paths': attachmentPaths,
        'is_public': isPublic,
        'public_price': publicPrice,
        'public_description': publicDescription,
      };

  factory InventoryItem.fromSupabase(Map<String, dynamic> row) {
    final raw = row['attachment_paths'];
    final paths = raw is List ? raw.map((e) => e.toString()).toList() : <String>[];
    return InventoryItem(
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
      attachmentPaths: paths,
      isPublic: (row['is_public'] as bool?) ?? false,
      publicPrice: (row['public_price'] as num?)?.toDouble(),
      publicDescription: row['public_description'] as String?,
    );
  }

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
    List<String>? attachmentPaths,
    bool? isPublic,
    Object? publicPrice = _sentinel,
    Object? publicDescription = _sentinel,
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
        attachmentPaths: attachmentPaths ?? this.attachmentPaths,
        isPublic: isPublic ?? this.isPublic,
        publicPrice: publicPrice == _sentinel
            ? this.publicPrice
            : publicPrice as double?,
        publicDescription: publicDescription == _sentinel
            ? this.publicDescription
            : publicDescription as String?,
      );
}

/// Getypte Buchungsart einer Lagerbewegung.
///
/// Entspricht dem `movement_type`-CHECK-Enum in der DB:
/// `goods_in | goods_out | correction | stocktake | transfer | sale`.
enum InventoryMovementType {
  goodsIn,
  goodsOut,
  correction,
  stocktake,
  transfer,
  sale;

  /// Konvertiert den DB-String (snake_case) in den Enum-Wert.
  /// Unbekannte Werte fallen defensiv auf [correction] zurück — kein Crash.
  static InventoryMovementType fromDbValue(String value) {
    switch (value) {
      case 'goods_in':
        return InventoryMovementType.goodsIn;
      case 'goods_out':
        return InventoryMovementType.goodsOut;
      case 'correction':
        return InventoryMovementType.correction;
      case 'stocktake':
        return InventoryMovementType.stocktake;
      case 'transfer':
        return InventoryMovementType.transfer;
      case 'sale':
        return InventoryMovementType.sale;
      default:
        return InventoryMovementType.correction;
    }
  }

  /// DB-String (snake_case) für diesen Enum-Wert.
  String get dbValue {
    switch (this) {
      case InventoryMovementType.goodsIn:
        return 'goods_in';
      case InventoryMovementType.goodsOut:
        return 'goods_out';
      case InventoryMovementType.correction:
        return 'correction';
      case InventoryMovementType.stocktake:
        return 'stocktake';
      case InventoryMovementType.transfer:
        return 'transfer';
      case InventoryMovementType.sale:
        return 'sale';
    }
  }
}

class InventoryMovement {
  final String id;
  final String itemId;
  final DateTime date;
  final int quantityChange;
  final String reason;
  final InventoryMovementType movementType;
  final double? unitCost;
  final int? dealId;
  final String? ticketNumber;
  final String? note;

  const InventoryMovement({
    required this.id,
    required this.itemId,
    required this.date,
    required this.quantityChange,
    required this.reason,
    this.movementType = InventoryMovementType.correction,
    this.unitCost,
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
        'movementType': movementType.dbValue,
        'unitCost': unitCost,
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
        movementType: json['movementType'] != null
            ? InventoryMovementType.fromDbValue(
                json['movementType'] as String)
            : InventoryMovementType.correction,
        unitCost: (json['unitCost'] as num?)?.toDouble(),
        dealId: json['dealId'] as int?,
        ticketNumber: json['ticketNumber'] as String?,
        note: json['note'] as String?,
      );

  // ── Supabase (snake_case) ─────────────────────────────────────────────────

  Map<String, dynamic> toSupabaseInsert() {
    final map = <String, dynamic>{
      'id': id,
      'item_id': itemId,
      'date': date.toIso8601String(),
      'quantity_change': quantityChange,
      'reason': reason,
      'movement_type': movementType.dbValue,
      'deal_id': dealId,
      'ticket_number': ticketNumber,
      'note': note,
    };
    if (unitCost != null) {
      map['unit_cost'] = unitCost;
    }
    return map;
  }

  factory InventoryMovement.fromSupabase(Map<String, dynamic> row) =>
      InventoryMovement(
        id: row['id'] as String,
        itemId: row['item_id'] as String,
        date: DateTime.parse(row['date'] as String),
        quantityChange: (row['quantity_change'] as num?)?.toInt() ?? 0,
        reason: row['reason'] as String? ?? 'Korrektur',
        movementType: row['movement_type'] != null
            ? InventoryMovementType.fromDbValue(
                row['movement_type'] as String)
            : InventoryMovementType.correction,
        unitCost: (row['unit_cost'] as num?)?.toDouble(),
        dealId: (row['deal_id'] as num?)?.toInt(),
        ticketNumber: row['ticket_number'] as String?,
        note: row['note'] as String?,
      );

  InventoryMovement copyWith({
    String? id,
    String? itemId,
    DateTime? date,
    int? quantityChange,
    String? reason,
    InventoryMovementType? movementType,
    Object? unitCost = _sentinel,
    Object? dealId = _sentinel,
    Object? ticketNumber = _sentinel,
    Object? note = _sentinel,
  }) =>
      InventoryMovement(
        id: id ?? this.id,
        itemId: itemId ?? this.itemId,
        date: date ?? this.date,
        quantityChange: quantityChange ?? this.quantityChange,
        reason: reason ?? this.reason,
        movementType: movementType ?? this.movementType,
        unitCost: unitCost == _sentinel ? this.unitCost : unitCost as double?,
        dealId: dealId == _sentinel ? this.dealId : dealId as int?,
        ticketNumber: ticketNumber == _sentinel
            ? this.ticketNumber
            : ticketNumber as String?,
        note: note == _sentinel ? this.note : note as String?,
      );
}

const Object _sentinel = Object();
