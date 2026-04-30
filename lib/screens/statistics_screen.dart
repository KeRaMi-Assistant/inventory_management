import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/deal.dart';
import '../providers/inventory_provider.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'de_DE', symbol: '€');
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        final monthly = _monthlyProfit(provider.deals);
        final topProducts = _topProducts(provider.deals);
        final buyerStats = _buyerStats(provider);
        final shopStats = _shopStats(provider.deals);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Panel(
                title: 'Profit pro Monat',
                icon: Icons.bar_chart_outlined,
                child: monthly.isEmpty
                    ? const Text('Keine Profitdaten vorhanden.')
                    : Column(
                        children: monthly.entries.map((e) {
                          final max = monthly.values.fold<double>(0, (m, v) => v.abs() > m ? v.abs() : m);
                          final width = max == 0 ? 0.0 : (e.value.abs() / max).clamp(0.04, 1.0);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                SizedBox(width: 72, child: Text(e.key)),
                                Expanded(
                                  child: FractionallySizedBox(
                                    widthFactor: width,
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: e.value >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 110, child: Text(money.format(e.value), textAlign: TextAlign.right)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth > 1000;
                  final product = _SimpleTable(
                    title: 'Top-Produkte',
                    columns: const ['Produkt', 'Profit', 'Deals'],
                    rows: topProducts.map((e) => [e.name, money.format(e.profit), '${e.count}']).toList(),
                  );
                  final buyers = _SimpleTable(
                    title: 'Käufer-Auswertung',
                    columns: const ['Käufer', 'Deals', 'EK', 'VK', 'Profit', 'Offen'],
                    rows: buyerStats
                        .map((e) => [e.name, '${e.count}', money.format(e.ek), money.format(e.vk), money.format(e.profit), money.format(e.open)])
                        .toList(),
                  );
                  if (wide) {
                    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: product),
                      const SizedBox(width: 16),
                      Expanded(child: buyers),
                    ]);
                  }
                  return Column(children: [product, const SizedBox(height: 16), buyers]);
                },
              ),
              const SizedBox(height: 16),
              _SimpleTable(
                title: 'Shop-Auswertung',
                columns: const ['Shop', 'Deals', 'Volumen', 'Ø Profit/Deal'],
                rows: shopStats
                    .map((e) => [e.name, '${e.count}', money.format(e.volume), money.format(e.avgProfit)])
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Map<String, double> _monthlyProfit(List<Deal> deals) {
    final now = DateTime.now();
    final result = <String, double>{};
    final fmt = DateFormat('MM/yy');
    for (int i = 11; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i);
      result[fmt.format(d)] = 0;
    }
    for (final deal in deals) {
      final key = fmt.format(DateTime(deal.orderDate.year, deal.orderDate.month));
      if (result.containsKey(key)) result[key] = result[key]! + (deal.totalProfit ?? 0);
    }
    return result;
  }

  List<_ProductStat> _topProducts(List<Deal> deals) {
    final map = <String, _ProductStat>{};
    for (final deal in deals) {
      final stat = map.putIfAbsent(deal.product, () => _ProductStat(deal.product));
      stat.count += 1;
      stat.profit += deal.totalProfit ?? 0;
    }
    return map.values.toList()..sort((a, b) => b.profit.compareTo(a.profit));
  }

  List<_BuyerStat> _buyerStats(InventoryProvider provider) {
    return provider.buyers.map((buyer) {
      final deals = provider.deals.where((d) => d.buyer == buyer.name);
      return _BuyerStat(
        buyer.name,
        deals.length,
        deals.fold(0, (sum, d) => sum + (d.ekGesamtBrutto ?? 0)),
        deals.fold(0, (sum, d) => sum + (d.zuBekommen ?? 0)),
        deals.fold(0, (sum, d) => sum + (d.totalProfit ?? 0)),
        deals.where((d) => d.status != 'Done').fold(0, (sum, d) => sum + (d.zuBekommen ?? 0)),
      );
    }).toList();
  }

  List<_ShopStat> _shopStats(List<Deal> deals) {
    final map = <String, _ShopStat>{};
    for (final deal in deals) {
      final stat = map.putIfAbsent(deal.shop, () => _ShopStat(deal.shop));
      stat.count += 1;
      stat.volume += deal.zuBekommen ?? 0;
      stat.profit += deal.totalProfit ?? 0;
    }
    return map.values.toList()..sort((a, b) => b.volume.compareTo(a.volume));
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _Panel({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E6EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Icon(icon, size: 16, color: const Color(0xFF6B7280)),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827))),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE0E6EF)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _SimpleTable extends StatelessWidget {
  final String title;
  final List<String> columns;
  final List<List<String>> rows;
  const _SimpleTable({required this.title, required this.columns, required this.rows});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: title,
      icon: Icons.table_chart_outlined,
      child: rows.isEmpty
          ? const Text('Keine Daten vorhanden.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13))
          : ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  border: TableBorder(
                    horizontalInside: const BorderSide(color: Color(0xFFE0E6EF), width: 1),
                  ),
                  children: [
                    // Header
                    TableRow(
                      decoration: const BoxDecoration(color: Color(0xFFEEF2F7)),
                      children: columns.map((c) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        child: Text(
                          c.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                            letterSpacing: 0.5,
                          ),
                        ),
                      )).toList(),
                    ),
                    // Data rows
                    ...rows.asMap().entries.map((entry) => TableRow(
                      decoration: BoxDecoration(
                        color: entry.key.isEven ? Colors.white : const Color(0xFFFAFBFD),
                      ),
                      children: entry.value.map((cell) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Text(
                          cell,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                        ),
                      )).toList(),
                    )),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ProductStat {
  final String name;
  int count = 0;
  double profit = 0;
  _ProductStat(this.name);
}

class _BuyerStat {
  final String name;
  final int count;
  final double ek;
  final double vk;
  final double profit;
  final double open;
  _BuyerStat(this.name, this.count, this.ek, this.vk, this.profit, this.open);
}

class _ShopStat {
  final String name;
  int count = 0;
  double volume = 0;
  double profit = 0;
  double get avgProfit => count == 0 ? 0 : profit / count;
  _ShopStat(this.name);
}
