class Shop {
  final String id;
  final String name;
  final String region;
  final String channel;
  final bool active;
  final String? url;

  const Shop({
    required this.id,
    required this.name,
    required this.region,
    this.channel = '',
    this.active = true,
    this.url,
  });

  // ── Local backup JSON (camelCase) ─────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'region': region,
        'channel': channel,
        'active': active,
        if (url != null) 'url': url,
      };

  factory Shop.fromJson(Map<String, dynamic> json) => Shop(
        id: json['id'] as String,
        name: json['name'] as String,
        region: json['region'] as String,
        channel: json['channel'] as String? ?? '',
        active: json['active'] as bool? ?? true,
        url: json['url'] as String?,
      );

  // ── Supabase (snake_case) ─────────────────────────────────────────────────

  Map<String, dynamic> toSupabaseInsert() => {
        'id': id,
        'name': name,
        'region': region,
        'channel': channel,
        'active': active,
        'url': url,
      };

  factory Shop.fromSupabase(Map<String, dynamic> row) => Shop(
        id: row['id'] as String,
        name: row['name'] as String,
        region: row['region'] as String? ?? 'DE',
        channel: row['channel'] as String? ?? '',
        active: row['active'] as bool? ?? true,
        url: row['url'] as String?,
      );

  Shop copyWith({
    String? id,
    String? name,
    String? region,
    String? channel,
    bool? active,
    Object? url = _sentinel,
  }) =>
      Shop(
        id: id ?? this.id,
        name: name ?? this.name,
        region: region ?? this.region,
        channel: channel ?? this.channel,
        active: active ?? this.active,
        url: url == _sentinel ? this.url : url as String?,
      );
}

const Object _sentinel = Object();
