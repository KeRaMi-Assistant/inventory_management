import 'package:flutter/material.dart';

class Buyer {
  final String id;
  final String name;
  final Color rowFillColor;
  final Color buyerCellColor;
  final Color fontColor;
  final int sortOrder;
  final bool active;
  final List<String> discordServerIds;
  final String paymentStatus;

  const Buyer({
    required this.id,
    required this.name,
    required this.rowFillColor,
    required this.buyerCellColor,
    required this.fontColor,
    required this.sortOrder,
    this.active = true,
    this.discordServerIds = const [],
    this.paymentStatus = 'OK',
  });

  // ── Local backup JSON (camelCase) ─────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rowFillColor': rowFillColor.toARGB32(),
        'buyerCellColor': buyerCellColor.toARGB32(),
        'fontColor': fontColor.toARGB32(),
        'sortOrder': sortOrder,
        'active': active,
        'discordServerIds': discordServerIds,
        'paymentStatus': paymentStatus,
      };

  factory Buyer.fromJson(Map<String, dynamic> json) => Buyer(
        id: json['id'] as String,
        name: json['name'] as String,
        rowFillColor: Color(json['rowFillColor'] as int),
        buyerCellColor: Color(json['buyerCellColor'] as int),
        fontColor: Color(json['fontColor'] as int),
        sortOrder: json['sortOrder'] as int,
        active: json['active'] as bool? ?? true,
        discordServerIds: (json['discordServerIds'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        paymentStatus: json['paymentStatus'] as String? ?? 'OK',
      );

  // ── Supabase (snake_case) ─────────────────────────────────────────────────

  /// Insert/update payload. `id` is included so the client can keep stable
  /// UUIDs across upserts; `user_id` is added by the repository.
  Map<String, dynamic> toSupabaseInsert() => {
        'id': id,
        'name': name,
        'row_fill_color': rowFillColor.toARGB32(),
        'buyer_cell_color': buyerCellColor.toARGB32(),
        'font_color': fontColor.toARGB32(),
        'sort_order': sortOrder,
        'active': active,
        'discord_server_ids': discordServerIds,
        'payment_status': paymentStatus,
      };

  factory Buyer.fromSupabase(Map<String, dynamic> row) {
    final raw = row['discord_server_ids'];
    final ids = raw is List
        ? raw.map((e) => e.toString()).toList()
        : <String>[];
    return Buyer(
      id: row['id'] as String,
      name: row['name'] as String,
      rowFillColor: Color((row['row_fill_color'] as num).toInt()),
      buyerCellColor: Color((row['buyer_cell_color'] as num).toInt()),
      fontColor: Color((row['font_color'] as num).toInt()),
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      active: row['active'] as bool? ?? true,
      discordServerIds: ids,
      paymentStatus: row['payment_status'] as String? ?? 'OK',
    );
  }

  Buyer copyWith({
    String? id,
    String? name,
    Color? rowFillColor,
    Color? buyerCellColor,
    Color? fontColor,
    int? sortOrder,
    bool? active,
    List<String>? discordServerIds,
    String? paymentStatus,
  }) =>
      Buyer(
        id: id ?? this.id,
        name: name ?? this.name,
        rowFillColor: rowFillColor ?? this.rowFillColor,
        buyerCellColor: buyerCellColor ?? this.buyerCellColor,
        fontColor: fontColor ?? this.fontColor,
        sortOrder: sortOrder ?? this.sortOrder,
        active: active ?? this.active,
        discordServerIds: discordServerIds ?? this.discordServerIds,
        paymentStatus: paymentStatus ?? this.paymentStatus,
      );
}
