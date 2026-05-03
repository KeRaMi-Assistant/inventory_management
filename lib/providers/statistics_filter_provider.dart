import 'package:flutter/material.dart';

/// Vordefinierte Zeitraum-Presets für die Statistik-Filter-Toolbar.
enum StatsPreset {
  today('Heute'),
  last7('7 Tage'),
  last30('30 Tage'),
  thisQuarter('Dieses Quartal'),
  thisYear('Dieses Jahr'),
  lastYear('Letztes Jahr'),
  custom('Custom');

  final String label;
  const StatsPreset(this.label);
}

/// Hält den Zustand der Filter-Toolbar in der Statistik. Persistent über alle
/// Tabs, damit der Nutzer beim Wechsel zwischen Übersicht/Käufer/Produkten
/// nicht jedes Mal neu filtern muss.
class StatisticsFilterProvider extends ChangeNotifier {
  StatsPreset preset = StatsPreset.last30;
  DateTime? customFrom;
  DateTime? customTo;
  bool compareToPrevious = true;

  String? buyer;
  String? shop;
  String? supplierId;
  String productSearch = '';

  // ── Range Berechnung ─────────────────────────────────────────────────────

  ({DateTime from, DateTime to}) get currentRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (preset) {
      case StatsPreset.today:
        return (from: today, to: _endOf(today));
      case StatsPreset.last7:
        return (from: today.subtract(const Duration(days: 6)), to: _endOf(today));
      case StatsPreset.last30:
        return (from: today.subtract(const Duration(days: 29)), to: _endOf(today));
      case StatsPreset.thisQuarter:
        final qStart = DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1, 1);
        return (from: qStart, to: _endOf(today));
      case StatsPreset.thisYear:
        return (from: DateTime(now.year, 1, 1), to: _endOf(today));
      case StatsPreset.lastYear:
        return (
          from: DateTime(now.year - 1, 1, 1),
          to: DateTime(now.year - 1, 12, 31, 23, 59, 59, 999),
        );
      case StatsPreset.custom:
        final from = customFrom ?? today.subtract(const Duration(days: 29));
        final to = customTo != null ? _endOf(customTo!) : _endOf(today);
        return (from: from, to: to);
    }
  }

  /// Vorperiode mit gleicher Länge wie [currentRange].
  ({DateTime from, DateTime to}) get previousRange {
    final cur = currentRange;
    final duration = cur.to.difference(cur.from);
    final prevTo = cur.from.subtract(const Duration(milliseconds: 1));
    final prevFrom = prevTo.subtract(duration);
    return (from: prevFrom, to: prevTo);
  }

  // ── Setters ──────────────────────────────────────────────────────────────

  void setPreset(StatsPreset value) {
    preset = value;
    notifyListeners();
  }

  void setCustomRange(DateTime? from, DateTime? to) {
    preset = StatsPreset.custom;
    customFrom = from;
    customTo = to;
    notifyListeners();
  }

  void toggleCompare(bool value) {
    compareToPrevious = value;
    notifyListeners();
  }

  void setBuyer(String? value) {
    buyer = (value == null || value.isEmpty || value == 'Alle') ? null : value;
    notifyListeners();
  }

  void setShop(String? value) {
    shop = (value == null || value.isEmpty || value == 'Alle') ? null : value;
    notifyListeners();
  }

  void setSupplier(String? id) {
    supplierId = (id == null || id.isEmpty) ? null : id;
    notifyListeners();
  }

  void setProductSearch(String value) {
    productSearch = value;
    notifyListeners();
  }

  void reset() {
    preset = StatsPreset.last30;
    customFrom = null;
    customTo = null;
    compareToPrevious = true;
    buyer = null;
    shop = null;
    supplierId = null;
    productSearch = '';
    notifyListeners();
  }

  bool get hasAnyFilter =>
      buyer != null ||
      shop != null ||
      supplierId != null ||
      productSearch.trim().isNotEmpty;

  DateTime _endOf(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
}
