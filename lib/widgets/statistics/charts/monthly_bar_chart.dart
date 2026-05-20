import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app_theme.dart';
import '../../../services/statistics_service.dart';

/// Bar-Chart für Profit pro Bucket (Tag/Woche/Monat). Optional zwei Bars
/// nebeneinander, wenn ein Vergleichszeitraum gegeben ist.
class MonthlyBarChart extends StatelessWidget {
  final List<TimeBucket> series;
  final List<TimeBucket>? comparison;
  final double height;
  const MonthlyBarChart({
    super.key,
    required this.series,
    this.comparison,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('Keine Daten im Zeitraum.',
              style: TextStyle(color: AppTheme.textMutedOf(context), fontSize: 13)),
        ),
      );
    }

    final money = NumberFormat.compactCurrency(locale: 'de_DE', symbol: '€');
    final dateFmt = _dateFormatFor(series.first.granularity);
    final hasCompare = comparison != null && comparison!.isNotEmpty;

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

    return SizedBox(
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
              color: AppTheme.bgSubtle,
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
                        fontSize: 10, color: AppTheme.textDisabled),
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
                          fontSize: 10, color: AppTheme.textDisabled),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppTheme.textPrimary,
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
    );
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
  const MarginLineChart({super.key, required this.series, this.height = 200});

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('Keine Daten.',
              style: TextStyle(color: AppTheme.textMutedOf(context), fontSize: 13)),
        ),
      );
    }
    final dateFmt = _dateFormatFor(series.first.granularity);
    final spots = <FlSpot>[];
    double maxY = 0, minY = 0;
    for (var i = 0; i < series.length; i++) {
      final m = series[i].marginPct;
      spots.add(FlSpot(i.toDouble(), m));
      if (m > maxY) maxY = m;
      if (m < minY) minY = m;
    }
    if (maxY == 0) maxY = 10;
    final yPadding = ((maxY - minY).abs() * 0.1).clamp(2.0, double.infinity);

    return SizedBox(
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
              color: AppTheme.bgSubtle,
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
                          fontSize: 10, color: AppTheme.textDisabled),
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
                          fontSize: 10, color: AppTheme.textDisabled),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppTheme.textPrimary,
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
    );
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
