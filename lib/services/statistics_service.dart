import '../models/deal.dart';
import '../models/inventory_batch.dart';
import '../models/inventory_item.dart';
import '../models/supplier.dart';
import '../providers/statistics_filter_provider.dart';

/// Hält gefilterte Daten + abgeleitete Statistiken. Berechnungen sind in
/// late-final-Feldern memoisiert, damit der gleiche Service-Instanz mehrfach
/// von der UI verwendet werden kann ohne Re-Berechnung.
///
/// Eine Instanz pro Build entspricht der Filter-State-Identity.
class StatisticsService {
  StatisticsService({
    required this.allDeals,
    required this.allItems,
    required this.suppliers,
    required this.batches,
    required this.filter,
    this.monthlyProfitGoal = 1000,
    this.lowStockThreshold = 5,
  });

  final List<Deal> allDeals;
  final List<InventoryItem> allItems;
  final List<Supplier> suppliers;
  final List<InventoryBatch> batches;
  final StatisticsFilterProvider filter;
  final double monthlyProfitGoal;
  final int lowStockThreshold;

  // ── Filter pipeline ──────────────────────────────────────────────────────

  late final ({DateTime from, DateTime to}) range = filter.currentRange;
  late final ({DateTime from, DateTime to}) prevRange = filter.previousRange;

  late final List<Deal> filteredDeals = _applyFilter(range);
  late final List<Deal> previousFilteredDeals = _applyFilter(prevRange);

  List<Deal> _applyFilter(({DateTime from, DateTime to}) r) {
    final q = filter.productSearch.trim().toLowerCase();
    return allDeals.where((d) {
      if (d.orderDate.isBefore(r.from) || d.orderDate.isAfter(r.to)) {
        return false;
      }
      if (filter.buyer != null && d.buyer != filter.buyer) return false;
      if (filter.shop != null && d.shop != filter.shop) return false;
      if (filter.supplierId != null) {
        // Indirekt: Item-Lieferant via inventoryItemIds
        final supplierMatch = d.inventoryItemIds.any((id) =>
            allItems.any((i) => i.id == id && i.supplierId == filter.supplierId));
        if (!supplierMatch) return false;
      }
      if (q.isNotEmpty && !d.product.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
  }

  // ── KPIs aktuelle Periode ────────────────────────────────────────────────

  late final double revenue = filteredDeals.fold(0.0, (s, d) => s + (d.zuBekommen ?? 0));
  late final double profit = filteredDeals.fold(0.0, (s, d) => s + (d.totalProfit ?? 0));
  late final double ekTotal = filteredDeals.fold(0.0, (s, d) => s + (d.ekGesamtBrutto ?? 0));
  late final double margin = revenue == 0 ? 0 : (profit / revenue) * 100;
  late final double roi = ekTotal == 0 ? 0 : (profit / ekTotal) * 100;
  late final double openReceivables = filteredDeals
      .where((d) => d.status != 'Done')
      .fold(0.0, (s, d) => s + (d.zuBekommen ?? 0));
  late final int dealCount = filteredDeals.length;

  // ── KPIs Vorperiode ──────────────────────────────────────────────────────

  late final double prevRevenue =
      previousFilteredDeals.fold(0.0, (s, d) => s + (d.zuBekommen ?? 0));
  late final double prevProfit =
      previousFilteredDeals.fold(0.0, (s, d) => s + (d.totalProfit ?? 0));
  late final double prevEkTotal =
      previousFilteredDeals.fold(0.0, (s, d) => s + (d.ekGesamtBrutto ?? 0));
  late final double prevMargin = prevRevenue == 0 ? 0 : (prevProfit / prevRevenue) * 100;
  late final double prevRoi = prevEkTotal == 0 ? 0 : (prevProfit / prevEkTotal) * 100;
  late final double prevOpenReceivables = previousFilteredDeals
      .where((d) => d.status != 'Done')
      .fold(0.0, (s, d) => s + (d.zuBekommen ?? 0));
  late final int prevDealCount = previousFilteredDeals.length;

  /// Δ% absolut (avoids div/0).
  static double? deltaPct(double current, double previous) {
    if (previous == 0) return current == 0 ? 0 : null;
    return ((current - previous) / previous.abs()) * 100;
  }

  // ── Zeitreihen für Charts ────────────────────────────────────────────────

  /// Liste von Punkten (Datum → Umsatz, Profit). Stundengranularität wäre
  /// overkill — wir gruppieren auf Tag, Woche oder Monat je nach Range-Länge.
  late final List<TimeBucket> timeSeries = _buildTimeSeries(filteredDeals, range);
  late final List<TimeBucket> previousTimeSeries =
      _buildTimeSeries(previousFilteredDeals, prevRange);

  List<TimeBucket> _buildTimeSeries(
      List<Deal> src, ({DateTime from, DateTime to}) r) {
    final days = r.to.difference(r.from).inDays + 1;
    final granularity = days <= 31
        ? Granularity.day
        : days <= 120
            ? Granularity.week
            : Granularity.month;

    DateTime keyOf(DateTime d) {
      switch (granularity) {
        case Granularity.day:
          return DateTime(d.year, d.month, d.day);
        case Granularity.week:
          final weekday = d.weekday; // 1..7 Mon..Sun
          final monday = d.subtract(Duration(days: weekday - 1));
          return DateTime(monday.year, monday.month, monday.day);
        case Granularity.month:
          return DateTime(d.year, d.month);
      }
    }

    final map = <DateTime, TimeBucket>{};
    final keys = <DateTime>{};

    // Init keys to ensure no gaps in chart
    DateTime cursor = keyOf(r.from);
    final endKey = keyOf(r.to);
    while (!cursor.isAfter(endKey)) {
      keys.add(cursor);
      switch (granularity) {
        case Granularity.day:
          cursor = cursor.add(const Duration(days: 1));
          break;
        case Granularity.week:
          cursor = cursor.add(const Duration(days: 7));
          break;
        case Granularity.month:
          cursor = DateTime(cursor.year, cursor.month + 1);
          break;
      }
    }

    for (final k in keys) {
      map[k] = TimeBucket(date: k, granularity: granularity);
    }
    for (final d in src) {
      final k = keyOf(d.orderDate);
      final bucket = map.putIfAbsent(
          k, () => TimeBucket(date: k, granularity: granularity));
      bucket.revenue += d.zuBekommen ?? 0;
      bucket.profit += d.totalProfit ?? 0;
      bucket.ek += d.ekGesamtBrutto ?? 0;
      bucket.deals += 1;
    }
    final list = map.values.toList()..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  // ── Top-Produkte ─────────────────────────────────────────────────────────

  late final List<ProductStat> topProducts = () {
    final map = <String, ProductStat>{};
    for (final d in filteredDeals) {
      final s = map.putIfAbsent(d.product, () => ProductStat(name: d.product));
      s.count += 1;
      s.profit += d.totalProfit ?? 0;
      s.revenue += d.zuBekommen ?? 0;
      s.ek += d.ekGesamtBrutto ?? 0;
      s.units += d.quantity;
    }
    final list = map.values.toList()
      ..sort((a, b) => b.profit.compareTo(a.profit));
    return list;
  }();

  // ── Käufer-Stats inkl. LTV/Cohorts ───────────────────────────────────────

  late final List<BuyerStat> buyerStats = () {
    final byBuyer = <String, List<Deal>>{};
    for (final d in filteredDeals) {
      final name = d.buyer ?? '— Ohne Käufer';
      byBuyer.putIfAbsent(name, () => []).add(d);
    }
    final now = DateTime.now();
    final results = byBuyer.entries.map((e) {
      final deals = e.value..sort((a, b) => a.orderDate.compareTo(b.orderDate));
      final first = deals.first.orderDate;
      final last = deals.last.orderDate;
      final activeDays = last.difference(first).inDays;
      final revenue = deals.fold<double>(0, (s, d) => s + (d.zuBekommen ?? 0));
      final profit = deals.fold<double>(0, (s, d) => s + (d.totalProfit ?? 0));
      final ek = deals.fold<double>(0, (s, d) => s + (d.ekGesamtBrutto ?? 0));
      final open = deals
          .where((d) => d.status != 'Done')
          .fold<double>(0, (s, d) => s + (d.zuBekommen ?? 0));
      final months = ((activeDays / 30).clamp(1, 999)).toDouble();
      final freq = deals.length / months;
      final inactiveDays = now.difference(last).inDays;
      return BuyerStat(
        name: e.key,
        count: deals.length,
        ek: ek,
        revenue: revenue,
        profit: profit,
        openAmount: open,
        firstDeal: first,
        lastDeal: last,
        activeDays: activeDays,
        avgOrderValue: deals.isEmpty ? 0 : revenue / deals.length,
        frequencyPerMonth: freq,
        inactive: inactiveDays > 60,
      );
    }).toList()
      ..sort((a, b) => b.profit.compareTo(a.profit));
    return results;
  }();

  // ── Shop-Stats ───────────────────────────────────────────────────────────

  late final List<ShopStat> shopStats = () {
    final map = <String, ShopStat>{};
    for (final d in filteredDeals) {
      final s = map.putIfAbsent(d.shop, () => ShopStat(name: d.shop));
      s.count += 1;
      s.volume += d.zuBekommen ?? 0;
      s.profit += d.totalProfit ?? 0;
    }
    return map.values.toList()..sort((a, b) => b.volume.compareTo(a.volume));
  }();

  // ── Lieferanten-Stats ────────────────────────────────────────────────────

  late final List<SupplierStat> supplierStats = () {
    return suppliers.map((sup) {
      final items = allItems.where((i) => i.supplierId == sup.id).toList();
      final stockValue = items.fold<double>(0, (s, i) => s + i.stockValue);
      final avgEk = items.isEmpty
          ? 0.0
          : items.fold<double>(0, (s, i) => s + (i.costPrice ?? 0)) / items.length;
      final supplierItemIds = items.map((i) => i.id).toSet();
      final relatedDeals = filteredDeals
          .where((d) => d.inventoryItemIds.any(supplierItemIds.contains))
          .toList();
      final profit = relatedDeals.fold<double>(0, (s, d) => s + (d.totalProfit ?? 0));
      final revenue = relatedDeals.fold<double>(0, (s, d) => s + (d.zuBekommen ?? 0));
      final marginPct = revenue == 0 ? 0.0 : (profit / revenue) * 100;
      return SupplierStat(
        id: sup.id,
        name: sup.name,
        active: sup.active,
        itemCount: items.length,
        stockValue: stockValue,
        avgEk: avgEk,
        profit: profit,
        marginPct: marginPct,
      );
    }).toList()
      ..sort((a, b) => b.stockValue.compareTo(a.stockValue));
  }();

  // ── Lager-Gesundheit ─────────────────────────────────────────────────────

  late final InventoryHealth inventoryHealth = () {
    final today = DateTime.now();
    final stockEk = allItems.fold<double>(0, (s, i) => s + i.stockValue);
    final stockVk = 0.0; // VK pro Item nicht im Modell — bleibt 0 als Platzhalter
    final expiringSoon =
        batches.where((b) => b.isExpiringSoon(days: 30) && !b.isExpired).length;
    final expired = batches.where((b) => b.isExpired).length;
    final lowStock = allItems.where((i) => i.quantity < lowStockThreshold).length;
    // Tote Bestände: Items, die in den letzten 90 Tagen nicht durch
    // einen verkauften ("Done") Deal liefen.
    final itemActivity = <String, DateTime>{};
    for (final d in allDeals.where((d) => d.status == 'Done')) {
      for (final id in d.inventoryItemIds) {
        final cur = itemActivity[id];
        if (cur == null || d.orderDate.isAfter(cur)) {
          itemActivity[id] = d.orderDate;
        }
      }
    }
    final cutoff = today.subtract(const Duration(days: 90));
    final dead = allItems.where((i) {
      final last = itemActivity[i.id];
      return i.quantity > 0 && (last == null || last.isBefore(cutoff));
    }).length;

    return InventoryHealth(
      stockValueEk: stockEk,
      stockValueVk: stockVk,
      expiringSoon: expiringSoon,
      expired: expired,
      lowStock: lowStock,
      deadStock: dead,
    );
  }();

  // ── Cashflow ─────────────────────────────────────────────────────────────

  late final CashflowReport cashflow = () {
    final received = filteredDeals
        .where((d) => d.status == 'Done')
        .fold<double>(0, (s, d) => s + (d.zuBekommen ?? 0));
    final today = DateTime.now();
    final open = filteredDeals.where((d) => d.status != 'Done').toList();
    double bucket0_7 = 0, bucket8_30 = 0, bucket31_60 = 0, bucket60p = 0;
    Deal? oldest;
    int oldestDays = 0;
    for (final d in open) {
      final age = today.difference(d.orderDate).inDays;
      final amount = d.zuBekommen ?? 0;
      if (age <= 7) {
        bucket0_7 += amount;
      } else if (age <= 30) {
        bucket8_30 += amount;
      } else if (age <= 60) {
        bucket31_60 += amount;
      } else {
        bucket60p += amount;
      }
      if (oldest == null || age > oldestDays) {
        oldest = d;
        oldestDays = age;
      }
    }
    // Ø Zahlungsdauer = Tage zwischen orderDate und arrivalDate (proxy)
    // Bei "Done"-Deals: orderDate → arrivalDate (oder heute, falls null).
    int total = 0;
    int n = 0;
    for (final d in filteredDeals.where((d) => d.status == 'Done')) {
      final endDate = d.arrivalDate ?? today;
      final diff = endDate.difference(d.orderDate).inDays;
      if (diff >= 0) {
        total += diff;
        n += 1;
      }
    }
    final avgDays = n == 0 ? 0.0 : total / n;
    return CashflowReport(
      received: received,
      bucket0_7: bucket0_7,
      bucket8_30: bucket8_30,
      bucket31_60: bucket31_60,
      bucket60p: bucket60p,
      avgPaymentDays: avgDays,
      oldestDeal: oldest,
      oldestDaysOpen: oldestDays,
    );
  }();

  // ── Steuer/MwSt ──────────────────────────────────────────────────────────

  late final List<TaxQuarterReport> taxReports = () {
    // Gruppiert nach (Jahr, Quartal, Währung)
    final map = <String, TaxQuarterReport>{};
    for (final d in filteredDeals) {
      final q = ((d.orderDate.month - 1) ~/ 3) + 1;
      final key = '${d.orderDate.year}-Q$q-${d.currency}';
      final r = map.putIfAbsent(
        key,
        () => TaxQuarterReport(
          year: d.orderDate.year,
          quarter: q,
          currency: d.currency,
        ),
      );
      final netto = d.ekGesamtNetto ?? 0;
      final brutto = d.ekGesamtBrutto ?? 0;
      r.netto += netto;
      r.brutto += brutto;
      r.tax += (brutto - netto);
      r.dealCount += 1;
    }
    final list = map.values.toList()
      ..sort((a, b) {
        final byYear = b.year.compareTo(a.year);
        if (byYear != 0) return byYear;
        final byQ = b.quarter.compareTo(a.quarter);
        if (byQ != 0) return byQ;
        return a.currency.compareTo(b.currency);
      });
    return list;
  }();

  // ── Ziele & Forecasting ──────────────────────────────────────────────────

  late final GoalProgress goals = () {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final monthEnd = DateTime(now.year, now.month + 1).subtract(const Duration(milliseconds: 1));
    final monthDeals = allDeals.where((d) =>
        !d.orderDate.isBefore(monthStart) && !d.orderDate.isAfter(monthEnd));
    final currentProfit = monthDeals.fold<double>(0, (s, d) => s + (d.totalProfit ?? 0));

    // Forecast: Profit / Tage bisher * Tage im Monat
    final daysSoFar = (now.difference(monthStart).inDays + 1).clamp(1, 31);
    final daysInMonth = monthEnd.day;
    final forecast = (currentProfit / daysSoFar) * daysInMonth;

    // Streak: Wie viele aufeinanderfolgende Monate (inkl. aktuell) das Ziel erreicht
    int streak = 0;
    for (int i = 0; i < 24; i++) {
      final mStart = DateTime(now.year, now.month - i);
      final mEnd = DateTime(now.year, now.month - i + 1)
          .subtract(const Duration(milliseconds: 1));
      final mProfit = allDeals
          .where((d) =>
              !d.orderDate.isBefore(mStart) && !d.orderDate.isAfter(mEnd))
          .fold<double>(0, (s, d) => s + (d.totalProfit ?? 0));
      // Aktueller Monat zählt nur wenn Forecast das Ziel schlägt
      final passed = i == 0
          ? forecast >= monthlyProfitGoal
          : mProfit >= monthlyProfitGoal;
      if (passed) {
        streak += 1;
      } else {
        break;
      }
    }

    return GoalProgress(
      currentProfit: currentProfit,
      target: monthlyProfitGoal,
      forecast: forecast,
      streak: streak,
    );
  }();

  // ── Heatmap (12 Monate) ──────────────────────────────────────────────────

  late final Map<DateTime, double> heatmap = () {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 365));
    final map = <DateTime, double>{};
    for (final d in allDeals) {
      if (d.orderDate.isBefore(start)) continue;
      final key = DateTime(d.orderDate.year, d.orderDate.month, d.orderDate.day);
      map[key] = (map[key] ?? 0) + (d.totalProfit ?? 0);
    }
    return map;
  }();

  // ── Drilldown: Daten für einen einzelnen Produkt-Namen ───────────────────

  ProductDrilldown drillDown(String product) {
    final deals = allDeals.where((d) => d.product == product).toList()
      ..sort((a, b) => b.orderDate.compareTo(a.orderDate));
    final monthly = <DateTime, TimeBucket>{};
    for (final d in deals) {
      final key = DateTime(d.orderDate.year, d.orderDate.month);
      final b = monthly.putIfAbsent(
          key, () => TimeBucket(date: key, granularity: Granularity.month));
      b.revenue += d.zuBekommen ?? 0;
      b.profit += d.totalProfit ?? 0;
      b.ek += d.ekGesamtBrutto ?? 0;
      b.deals += 1;
      b.units = (b.units) + d.quantity;
    }
    final monthSeries = monthly.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final byBuyer = <String, double>{};
    for (final d in deals) {
      final n = d.buyer ?? '— Ohne Käufer';
      byBuyer[n] = (byBuyer[n] ?? 0) + (d.totalProfit ?? 0);
    }
    final byShop = <String, double>{};
    for (final d in deals) {
      byShop[d.shop] = (byShop[d.shop] ?? 0) + (d.zuBekommen ?? 0);
    }
    String topName(Map<String, double> m) {
      if (m.isEmpty) return '—';
      final entries = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      return entries.first.key;
    }
    final topBuyers = (byBuyer.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(5)
        .toList();
    final topShops = (byShop.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(5)
        .toList();
    return ProductDrilldown(
      product: product,
      deals: deals,
      monthSeries: monthSeries,
      topBuyers: topBuyers,
      topShops: topShops,
      topBuyerName: topName(byBuyer),
      topShopName: topName(byShop),
    );
  }
}

// ── Datenklassen ───────────────────────────────────────────────────────────

enum Granularity { day, week, month }

class TimeBucket {
  final DateTime date;
  final Granularity granularity;
  double revenue = 0;
  double profit = 0;
  double ek = 0;
  int deals = 0;
  int units = 0;
  TimeBucket({required this.date, required this.granularity});

  double get marginPct => revenue == 0 ? 0 : (profit / revenue) * 100;
}

class ProductStat {
  final String name;
  int count = 0;
  int units = 0;
  double profit = 0;
  double revenue = 0;
  double ek = 0;
  ProductStat({required this.name});
  double get marginPct => revenue == 0 ? 0 : (profit / revenue) * 100;
}

class BuyerStat {
  final String name;
  final int count;
  final double ek;
  final double revenue;
  final double profit;
  final double openAmount;
  final DateTime firstDeal;
  final DateTime lastDeal;
  final int activeDays;
  final double avgOrderValue;
  final double frequencyPerMonth;
  final bool inactive;
  BuyerStat({
    required this.name,
    required this.count,
    required this.ek,
    required this.revenue,
    required this.profit,
    required this.openAmount,
    required this.firstDeal,
    required this.lastDeal,
    required this.activeDays,
    required this.avgOrderValue,
    required this.frequencyPerMonth,
    required this.inactive,
  });
}

class ShopStat {
  final String name;
  int count = 0;
  double volume = 0;
  double profit = 0;
  ShopStat({required this.name});
  double get avgProfit => count == 0 ? 0 : profit / count;
  double get marginPct => volume == 0 ? 0 : (profit / volume) * 100;
}

class SupplierStat {
  final String id;
  final String name;
  final bool active;
  final int itemCount;
  final double stockValue;
  final double avgEk;
  final double profit;
  final double marginPct;
  SupplierStat({
    required this.id,
    required this.name,
    required this.active,
    required this.itemCount,
    required this.stockValue,
    required this.avgEk,
    required this.profit,
    required this.marginPct,
  });
}

class InventoryHealth {
  final double stockValueEk;
  final double stockValueVk;
  final int expiringSoon;
  final int expired;
  final int lowStock;
  final int deadStock;
  InventoryHealth({
    required this.stockValueEk,
    required this.stockValueVk,
    required this.expiringSoon,
    required this.expired,
    required this.lowStock,
    required this.deadStock,
  });
}

class CashflowReport {
  final double received;
  // ignore: non_constant_identifier_names
  final double bucket0_7;
  // ignore: non_constant_identifier_names
  final double bucket8_30;
  // ignore: non_constant_identifier_names
  final double bucket31_60;
  // ignore: non_constant_identifier_names
  final double bucket60p;
  final double avgPaymentDays;
  final Deal? oldestDeal;
  final int oldestDaysOpen;
  CashflowReport({
    required this.received,
    // ignore: non_constant_identifier_names
    required this.bucket0_7,
    // ignore: non_constant_identifier_names
    required this.bucket8_30,
    // ignore: non_constant_identifier_names
    required this.bucket31_60,
    // ignore: non_constant_identifier_names
    required this.bucket60p,
    required this.avgPaymentDays,
    required this.oldestDeal,
    required this.oldestDaysOpen,
  });
  double get totalOpen => bucket0_7 + bucket8_30 + bucket31_60 + bucket60p;
}

class TaxQuarterReport {
  final int year;
  final int quarter;
  final String currency;
  double netto = 0;
  double brutto = 0;
  double tax = 0;
  int dealCount = 0;
  TaxQuarterReport({
    required this.year,
    required this.quarter,
    required this.currency,
  });
  String get label => 'Q$quarter $year';
}

class GoalProgress {
  final double currentProfit;
  final double target;
  final double forecast;
  final int streak;
  GoalProgress({
    required this.currentProfit,
    required this.target,
    required this.forecast,
    required this.streak,
  });
  double get progressPct => target == 0 ? 0 : (currentProfit / target) * 100;
}

class ProductDrilldown {
  final String product;
  final List<Deal> deals;
  final List<TimeBucket> monthSeries;
  final List<MapEntry<String, double>> topBuyers;
  final List<MapEntry<String, double>> topShops;
  final String topBuyerName;
  final String topShopName;
  ProductDrilldown({
    required this.product,
    required this.deals,
    required this.monthSeries,
    required this.topBuyers,
    required this.topShops,
    required this.topBuyerName,
    required this.topShopName,
  });
}
