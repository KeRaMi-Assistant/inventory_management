/// Lager-Stammsatz (Epic D — Mehrlager).
///
/// Entspricht der DB-Tabelle `warehouses`:
///   id, workspace_id, user_id, name, address, is_default, is_active,
///   created_at, updated_at, deleted_at.
///
/// Das Partial-UNIQUE-Constraint `UNIQUE (workspace_id) WHERE is_default AND
/// deleted_at IS NULL` garantiert DB-seitig, dass maximal ein Lager pro
/// Workspace als Default markiert sein kann. Der App-seitige Bootstrap (in
/// `DealsProvider`) nutzt `is_default: true` beim ersten Anlegen.
class Warehouse {
  final String id;
  final String workspaceId;
  final String userId;

  /// Anzeigename des Lagers (1–100 Zeichen, DB-CHECK-Constraint).
  final String name;

  /// Optionale Adresse (Freitext).
  final String? address;

  /// Dieses Lager ist das Standardlager des Workspaces.
  /// DB-seitig wird max. ein aktives Default pro Workspace erlaubt.
  final bool isDefault;

  /// Lager ist aktiv und für Buchungen auswählbar.
  final bool isActive;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const Warehouse({
    required this.id,
    required this.workspaceId,
    required this.userId,
    required this.name,
    this.address,
    this.isDefault = false,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  /// Erzeugt einen Insert-Payload für Supabase.
  ///
  /// `user_id` und `workspace_id` werden im Repository vor dem Insert
  /// ergänzt (Pattern analog `ProductCategory.toSupabaseInsert`).
  /// Timestamps (`created_at`, `updated_at`) werden nicht geschrieben —
  /// DB-Defaults und Touch-Trigger setzen sie.
  Map<String, dynamic> toSupabaseInsert() => {
        if (id.isNotEmpty) 'id': id,
        'workspace_id': workspaceId,
        'user_id': userId,
        'name': name,
        'address': address,
        'is_default': isDefault,
        'is_active': isActive,
      };

  factory Warehouse.fromSupabase(Map<String, dynamic> row) => Warehouse(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        userId: row['user_id'] as String,
        name: row['name'] as String,
        address: row['address'] as String?,
        isDefault: (row['is_default'] as bool?) ?? false,
        isActive: (row['is_active'] as bool?) ?? true,
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
        deletedAt: row['deleted_at'] != null
            ? DateTime.parse(row['deleted_at'] as String)
            : null,
      );

  Warehouse copyWith({
    String? id,
    String? workspaceId,
    String? userId,
    String? name,
    Object? address = _sentinel,
    bool? isDefault,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? deletedAt = _sentinel,
  }) =>
      Warehouse(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        userId: userId ?? this.userId,
        name: name ?? this.name,
        address: address == _sentinel ? this.address : address as String?,
        isDefault: isDefault ?? this.isDefault,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt:
            deletedAt == _sentinel ? this.deletedAt : deletedAt as DateTime?,
      );
}

const Object _sentinel = Object();
