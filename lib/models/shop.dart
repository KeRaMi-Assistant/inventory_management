class Shop {
  final String id;
  final String name;
  final String region;
  final String channel;
  final bool active;

  const Shop({
    required this.id,
    required this.name,
    required this.region,
    this.channel = '',
    this.active = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'region': region,
        'channel': channel,
        'active': active,
      };

  factory Shop.fromJson(Map<String, dynamic> json) => Shop(
        id: json['id'] as String,
        name: json['name'] as String,
        region: json['region'] as String,
        channel: json['channel'] as String? ?? '',
        active: json['active'] as bool? ?? true,
      );

  Shop copyWith({
    String? id,
    String? name,
    String? region,
    String? channel,
    bool? active,
  }) =>
      Shop(
        id: id ?? this.id,
        name: name ?? this.name,
        region: region ?? this.region,
        channel: channel ?? this.channel,
        active: active ?? this.active,
      );
}
