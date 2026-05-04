/// Ein Kommentar/Notiz-Thread-Eintrag auf einem Deal. Pro Deal können beliebig
/// viele Kommentare existieren — die UI zeigt sie chronologisch absteigend.
class DealComment {
  final String id;
  final int dealId;
  final String author;
  final String body;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const DealComment({
    required this.id,
    required this.dealId,
    required this.author,
    required this.body,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toSupabaseInsert() => {
        'id': id,
        'deal_id': dealId,
        'author': author,
        'body': body,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  factory DealComment.fromSupabase(Map<String, dynamic> row) => DealComment(
        id: row['id'] as String,
        dealId: (row['deal_id'] as num).toInt(),
        author: row['author'] as String,
        body: row['body'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: row['updated_at'] != null
            ? DateTime.parse(row['updated_at'] as String)
            : null,
      );
}
