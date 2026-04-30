class ActivityEntry {
  final String id;
  final DateTime date;
  final String message;
  final String type;

  const ActivityEntry({
    required this.id,
    required this.date,
    required this.message,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'message': message,
        'type': type,
      };

  factory ActivityEntry.fromJson(Map<String, dynamic> json) => ActivityEntry(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        message: json['message'] as String,
        type: json['type'] as String? ?? 'info',
      );

  // ── Supabase (snake_case) ─────────────────────────────────────────────────

  Map<String, dynamic> toSupabaseInsert() => {
        'id': id,
        'date': date.toIso8601String(),
        'message': message,
        'type': type,
      };

  factory ActivityEntry.fromSupabase(Map<String, dynamic> row) => ActivityEntry(
        id: row['id'] as String,
        date: DateTime.parse(row['date'] as String),
        message: row['message'] as String,
        type: row['type'] as String? ?? 'info',
      );
}
