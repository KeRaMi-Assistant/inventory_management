/// Aggregierter Lagerbestand eines Produkts pro Lager.
///
/// Liest aus dem DB-View `product_stock` (Epic A-full, read-only).
/// Der View aggregiert `inventory_items.quantity` pro
/// `(workspace_id, product_id, warehouse_id)` — Rows mit
/// `product_id IS NULL` werden dort bewusst ausgeschlossen.
///
/// Gesamtbestand eines Produkts = Summe aller Rows mit gleicher
/// `productId` über alle Lager (Groupierung im Provider).
class ProductStock {
  final String workspaceId;
  final String productId;

  /// `null` wenn das Bestands-Item keinem Lager zugeordnet ist
  /// (d. h. `inventory_items.warehouse_id IS NULL`).
  final String? warehouseId;

  final int qtyInWarehouse;

  const ProductStock({
    required this.workspaceId,
    required this.productId,
    this.warehouseId,
    required this.qtyInWarehouse,
  });

  factory ProductStock.fromSupabase(Map<String, dynamic> row) => ProductStock(
        workspaceId: row['workspace_id'] as String,
        productId: row['product_id'] as String,
        warehouseId: row['warehouse_id'] as String?,
        qtyInWarehouse: (row['qty_in_warehouse'] as num?)?.toInt() ?? 0,
      );
}
