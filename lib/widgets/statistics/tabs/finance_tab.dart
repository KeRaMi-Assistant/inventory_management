import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/statistics_service.dart';
import '../../../utils/responsive.dart';
import '../charts/heatmap.dart';
import '../sortable_table.dart';
import '../stat_panel.dart';

class FinanceTab extends StatelessWidget {
  final StatisticsService stats;
  final VoidCallback? onExportTax;
  const FinanceTab({super.key, required this.stats, this.onExportTax});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final money = NumberFormat.currency(locale: localeTag, symbol: '€');
    final dateFmt = DateFormat.yMd(localeTag);
    final cf = stats.cashflow;
    final goals = stats.goals;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth > Breakpoints.legacyStatsFinanceWide;
            final cashflowPanel = StatPanel(
              title: l10n.statsCashflow,
              icon: Icons.account_balance_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _CashStat(
                          label: l10n.statsReceived,
                          value: money.format(cf.received),
                          color: const Color(0xFF059669),
                          icon: Icons.arrow_downward,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _CashStat(
                          label: l10n.statsOutstanding,
                          value: money.format(cf.totalOpen),
                          color: const Color(0xFFD97706),
                          icon: Icons.hourglass_empty,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.statsAgingHeading,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _AgingBars(cf: cf),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _CashStat(
                          label: 'Ø',
                          value: cf.avgPaymentDays.toStringAsFixed(1),
                          color: const Color(0xFF2563EB),
                          icon: Icons.timer_outlined,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: cf.oldestDeal == null
                            ? _CashStat(
                                label: l10n.statsOldestOpen,
                                value: '—',
                                color: const Color(0xFF6B7280),
                                icon: Icons.event_outlined,
                              )
                            : _CashStat(
                                label: l10n.statsOldestOpen,
                                value:
                                    '${cf.oldestDaysOpen} · ${money.format(cf.oldestDeal!.zuBekommen ?? 0)}',
                                color: const Color(0xFFDC2626),
                                icon: Icons.event_outlined,
                                subtitle:
                                    '${cf.oldestDeal!.buyer ?? '—'} · ${dateFmt.format(cf.oldestDeal!.orderDate)}',
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            );
            final goalsPanel = StatPanel(
              title: l10n.statsForecast,
              icon: Icons.flag_outlined,
              child: _GoalsContent(goals: goals),
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: cashflowPanel),
                  const SizedBox(width: 16),
                  Expanded(child: goalsPanel),
                ],
              );
            }
            return Column(children: [
              cashflowPanel,
              const SizedBox(height: 16),
              goalsPanel,
            ]);
          },
        ),
        const SizedBox(height: 16),
        StatPanel(
          title: '12 ${l10n.statsCurrentMonth}',
          icon: Icons.calendar_view_month_outlined,
          child: ProfitHeatmap(data: stats.heatmap),
        ),
        const SizedBox(height: 16),
        StatPanel(
          title: '${l10n.statsTax} · ${l10n.statsTabFinance}',
          icon: Icons.receipt_long_outlined,
          padding: const EdgeInsets.symmetric(vertical: 4),
          trailing: TextButton.icon(
            onPressed: onExportTax,
            icon: const Icon(Icons.file_download_outlined, size: 16),
            label: Text(l10n.statsExportCsvTitle),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB)),
          ),
          child: SortableTable<TaxQuarterReport>(
            rows: stats.taxReports,
            defaultSortIndex: 0,
            defaultAscending: false,
            columns: [
              SortableColumn(
                label: l10n.statsQuarter,
                builder: (r) => Text(r.label,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                valueOf: (r) => r.year * 10 + r.quarter,
              ),
              SortableColumn(
                label: l10n.statsCurrency,
                builder: (r) => Text(r.currency,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                valueOf: (r) => r.currency,
              ),
              SortableColumn(
                label: l10n.statsDealsLabel,
                numeric: true,
                builder: (r) => Text('${r.dealCount}'),
                valueOf: (r) => r.dealCount,
              ),
              SortableColumn(
                label: l10n.statsNet,
                numeric: true,
                builder: (r) => Text(_format(localeTag, r.netto, r.currency)),
                valueOf: (r) => r.netto,
              ),
              SortableColumn(
                label: l10n.statsTax,
                numeric: true,
                builder: (r) => Text(_format(localeTag, r.tax, r.currency),
                    style: const TextStyle(
                        color: Color(0xFFD97706),
                        fontWeight: FontWeight.w700)),
                valueOf: (r) => r.tax,
              ),
              SortableColumn(
                label: l10n.statsGross,
                numeric: true,
                builder: (r) => Text(_format(localeTag, r.brutto, r.currency)),
                valueOf: (r) => r.brutto,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _format(String localeTag, double v, String currency) {
    final symbol = switch (currency) {
      'EUR' => '€',
      'USD' => r'$',
      'GBP' => '£',
      'CHF' => 'CHF',
      _ => currency,
    };
    return NumberFormat.currency(locale: localeTag, symbol: symbol).format(v);
  }
}

class _CashStat extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final Color color;
  final IconData icon;
  const _CashStat({
    required this.label,
    required this.value,
    this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!,
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFF9CA3AF))),
          ],
        ],
      ),
    );
  }
}

class _AgingBars extends StatelessWidget {
  final CashflowReport cf;
  const _AgingBars({required this.cf});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final money = NumberFormat.currency(locale: localeTag, symbol: '€');
    final total = cf.totalOpen;
    if (total == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(l10n.dealCommentEmpty,
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
      );
    }
    final segments = [
      ('0–7', cf.bucket0_7, const Color(0xFF059669)),
      ('8–30', cf.bucket8_30, const Color(0xFFD97706)),
      ('31–60', cf.bucket31_60, const Color(0xFFEA580C)),
      ('> 60', cf.bucket60p, const Color(0xFFDC2626)),
    ];
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                for (final s in segments)
                  if (s.$2 > 0)
                    Expanded(
                      flex: math.max(1, ((s.$2 / total) * 1000).round()),
                      child: Tooltip(
                        message: '${s.$1}: ${money.format(s.$2)}',
                        child: Container(color: s.$3),
                      ),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final s in segments)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: s.$3, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${s.$1}: ${money.format(s.$2)}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF374151)),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _GoalsContent extends StatelessWidget {
  final GoalProgress goals;
  const _GoalsContent({required this.goals});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final money = NumberFormat.currency(locale: localeTag, symbol: '€');
    final progress = (goals.progressPct / 100).clamp(0.0, 1.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CircularProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    strokeWidth: 12,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation(
                      progress >= 1.0
                          ? const Color(0xFF059669)
                          : progress >= 0.7
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFD97706),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${goals.progressPct.toStringAsFixed(0)}%',
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827)),
                    ),
                    Text(
                      l10n.statsCurrentMonth,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _GoalRow(label: l10n.statsCurrent, value: money.format(goals.currentProfit)),
        _GoalRow(label: l10n.statsTarget, value: money.format(goals.target)),
        _GoalRow(
          label: l10n.statsForecast,
          value: money.format(goals.forecast),
          highlight: goals.forecast >= goals.target,
        ),
        const Divider(height: 24),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.local_fire_department,
                  size: 18, color: Color(0xFFEA580C)),
            ),
            const SizedBox(width: 10),
            Text(
              '${goals.streak}',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827)),
            ),
            const Spacer(),
            Text(
              goals.streak == 0
                  ? l10n.statsGoalNotMet
                  : l10n.statsGoalsInRow,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ],
    );
  }
}

class _GoalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _GoalRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: highlight
                  ? const Color(0xFF059669)
                  : const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}
