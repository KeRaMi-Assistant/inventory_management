import 'package:flutter/material.dart';

class Buyer {
  final String id;
  final String name;
  final Color rowFillColor;
  final Color buyerCellColor;
  final Color fontColor;
  final int sortOrder;
  final bool active;

  const Buyer({
    required this.id,
    required this.name,
    required this.rowFillColor,
    required this.buyerCellColor,
    required this.fontColor,
    required this.sortOrder,
    this.active = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rowFillColor': rowFillColor.toARGB32(),
        'buyerCellColor': buyerCellColor.toARGB32(),
        'fontColor': fontColor.toARGB32(),
        'sortOrder': sortOrder,
        'active': active,
      };

  factory Buyer.fromJson(Map<String, dynamic> json) => Buyer(
        id: json['id'] as String,
        name: json['name'] as String,
        rowFillColor: Color(json['rowFillColor'] as int),
        buyerCellColor: Color(json['buyerCellColor'] as int),
        fontColor: Color(json['fontColor'] as int),
        sortOrder: json['sortOrder'] as int,
        active: json['active'] as bool? ?? true,
      );

  Buyer copyWith({
    String? id,
    String? name,
    Color? rowFillColor,
    Color? buyerCellColor,
    Color? fontColor,
    int? sortOrder,
    bool? active,
  }) =>
      Buyer(
        id: id ?? this.id,
        name: name ?? this.name,
        rowFillColor: rowFillColor ?? this.rowFillColor,
        buyerCellColor: buyerCellColor ?? this.buyerCellColor,
        fontColor: fontColor ?? this.fontColor,
        sortOrder: sortOrder ?? this.sortOrder,
        active: active ?? this.active,
      );
}
