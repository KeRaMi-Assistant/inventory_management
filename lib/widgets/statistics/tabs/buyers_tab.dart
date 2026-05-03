import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/statistics_service.dart';
import '../sortable_table.dart';
import '../stat_panel.dart';

/// Käufer-Tab: Tabelle mit Cohorts, LTV, Frequenz, etc. Sortierbar.
class BuyersTab extends StatelessWidget {
  final StatisticsService stats;
  const BuyersTab({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'de_DE', symbol: '€');
    final dateFmt = DateFormat('dd.MM.yy', 'de_DE');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StatPanel(
          title: 'Käufer-Performance',
          icon: Icons.people_outline,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SortableTable<BuyerStat>(
            rows: stats.buyerStats,
            defaultSortIndex: 5,
            defaultAscending: false,
            rowColor: (b) => b.inactive ? const Color(0xFFFEF2F2) : null,
            columns: [
              SortableColumn(
                label: 'Käufer',
                builder: (b) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (b.inactive)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFDC2626),
                          shape: BoxShape.circle,
                        ),
                      ),
                    Text(b.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                valueOf: (b) => b.name.toLowerCase(),
              ),
              SortableColumn(
                label: 'Deals',
                numeric: true,
                builder: (b) => Text('${b.count}'),
                valueOf: (b) => b.count,
              ),
              SortableColumn(
                label: 'EK',
                numeric: true,
                builder: (b) => Text(money.format(b.ek)),
                valueOf: (b) => b.ek,
              ),
              SortableColumn(
                label: 'Umsatz',
                numeric: true,
                builder: (b) => Text(money.format(b.revenue)),
                valueOf: (b) => b.revenue,
              ),
              SortableColumn(
                label: 'Offen',
                numeric: true,
                builder: (b) => Text(money.format(b.openAmount),
                    style: TextStyle(
                      color: b.openAmount > 0
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    )),
                valueOf: (b) => b.openAmount,
              ),
              SortableColumn(
                label: 'LTV (Profit)',
                numeric: true,
                builder: (b) => Text(
                  money.format(b.profit),
                  style: TextStyle(
                    color: b.profit >= 0
                        ? const Color(0xFF059669)
                        : const Color(0xFFDC2626),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                valueOf: (b) => b.profit,
              ),
              SortableColumn(
                label: 'Ø Order',
                numeric: true,
                builder: (b) => Text(money.format(b.avgOrderValue)),
                valueOf: (b) => b.avgOrderValue,
              ),
              SortableColumn(
                label: 'Frequenz',
                numeric: true,
                builder: (b) =>
                    Text('${b.frequencyPerMonth.toStringAsFixed(1)}/Mon'),
                valueOf: (b) => b.frequencyPerMonth,
              ),
              SortableColumn(
                label: 'First',
                builder: (b) => Text(dateFmt.format(b.firstDeal)),
                valueOf: (b) => b.firstDeal.millisecondsSinceEpoch,
              ),
              SortableColumn(
                label: 'Last',
                builder: (b) => Text(dateFmt.format(b.lastDeal)),
                valueOf: (b) => b.lastDeal.millisecondsSinceEpoch,
              ),
              SortableColumn(
                label: 'Tage aktiv',
                numeric: true,
                builder: (b) => Text('${b.activeDays}'),
                valueOf: (b) => b.activeDays,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFCA5A5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 16, color: Color(0xFF991B1B)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Käufer mit rotem Punkt waren > 60 Tage inaktiv (kein Deal im aktuellen Filter-Zeitraum).',
                  style: TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
