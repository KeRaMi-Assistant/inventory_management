class InventoryBatch {
  final String id;
  final String itemId;
  final String batchNumber;
  final String? serialNumber;
  final DateTime? mhd;
  final int quantity;
  final DateTime createdAt;

  const InventoryBatch({
    required this.id,
    required this.itemId,
    required this.batchNumber,
    this.serialNumber,
    this.mhd,
    required this.quantity,
    required this.createdAt,
  });

  /// Liefert true, wenn das MHD in <= [days] Tagen erreicht wird.
  bool isExpiringSoon({int days = 30}) {
    if (mhd == null) return false;
    final now = DateTime.now();
    final diff = mhd!.difference(DateTime(now.year, now.month, now.day));
    return diff.inDays >= 0 && diff.inDays <= days;
  }

  bool get isExpired =>
      mhd != null && mhd!.isBefore(DateTime.now().subtract(const Duration(days: 1)));

  Map<String, dynamic> toJson() => {
        'id': id,
        'itemId': itemId,
        'batchNumber': batchNumber,
        'serialNumber': serialNumber,
        'mhd': mhd?.toIso8601String(),
        'quantity': quantity,
        'createdAt': createdAt.toIso8601String(),
      };

  factory InventoryBatch.fromJson(Map<String, dynamic> json) => InventoryBatch(
        id: json['id'] as String,
        itemId: json['itemId'] as String,
        batchNumber: json['batchNumber'] as String,
        serialNumber: json['serialNumber'] as String?,
        mhd: json['mhd'] != null
            ? DateTime.parse(json['mhd'] as String)
            : null,
        quantity: json['quantity'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toSupabaseInsert() => {
        if (id.isNotEmpty) 'id': id,
        'item_id': itemId,
        'batch_number': batchNumber,
        'serial_number': serialNumber,
        'mhd': mhd != null
            ? '${mhd!.year.toString().padLeft(4, '0')}-${mhd!.month.toString().padLeft(2, '0')}-${mhd!.day.toString().padLeft(2, '0')}'
            : null,
        'quantity': quantity,
      };

  factory InventoryBatch.fromSupabase(Map<String, dynamic> row) =>
      InventoryBatch(
        id: row['id'] as String,
        itemId: row['item_id'] as String,
        batchNumber: row['batch_number'] as String,
        serialNumber: row['serial_number'] as String?,
        mhd: row['mhd'] != null ? DateTime.parse(row['mhd'] as String) : null,
        quantity: (row['quantity'] as num).toInt(),
        createdAt: row['created_at'] != null
            ? DateTime.parse(row['created_at'] as String)
            : DateTime.now(),
      );

  InventoryBatch copyWith({
    String? id,
    String? itemId,
    String? batchNumber,
    Object? serialNumber = _sentinel,
    Object? mhd = _sentinel,
    int? quantity,
    DateTime? createdAt,
  }) =>
      InventoryBatch(
        id: id ?? this.id,
        itemId: itemId ?? this.itemId,
        batchNumber: batchNumber ?? this.batchNumber,
        serialNumber: serialNumber == _sentinel
            ? this.serialNumber
            : serialNumber as String?,
        mhd: mhd == _sentinel ? this.mhd : mhd as DateTime?,
        quantity: quantity ?? this.quantity,
        createdAt: createdAt ?? this.createdAt,
      );
}

const Object _sentinel = Object();
