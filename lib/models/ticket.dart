/// Row in the `tickets` table — backs the auto-archive lifecycle introduced
/// in migration `20260509000000_tickets_table.sql`. The DB infers archive
/// state from linked deals/inventory; we only mutate it explicitly through
/// `archiveTicket` / `reopenTicket`.
class Ticket {
  final int id;
  final String workspaceId;
  final String ticketNumber;
  final DateTime? archivedAt;
  final String? archivedReason;
  final String? archivedBy;
  final DateTime createdAt;

  const Ticket({
    required this.id,
    required this.workspaceId,
    required this.ticketNumber,
    required this.createdAt,
    this.archivedAt,
    this.archivedReason,
    this.archivedBy,
  });

  bool get isArchived => archivedAt != null;

  factory Ticket.fromSupabase(Map<String, dynamic> row) => Ticket(
        id: (row['id'] as num).toInt(),
        workspaceId: row['workspace_id'] as String,
        ticketNumber: row['ticket_number'] as String,
        archivedAt: row['archived_at'] != null
            ? DateTime.parse(row['archived_at'] as String)
            : null,
        archivedReason: row['archived_reason'] as String?,
        archivedBy: row['archived_by'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
      );

  Ticket copyWith({
    DateTime? archivedAt,
    String? archivedReason,
    String? archivedBy,
    bool clearArchive = false,
  }) =>
      Ticket(
        id: id,
        workspaceId: workspaceId,
        ticketNumber: ticketNumber,
        createdAt: createdAt,
        archivedAt: clearArchive ? null : (archivedAt ?? this.archivedAt),
        archivedReason:
            clearArchive ? null : (archivedReason ?? this.archivedReason),
        archivedBy: clearArchive ? null : (archivedBy ?? this.archivedBy),
      );
}
