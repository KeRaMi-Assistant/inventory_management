/// Produkt-Stammkatalog-Eintrag.
///
/// Entspricht der `products`-Tabelle (Epic A-full). Ein `Product` ist der
/// wiederverwendbare Stammartikel; der physische Bestand liegt in
/// `inventory_items` (mit optionaler `product_id`-Referenz).
class Product {
  final String id;
  final String workspaceId;
  final String userId;
  final String name;
  final String? sku;
  final String? ean;
  final String? categoryId;
  final String? defaultSupplierId;
  final String unit;
  final double? defaultCostPrice;
  final double? defaultSalePrice;
  final int minStock;
  final double? taxRate;
  final String? note;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const Product({
    required this.id,
    required this.workspaceId,
    required this.userId,
    required this.name,
    this.sku,
    this.ean,
    this.categoryId,
    this.defaultSupplierId,
    this.unit = 'Stk',
    this.defaultCostPrice,
    this.defaultSalePrice,
    this.minStock = 0,
    this.taxRate,
    this.note,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  /// Schreibt nur die Spalten, die der Client setzt.
  /// `id` wird nur geschrieben wenn non-empty (sonst generiert DB per
  /// `gen_random_uuid()`). Timestamps (`created_at`, `updated_at`) werden
  /// durch den `touch_row`-Trigger server-seitig gepflegt.
  Map<String, dynamic> toSupabaseInsert() => {
        if (id.isNotEmpty) 'id': id,
        'workspace_id': workspaceId,
        'user_id': userId,
        'name': name,
        'sku': sku,
        'ean': ean,
        'category_id': categoryId,
        'default_supplier_id': defaultSupplierId,
        'unit': unit,
        'default_cost_price': defaultCostPrice,
        'default_sale_price': defaultSalePrice,
        'min_stock': minStock,
        'tax_rate': taxRate,
        'note': note,
        'is_active': isActive,
      };

  factory Product.fromSupabase(Map<String, dynamic> row) => Product(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        userId: row['user_id'] as String,
        name: row['name'] as String,
        sku: row['sku'] as String?,
        ean: row['ean'] as String?,
        categoryId: row['category_id'] as String?,
        defaultSupplierId: row['default_supplier_id'] as String?,
        unit: row['unit'] as String? ?? 'Stk',
        defaultCostPrice: (row['default_cost_price'] as num?)?.toDouble(),
        defaultSalePrice: (row['default_sale_price'] as num?)?.toDouble(),
        minStock: (row['min_stock'] as num?)?.toInt() ?? 0,
        taxRate: (row['tax_rate'] as num?)?.toDouble(),
        note: row['note'] as String?,
        isActive: row['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
        deletedAt: row['deleted_at'] != null
            ? DateTime.parse(row['deleted_at'] as String)
            : null,
      );

  Product copyWith({
    String? id,
    String? workspaceId,
    String? userId,
    String? name,
    Object? sku = _sentinel,
    Object? ean = _sentinel,
    Object? categoryId = _sentinel,
    Object? defaultSupplierId = _sentinel,
    String? unit,
    Object? defaultCostPrice = _sentinel,
    Object? defaultSalePrice = _sentinel,
    int? minStock,
    Object? taxRate = _sentinel,
    Object? note = _sentinel,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? deletedAt = _sentinel,
  }) =>
      Product(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        userId: userId ?? this.userId,
        name: name ?? this.name,
        sku: sku == _sentinel ? this.sku : sku as String?,
        ean: ean == _sentinel ? this.ean : ean as String?,
        categoryId:
            categoryId == _sentinel ? this.categoryId : categoryId as String?,
        defaultSupplierId: defaultSupplierId == _sentinel
            ? this.defaultSupplierId
            : defaultSupplierId as String?,
        unit: unit ?? this.unit,
        defaultCostPrice: defaultCostPrice == _sentinel
            ? this.defaultCostPrice
            : defaultCostPrice as double?,
        defaultSalePrice: defaultSalePrice == _sentinel
            ? this.defaultSalePrice
            : defaultSalePrice as double?,
        minStock: minStock ?? this.minStock,
        taxRate: taxRate == _sentinel ? this.taxRate : taxRate as double?,
        note: note == _sentinel ? this.note : note as String?,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt:
            deletedAt == _sentinel ? this.deletedAt : deletedAt as DateTime?,
      );
}

const Object _sentinel = Object();
