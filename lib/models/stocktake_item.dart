/// Zähl-Position einer Inventur — entspricht der `stocktake_items`-Tabelle
/// (Epic E).
///
/// `stocktakeId` ist `int?` (BIGINT-FK auf `stocktakes.id`, welcher
/// BIGSERIAL ist). Frisch angelegte Items, die noch nicht persistiert
/// wurden, können `stocktakeId == null` tragen.
///
/// `countedQty` ist nullable: `null` bedeutet „noch nicht gezählt".
/// Ein Wert >= 0 bedeutet, dass die Position bereits gezählt wurde.
class StocktakeItem {
  /// UUID-PK, generiert durch `gen_random_uuid()` in der DB (oder Client).
  final String id;
  final String workspaceId;

  /// FK auf `stocktakes(id)` — BIGINT, da PK dort BIGSERIAL ist.
  final int? stocktakeId;

  /// FK auf `products(id)` — UUID als String.
  final String productId;

  /// Soll-Bestand zum Snapshot-Zeitpunkt (aggregiert aus `product_stock`).
  final int expectedQty;

  /// Gezählte Menge. `null` = noch nicht gezählt.
  final int? countedQty;

  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy;
  final int version;

  const StocktakeItem({
    required this.id,
    required this.workspaceId,
    this.stocktakeId,
    required this.productId,
    required this.expectedQty,
    this.countedQty,
    required this.createdAt,
    required this.updatedAt,
    this.updatedBy,
    this.version = 1,
  });

  /// `true` wenn die Position bereits gezählt wurde (`countedQty != null`).
  bool get isCounted => countedQty != null;

  /// Differenz zwischen gezähltem und erwartetem Bestand.
  /// `null` wenn die Position noch nicht gezählt wurde.
  int? get difference =>
      countedQty != null ? countedQty! - expectedQty : null;

  /// Schreibt nur die Client-seitig gesetzten Spalten.
  /// `id` wird stets geschrieben (Client vergibt UUID vor dem Insert).
  /// Timestamps (`created_at`, `updated_at`) werden durch den `touch_row`-
  /// Trigger server-seitig gepflegt.
  Map<String, dynamic> toSupabaseInsert() => {
        'id': id,
        'workspace_id': workspaceId,
        if (stocktakeId != null) 'stocktake_id': stocktakeId,
        'product_id': productId,
        'expected_qty': expectedQty,
        'counted_qty': countedQty,
      };

  factory StocktakeItem.fromSupabase(Map<String, dynamic> row) =>
      StocktakeItem(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        stocktakeId: (row['stocktake_id'] as num?)?.toInt(),
        productId: row['product_id'] as String,
        expectedQty: (row['expected_qty'] as num?)?.toInt() ?? 0,
        countedQty: (row['counted_qty'] as num?)?.toInt(),
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
        updatedBy: row['updated_by'] as String?,
        version: (row['version'] as num?)?.toInt() ?? 1,
      );

  StocktakeItem copyWith({
    String? id,
    String? workspaceId,
    Object? stocktakeId = _sentinel,
    String? productId,
    int? expectedQty,
    Object? countedQty = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? updatedBy = _sentinel,
    int? version,
  }) =>
      StocktakeItem(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        stocktakeId: stocktakeId == _sentinel
            ? this.stocktakeId
            : stocktakeId as int?,
        productId: productId ?? this.productId,
        expectedQty: expectedQty ?? this.expectedQty,
        countedQty:
            countedQty == _sentinel ? this.countedQty : countedQty as int?,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        updatedBy:
            updatedBy == _sentinel ? this.updatedBy : updatedBy as String?,
        version: version ?? this.version,
      );
}

const Object _sentinel = Object();
