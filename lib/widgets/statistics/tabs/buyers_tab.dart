import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/statistics_service.dart';
import '../sortable_table.dart';
import '../stat_panel.dart';

/// Käufer-Tab: Tabelle mit Cohorts, LTV, Frequenz, etc. Sortierbar.
class BuyersTab extends StatelessWidget {
  final StatisticsService stats;
  const BuyersTab({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final money = NumberFormat.currency(locale: localeTag, symbol: '€');
    final dateFmt = DateFormat.yMd(localeTag);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StatPanel(
          title: l10n.statsTabBuyers,
          icon: Icons.people_outline,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SortableTable<BuyerStat>(
            rows: stats.buyerStats,
            defaultSortIndex: 5,
            defaultAscending: false,
            rowColor: (b) => b.inactive ? const Color(0xFFFEF2F2) : null,
            columns: [
              SortableColumn(
                label: l10n.statsBuyerLabel,
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
                label: l10n.statsDealsLabel,
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
                label: l10n.statsLabelRevenue,
                numeric: true,
                builder: (b) => Text(money.format(b.revenue)),
                valueOf: (b) => b.revenue,
              ),
              SortableColumn(
                label: l10n.statsOpenLabel,
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
                label: l10n.statsLabelProfit,
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
                label: 'Ø',
                numeric: true,
                builder: (b) => Text(money.format(b.avgOrderValue)),
                valueOf: (b) => b.avgOrderValue,
              ),
              SortableColumn(
                label: l10n.statsFrequency,
                numeric: true,
                builder: (b) =>
                    Text(b.frequencyPerMonth.toStringAsFixed(1)),
                valueOf: (b) => b.frequencyPerMonth,
              ),
              SortableColumn(
                label: l10n.statsFirst,
                builder: (b) => Text(dateFmt.format(b.firstDeal)),
                valueOf: (b) => b.firstDeal.millisecondsSinceEpoch,
              ),
              SortableColumn(
                label: l10n.statsLast,
                builder: (b) => Text(dateFmt.format(b.lastDeal)),
                valueOf: (b) => b.lastDeal.millisecondsSinceEpoch,
              ),
              SortableColumn(
                label: l10n.statsActiveDays,
                numeric: true,
                builder: (b) => Text('${b.activeDays}'),
                valueOf: (b) => b.activeDays,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
