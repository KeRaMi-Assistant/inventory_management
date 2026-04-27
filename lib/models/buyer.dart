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

  const Buyer({
    required this.id,
    required this.name,
    required this.rowFillColor,
    required this.buyerCellColor,
    required this.fontColor,
    required this.sortOrder,
    this.active = true,
    this.discordServerIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rowFillColor': rowFillColor.toARGB32(),
        'buyerCellColor': buyerCellColor.toARGB32(),
        'fontColor': fontColor.toARGB32(),
        'sortOrder': sortOrder,
        'active': active,
        'discordServerIds': discordServerIds,
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
      );

  Buyer copyWith({
    String? id,
    String? name,
    Color? rowFillColor,
    Color? buyerCellColor,
    Color? fontColor,
    int? sortOrder,
    bool? active,
    List<String>? discordServerIds,
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
      );
}

