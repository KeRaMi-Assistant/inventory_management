/// Artikel-Lieferanten-Zuordnung (n:m zwischen `products` und `suppliers`).
///
/// Entspricht der `product_suppliers`-Tabelle (Epic A-full / B-Split).
/// Mehrere Lieferanten können demselben Produkt zugeordnet sein; maximal
/// ein Eintrag pro Produkt darf `isPreferred = true` tragen
/// (DB-seitig durch partial-UNIQUE abgesichert).
class ProductSupplier {
  final String id;
  final String workspaceId;
  final String userId;
  final String productId;
  final String supplierId;
  final String? supplierSku;
  final double? supplierPrice;
  final bool isPreferred;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const ProductSupplier({
    required this.id,
    required this.workspaceId,
    required this.userId,
    required this.productId,
    required this.supplierId,
    this.supplierSku,
    this.supplierPrice,
    this.isPreferred = false,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  /// Schreibt nur die Spalten, die der Client setzt.
  /// `id` wird nur geschrieben wenn non-empty (sonst generiert DB per
  /// `gen_random_uuid()`). Timestamps werden durch den `touch_row`-Trigger
  /// server-seitig gepflegt.
  Map<String, dynamic> toSupabaseInsert() => {
        if (id.isNotEmpty) 'id': id,
        'workspace_id': workspaceId,
        'user_id': userId,
        'product_id': productId,
        'supplier_id': supplierId,
        'supplier_sku': supplierSku,
        'supplier_price': supplierPrice,
        'is_preferred': isPreferred,
      };

  factory ProductSupplier.fromSupabase(Map<String, dynamic> row) =>
      ProductSupplier(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        userId: row['user_id'] as String,
        productId: row['product_id'] as String,
        supplierId: row['supplier_id'] as String,
        supplierSku: row['supplier_sku'] as String?,
        supplierPrice: (row['supplier_price'] as num?)?.toDouble(),
        isPreferred: row['is_preferred'] as bool? ?? false,
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
        deletedAt: row['deleted_at'] != null
            ? DateTime.parse(row['deleted_at'] as String)
            : null,
      );

  ProductSupplier copyWith({
    String? id,
    String? workspaceId,
    String? userId,
    String? productId,
    String? supplierId,
    Object? supplierSku = _sentinel,
    Object? supplierPrice = _sentinel,
    bool? isPreferred,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? deletedAt = _sentinel,
  }) =>
      ProductSupplier(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        userId: userId ?? this.userId,
        productId: productId ?? this.productId,
        supplierId: supplierId ?? this.supplierId,
        supplierSku:
            supplierSku == _sentinel ? this.supplierSku : supplierSku as String?,
        supplierPrice: supplierPrice == _sentinel
            ? this.supplierPrice
            : supplierPrice as double?,
        isPreferred: isPreferred ?? this.isPreferred,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt:
            deletedAt == _sentinel ? this.deletedAt : deletedAt as DateTime?,
      );
}

const Object _sentinel = Object();
