/// Bestellposition — entspricht der `purchase_order_items`-Tabelle (Epic C).
///
/// `purchaseOrderId` ist `int?` (BIGINT-FK auf `purchase_orders.id`,
/// welcher BIGSERIAL ist). Neu angelegte Items, die noch nicht persistiert
/// wurden, können `purchaseOrderId == null` tragen.
class PurchaseOrderItem {
  /// UUID-PK, generiert durch `gen_random_uuid()` in der DB (oder Client).
  final String id;
  final String workspaceId;

  /// FK auf `purchase_orders(id)` — BIGINT, da PK dort BIGSERIAL ist.
  final int? purchaseOrderId;

  /// FK auf `products(id)` — UUID als String.
  final String? productId;
  final int quantityOrdered;

  /// Erhaltene Menge — DB-Default 0.
  final int quantityReceived;
  final double? unitPrice;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy;
  final int version;
  final DateTime? deletedAt;

  const PurchaseOrderItem({
    required this.id,
    required this.workspaceId,
    this.purchaseOrderId,
    this.productId,
    required this.quantityOrdered,
    this.quantityReceived = 0,
    this.unitPrice,
    required this.createdAt,
    required this.updatedAt,
    this.updatedBy,
    this.version = 1,
    this.deletedAt,
  });

  /// Schreibt nur die Client-seitig gesetzten Spalten.
  /// `id` wird stets geschrieben (Client vergibt UUID vor dem Insert).
  /// Timestamps (`created_at`, `updated_at`) werden durch den `touch_row`-
  /// Trigger server-seitig gepflegt.
  Map<String, dynamic> toSupabaseInsert() => {
        'id': id,
        'workspace_id': workspaceId,
        if (purchaseOrderId != null) 'purchase_order_id': purchaseOrderId,
        'product_id': productId,
        'quantity_ordered': quantityOrdered,
        'quantity_received': quantityReceived,
        'unit_price': unitPrice,
      };

  factory PurchaseOrderItem.fromSupabase(Map<String, dynamic> row) =>
      PurchaseOrderItem(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        purchaseOrderId: (row['purchase_order_id'] as num?)?.toInt(),
        productId: row['product_id'] as String?,
        quantityOrdered: (row['quantity_ordered'] as num?)?.toInt() ?? 0,
        quantityReceived: (row['quantity_received'] as num?)?.toInt() ?? 0,
        unitPrice: (row['unit_price'] as num?)?.toDouble(),
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
        updatedBy: row['updated_by'] as String?,
        version: (row['version'] as num?)?.toInt() ?? 1,
        deletedAt: row['deleted_at'] != null
            ? DateTime.parse(row['deleted_at'] as String)
            : null,
      );

  PurchaseOrderItem copyWith({
    String? id,
    String? workspaceId,
    Object? purchaseOrderId = _sentinel,
    Object? productId = _sentinel,
    int? quantityOrdered,
    int? quantityReceived,
    Object? unitPrice = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? updatedBy = _sentinel,
    int? version,
    Object? deletedAt = _sentinel,
  }) =>
      PurchaseOrderItem(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        purchaseOrderId: purchaseOrderId == _sentinel
            ? this.purchaseOrderId
            : purchaseOrderId as int?,
        productId:
            productId == _sentinel ? this.productId : productId as String?,
        quantityOrdered: quantityOrdered ?? this.quantityOrdered,
        quantityReceived: quantityReceived ?? this.quantityReceived,
        unitPrice: unitPrice == _sentinel ? this.unitPrice : unitPrice as double?,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        updatedBy: updatedBy == _sentinel ? this.updatedBy : updatedBy as String?,
        version: version ?? this.version,
        deletedAt:
            deletedAt == _sentinel ? this.deletedAt : deletedAt as DateTime?,
      );
}

const Object _sentinel = Object();
