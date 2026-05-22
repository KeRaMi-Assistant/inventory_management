class ProductCategory {
  final String id;
  final String workspaceId;
  final String userId;
  final String name;
  final String? parentId;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const ProductCategory({
    required this.id,
    required this.workspaceId,
    required this.userId,
    required this.name,
    this.parentId,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  Map<String, dynamic> toSupabaseInsert() => {
        if (id.isNotEmpty) 'id': id,
        'workspace_id': workspaceId,
        'user_id': userId,
        'name': name,
        'parent_id': parentId,
        'sort_order': sortOrder,
      };

  factory ProductCategory.fromSupabase(Map<String, dynamic> row) =>
      ProductCategory(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        userId: row['user_id'] as String,
        name: row['name'] as String,
        parentId: row['parent_id'] as String?,
        sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
        deletedAt: row['deleted_at'] != null
            ? DateTime.parse(row['deleted_at'] as String)
            : null,
      );

  ProductCategory copyWith({
    String? id,
    String? workspaceId,
    String? userId,
    String? name,
    Object? parentId = _sentinel,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? deletedAt = _sentinel,
  }) =>
      ProductCategory(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        userId: userId ?? this.userId,
        name: name ?? this.name,
        parentId: parentId == _sentinel ? this.parentId : parentId as String?,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt:
            deletedAt == _sentinel ? this.deletedAt : deletedAt as DateTime?,
      );
}

const Object _sentinel = Object();
