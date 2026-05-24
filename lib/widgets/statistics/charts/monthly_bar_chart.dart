import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/statistics_service.dart';

/// Bar-Chart für Profit pro Bucket (Tag/Woche/Monat). Optional zwei Bars
/// nebeneinander, wenn ein Vergleichszeitraum gegeben ist.
class MonthlyBarChart extends StatelessWidget {
  final List<TimeBucket> series;
  final List<TimeBucket>? comparison;
  final double height;
  /// Optionaler Titel — wird als Teil des Semantics-Labels für Screen-Reader
  /// genutzt. Muss nicht identisch zum StatPanel-Titel sein, aber aussagekräftig.
  final String? title;
  const MonthlyBarChart({
    super.key,
    required this.series,
    this.comparison,
    this.height = 220,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (series.isEmpty) {
      return Semantics(
        label: l10n.semanticsChartLoading,
        excludeSemantics: true,
        child: SizedBox(
          height: height,
          child: const Center(
            child: Text('Keine Daten im Zeitraum.',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
          ),
        ),
      );
    }

    final money = NumberFormat.compactCurrency(locale: 'de_DE', symbol: '€');
    final dateFmt = _dateFormatFor(series.first.granularity);
    final hasCompare = comparison != null && comparison!.isNotEmpty;

    // Semantics-Berechnung: höchster absoluter Profit-Wert
    TimeBucket? topBucket;
    for (final b in series) {
      if (topBucket == null || b.profit.abs() > topBucket.profit.abs()) {
        topBucket = b;
      }
    }
    final semanticsLabel = l10n.semanticsChartBar(
      title ?? '',
      series.length,
      topBucket != null ? money.format(topBucket.profit) : '—',
      topBucket != null ? dateFmt.format(topBucket.date) : '—',
    );

    double maxY = 0;
    double minY = 0;
    for (final b in series) {
      if (b.profit > maxY) maxY = b.profit;
      if (b.profit < minY) minY = b.profit;
    }
    if (hasCompare) {
      for (final b in comparison!) {
        if (b.profit > maxY) maxY = b.profit;
        if (b.profit < minY) minY = b.profit;
      }
    }
    if (maxY == 0) maxY = 100;
    final yPadding = (maxY - minY).abs() * 0.1;

    final groups = <BarChartGroupData>[];
    for (var i = 0; i < series.length; i++) {
      final b = series[i];
      final compVal =
          hasCompare && i < comparison!.length ? comparison![i].profit : null;
      groups.add(BarChartGroupData(
        x: i,
        barsSpace: 2,
        barRods: [
          BarChartRodData(
            toY: b.profit,
            color: b.profit >= 0
                ? const Color(0xFF059669)
                : const Color(0xFFDC2626),
            width: hasCompare ? 8 : 14,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(3),
              topRight: Radius.circular(3),
            ),
          ),
          if (compVal != null)
            BarChartRodData(
              toY: compVal,
              color: const Color(0xFFCBD5E1),
              width: 8,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(3),
                topRight: Radius.circular(3),
              ),
            ),
        ],
      ));
    }

    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          minY: minY - yPadding,
          maxY: maxY + yPadding,
          alignment: BarChartAlignment.spaceAround,
          barGroups: groups,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval:
                ((maxY - minY) / 4).abs().clamp(1, double.infinity),
            getDrawingHorizontalLine: (_) => const FlLine(
              color: Color(0xFFEEF2F7),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 56,
                getTitlesWidget: (v, _) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    money.format(v),
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF9CA3AF)),
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval:
                    (series.length / 6).ceilToDouble().clamp(1, double.infinity),
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= series.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      dateFmt.format(series[i].date),
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF9CA3AF)),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF111827),
              tooltipRoundedRadius: 8,
              getTooltipItem: (group, gIdx, rod, rIdx) {
                if (group.x < 0 || group.x >= series.length) return null;
                final b = series[group.x];
                final isCompare = rIdx == 1;
                return BarTooltipItem(
                  '${isCompare ? 'Vorher' : 'Profit'}\n${money.format(rod.toY)}\n${dateFmt.format(b.date)}',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ), // SizedBox
    ); // Semantics
  }

  DateFormat _dateFormatFor(Granularity g) {
    switch (g) {
      case Granularity.day:
        return DateFormat('dd.MM', 'de_DE');
      case Granularity.week:
        return DateFormat('dd.MM', 'de_DE');
      case Granularity.month:
        return DateFormat('MMM yy', 'de_DE');
    }
  }
}

/// Linien-Chart der Profit-Marge in % über die Zeit.
class MarginLineChart extends StatelessWidget {
  final List<TimeBucket> series;
  final double height;
  /// Optionaler Titel — wird als Teil des Semantics-Labels für Screen-Reader genutzt.
  final String? title;
  const MarginLineChart({super.key, required this.series, this.height = 200, this.title});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (series.isEmpty) {
      return Semantics(
        label: l10n.semanticsChartLoading,
        excludeSemantics: true,
        child: SizedBox(
          height: height,
          child: const Center(
            child: Text('Keine Daten.',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
          ),
        ),
      );
    }
    final dateFmt = _dateFormatFor(series.first.granularity);
    final spots = <FlSpot>[];
    double maxY = 0, minY = 0;
    TimeBucket? topBucket;
    for (var i = 0; i < series.length; i++) {
      final m = series[i].marginPct;
      spots.add(FlSpot(i.toDouble(), m));
      if (m > maxY) maxY = m;
      if (m < minY) minY = m;
      if (topBucket == null || m > topBucket.marginPct) topBucket = series[i];
    }
    if (maxY == 0) maxY = 10;
    final yPadding = ((maxY - minY).abs() * 0.1).clamp(2.0, double.infinity);

    final semanticsLabel = l10n.semanticsChartLine(
      title ?? '',
      series.length,
      topBucket != null ? '${topBucket.marginPct.toStringAsFixed(1)}%' : '—',
      topBucket != null ? dateFmt.format(topBucket.date) : '—',
    );

    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: minY - yPadding,
          maxY: maxY + yPadding,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval:
                ((maxY - minY) / 4).abs().clamp(1, double.infinity),
            getDrawingHorizontalLine: (_) => const FlLine(
              color: Color(0xFFEEF2F7),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (v, _) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text('${v.toStringAsFixed(0)}%',
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF9CA3AF)),
                      textAlign: TextAlign.right),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: (series.length / 6).ceilToDouble().clamp(1, double.infinity),
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= series.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      dateFmt.format(series[i].date),
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF9CA3AF)),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF111827),
              tooltipRoundedRadius: 8,
              getTooltipItems: (spots) => spots.map((s) {
                final i = s.x.toInt();
                final b = (i >= 0 && i < series.length) ? series[i] : null;
                final dateStr = b != null ? dateFmt.format(b.date) : '';
                return LineTooltipItem(
                  'Marge ${s.y.toStringAsFixed(1)}%\n$dateStr',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: const Color(0xFF7C3AED),
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF7C3AED).withAlpha(20),
              ),
            ),
          ],
        ),
      ),
    ), // SizedBox
    ); // Semantics
  }

  DateFormat _dateFormatFor(Granularity g) {
    switch (g) {
      case Granularity.day:
        return DateFormat('dd.MM', 'de_DE');
      case Granularity.week:
        return DateFormat('dd.MM', 'de_DE');
      case Granularity.month:
        return DateFormat('MMM yy', 'de_DE');
    }
  }
}
