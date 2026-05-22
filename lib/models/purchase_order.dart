/// Status einer Bestellung (`purchase_orders.status`).
///
/// DB-Werte: `draft | ordered | partially_received | received | cancelled`.
/// Unbekannte DB-Strings fallen defensiv auf [draft] zurück — kein Crash.
enum PurchaseOrderStatus {
  draft,
  ordered,
  partiallyReceived,
  received,
  cancelled;

  /// Konvertiert den DB-String in den Enum-Wert.
  static PurchaseOrderStatus fromDbValue(String value) {
    switch (value) {
      case 'draft':
        return PurchaseOrderStatus.draft;
      case 'ordered':
        return PurchaseOrderStatus.ordered;
      case 'partially_received':
        return PurchaseOrderStatus.partiallyReceived;
      case 'received':
        return PurchaseOrderStatus.received;
      case 'cancelled':
        return PurchaseOrderStatus.cancelled;
      default:
        return PurchaseOrderStatus.draft;
    }
  }

  /// DB-String (snake_case) für diesen Enum-Wert.
  String get dbValue {
    switch (this) {
      case PurchaseOrderStatus.draft:
        return 'draft';
      case PurchaseOrderStatus.ordered:
        return 'ordered';
      case PurchaseOrderStatus.partiallyReceived:
        return 'partially_received';
      case PurchaseOrderStatus.received:
        return 'received';
      case PurchaseOrderStatus.cancelled:
        return 'cancelled';
    }
  }
}

/// Bestellkopf — entspricht der `purchase_orders`-Tabelle (Epic C).
///
/// `id` ist `int?` weil der PK ein BIGSERIAL ist (DB generiert ihn).
/// Noch nicht gespeicherte Bestellungen haben `id == null`; nach dem
/// Insert gibt Supabase den erzeugten int-PK zurück.
class PurchaseOrder {
  /// DB-generierter BIGSERIAL-PK. `null` solange der Record nicht persistiert.
  final int? id;
  final String workspaceId;
  final String userId;

  /// FK auf `suppliers(id)` — UUID als String.
  final String? supplierId;
  final String orderNumber;
  final PurchaseOrderStatus status;
  final DateTime? orderDate;
  final DateTime? expectedDate;
  final String? note;
  final double? totalNet;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy;
  final int version;
  final DateTime? deletedAt;

  const PurchaseOrder({
    this.id,
    required this.workspaceId,
    required this.userId,
    this.supplierId,
    required this.orderNumber,
    this.status = PurchaseOrderStatus.draft,
    this.orderDate,
    this.expectedDate,
    this.note,
    this.totalNet,
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
        'supplier_id': supplierId,
        'order_number': orderNumber,
        'status': status.dbValue,
        'order_date': orderDate?.toIso8601String(),
        'expected_date': expectedDate?.toIso8601String(),
        'note': note,
        'total_net': totalNet,
      };

  factory PurchaseOrder.fromSupabase(Map<String, dynamic> row) => PurchaseOrder(
        id: (row['id'] as num?)?.toInt(),
        workspaceId: row['workspace_id'] as String,
        userId: row['user_id'] as String,
        supplierId: row['supplier_id'] as String?,
        orderNumber: row['order_number'] as String,
        status: row['status'] != null
            ? PurchaseOrderStatus.fromDbValue(row['status'] as String)
            : PurchaseOrderStatus.draft,
        orderDate: row['order_date'] != null
            ? DateTime.parse(row['order_date'] as String)
            : null,
        expectedDate: row['expected_date'] != null
            ? DateTime.parse(row['expected_date'] as String)
            : null,
        note: row['note'] as String?,
        totalNet: (row['total_net'] as num?)?.toDouble(),
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
        updatedBy: row['updated_by'] as String?,
        version: (row['version'] as num?)?.toInt() ?? 1,
        deletedAt: row['deleted_at'] != null
            ? DateTime.parse(row['deleted_at'] as String)
            : null,
      );

  PurchaseOrder copyWith({
    Object? id = _sentinel,
    String? workspaceId,
    String? userId,
    Object? supplierId = _sentinel,
    String? orderNumber,
    PurchaseOrderStatus? status,
    Object? orderDate = _sentinel,
    Object? expectedDate = _sentinel,
    Object? note = _sentinel,
    Object? totalNet = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? updatedBy = _sentinel,
    int? version,
    Object? deletedAt = _sentinel,
  }) =>
      PurchaseOrder(
        id: id == _sentinel ? this.id : id as int?,
        workspaceId: workspaceId ?? this.workspaceId,
        userId: userId ?? this.userId,
        supplierId:
            supplierId == _sentinel ? this.supplierId : supplierId as String?,
        orderNumber: orderNumber ?? this.orderNumber,
        status: status ?? this.status,
        orderDate:
            orderDate == _sentinel ? this.orderDate : orderDate as DateTime?,
        expectedDate: expectedDate == _sentinel
            ? this.expectedDate
            : expectedDate as DateTime?,
        note: note == _sentinel ? this.note : note as String?,
        totalNet: totalNet == _sentinel ? this.totalNet : totalNet as double?,
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
