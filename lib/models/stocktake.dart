/// Status einer Inventur-Session (`stocktakes.status`).
///
/// DB-Werte: `open | counting | closed | cancelled`.
/// Unbekannte DB-Strings fallen defensiv auf [open] zurück — kein Crash.
enum StocktakeStatus {
  open,
  counting,
  closed,
  cancelled;

  /// Konvertiert den DB-String in den Enum-Wert.
  static StocktakeStatus fromDbValue(String value) {
    switch (value) {
      case 'open':
        return StocktakeStatus.open;
      case 'counting':
        return StocktakeStatus.counting;
      case 'closed':
        return StocktakeStatus.closed;
      case 'cancelled':
        return StocktakeStatus.cancelled;
      default:
        return StocktakeStatus.open;
    }
  }

  /// DB-String (snake_case) für diesen Enum-Wert.
  String get dbValue {
    switch (this) {
      case StocktakeStatus.open:
        return 'open';
      case StocktakeStatus.counting:
        return 'counting';
      case StocktakeStatus.closed:
        return 'closed';
      case StocktakeStatus.cancelled:
        return 'cancelled';
    }
  }
}

/// Inventur-Session — entspricht der `stocktakes`-Tabelle (Epic E).
///
/// `id` ist `int?` weil der PK ein BIGSERIAL ist (DB generiert ihn).
/// Noch nicht gespeicherte Sessions haben `id == null`; nach dem
/// Insert gibt Supabase den erzeugten int-PK zurück.
class Stocktake {
  /// DB-generierter BIGSERIAL-PK. `null` solange der Record nicht persistiert.
  final int? id;
  final String workspaceId;
  final String userId;

  /// FK auf `warehouses(id)` — UUID als String. Nullable: nicht alle
  /// Inventuren sind auf ein Lager beschränkt.
  final String? warehouseId;

  final StocktakeStatus status;

  /// Optionaler Titel der Inventur (z. B. „Jahresabschluss 2026").
  final String? title;

  /// Zeitpunkt, zu dem die Inventur gestartet wurde (Zählung begann).
  final DateTime? startedAt;

  /// Zeitpunkt, zu dem die Inventur abgeschlossen / storniert wurde.
  final DateTime? closedAt;

  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy;
  final int version;
  final DateTime? deletedAt;

  const Stocktake({
    this.id,
    required this.workspaceId,
    required this.userId,
    this.warehouseId,
    this.status = StocktakeStatus.open,
    this.title,
    this.startedAt,
    this.closedAt,
    required this.createdAt,
    required this.updatedAt,
    this.updatedBy,
    this.version = 1,
    this.deletedAt,
  });

  /// Schreibt nur die Client-seitig gesetzten Spalten.
  /// `id` wird nur geschrieben wenn non-null (sonst erzeugt DB per BIGSERIAL).
  /// Timestamps (`created_at`, `updated_at`) werden durch den `touch_row`-
  /// Trigger server-seitig gepflegt.
  Map<String, dynamic> toSupabaseInsert() => {
        if (id != null) 'id': id,
        'workspace_id': workspaceId,
        'user_id': userId,
        'warehouse_id': warehouseId,
        'status': status.dbValue,
        'title': title,
        'started_at': startedAt?.toIso8601String(),
        'closed_at': closedAt?.toIso8601String(),
      };

  factory Stocktake.fromSupabase(Map<String, dynamic> row) => Stocktake(
        id: (row['id'] as num?)?.toInt(),
        workspaceId: row['workspace_id'] as String,
        userId: row['user_id'] as String,
        warehouseId: row['warehouse_id'] as String?,
        status: row['status'] != null
            ? StocktakeStatus.fromDbValue(row['status'] as String)
            : StocktakeStatus.open,
        title: row['title'] as String?,
        startedAt: row['started_at'] != null
            ? DateTime.parse(row['started_at'] as String)
            : null,
        closedAt: row['closed_at'] != null
            ? DateTime.parse(row['closed_at'] as String)
            : null,
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
        updatedBy: row['updated_by'] as String?,
        version: (row['version'] as num?)?.toInt() ?? 1,
        deletedAt: row['deleted_at'] != null
            ? DateTime.parse(row['deleted_at'] as String)
            : null,
      );

  Stocktake copyWith({
    Object? id = _sentinel,
    String? workspaceId,
    String? userId,
    Object? warehouseId = _sentinel,
    StocktakeStatus? status,
    Object? title = _sentinel,
    Object? startedAt = _sentinel,
    Object? closedAt = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? updatedBy = _sentinel,
    int? version,
    Object? deletedAt = _sentinel,
  }) =>
      Stocktake(
        id: id == _sentinel ? this.id : id as int?,
        workspaceId: workspaceId ?? this.workspaceId,
        userId: userId ?? this.userId,
        warehouseId:
            warehouseId == _sentinel ? this.warehouseId : warehouseId as String?,
        status: status ?? this.status,
        title: title == _sentinel ? this.title : title as String?,
        startedAt:
            startedAt == _sentinel ? this.startedAt : startedAt as DateTime?,
        closedAt:
            closedAt == _sentinel ? this.closedAt : closedAt as DateTime?,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        updatedBy:
            updatedBy == _sentinel ? this.updatedBy : updatedBy as String?,
        version: version ?? this.version,
        deletedAt:
            deletedAt == _sentinel ? this.deletedAt : deletedAt as DateTime?,
      );
}

const Object _sentinel = Object();
