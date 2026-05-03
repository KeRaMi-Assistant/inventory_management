import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/statistics_service.dart';
import '../product_drilldown_sheet.dart';
import '../sortable_table.dart';
import '../stat_panel.dart';

class ProductsShopsTab extends StatelessWidget {
  final StatisticsService stats;
  const ProductsShopsTab({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'de_DE', symbol: '€');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StatPanel(
          title: 'Top-Produkte',
          icon: Icons.star_outline,
          padding: const EdgeInsets.symmetric(vertical: 4),
          trailing: const Text(
            'Klick öffnet Drilldown',
            style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          ),
          child: SortableTable<ProductStat>(
            rows: stats.topProducts,
            defaultSortIndex: 2,
            defaultAscending: false,
            onTap: (p) => ProductDrilldownSheet.show(
              context,
              stats.drillDown(p.name),
            ),
            columns: [
              SortableColumn(
                label: 'Produkt',
                builder: (p) => Text(p.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                valueOf: (p) => p.name.toLowerCase(),
              ),
              SortableColumn(
                label: 'Deals',
                numeric: true,
                builder: (p) => Text('${p.count}'),
                valueOf: (p) => p.count,
              ),
              SortableColumn(
                label: 'Profit',
                numeric: true,
                builder: (p) => Text(
                  money.format(p.profit),
                  style: TextStyle(
                    color: p.profit >= 0
                        ? const Color(0xFF059669)
                        : const Color(0xFFDC2626),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                valueOf: (p) => p.profit,
              ),
              SortableColumn(
                label: 'Umsatz',
                numeric: true,
                builder: (p) => Text(money.format(p.revenue)),
                valueOf: (p) => p.revenue,
              ),
              SortableColumn(
                label: 'Marge',
                numeric: true,
                builder: (p) => Text('${p.marginPct.toStringAsFixed(1)}%'),
                valueOf: (p) => p.marginPct,
              ),
              SortableColumn(
                label: 'Stück',
                numeric: true,
                builder: (p) => Text('${p.units}'),
                valueOf: (p) => p.units,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StatPanel(
          title: 'Shop-Performance',
          icon: Icons.store_outlined,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SortableTable<ShopStat>(
            rows: stats.shopStats,
            defaultSortIndex: 2,
            defaultAscending: false,
            columns: [
              SortableColumn(
                label: 'Shop',
                builder: (s) => Text(s.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                valueOf: (s) => s.name.toLowerCase(),
              ),
              SortableColumn(
                label: 'Deals',
                numeric: true,
                builder: (s) => Text('${s.count}'),
                valueOf: (s) => s.count,
              ),
              SortableColumn(
                label: 'Volumen',
                numeric: true,
                builder: (s) => Text(money.format(s.volume)),
                valueOf: (s) => s.volume,
              ),
              SortableColumn(
                label: 'Profit',
                numeric: true,
                builder: (s) => Text(
                  money.format(s.profit),
                  style: TextStyle(
                    color: s.profit >= 0
                        ? const Color(0xFF059669)
                        : const Color(0xFFDC2626),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                valueOf: (s) => s.profit,
              ),
              SortableColumn(
                label: 'Marge',
                numeric: true,
                builder: (s) => Text('${s.marginPct.toStringAsFixed(1)}%'),
                valueOf: (s) => s.marginPct,
              ),
              SortableColumn(
                label: 'Ø Profit/Deal',
                numeric: true,
                builder: (s) => Text(money.format(s.avgProfit)),
                valueOf: (s) => s.avgProfit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
