import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';

/// GitHub-Style Kalender-Heatmap. Zeigt 12 Monate Profit-Aktivität.
/// 4 Stufen: 0, niedrig, mittel, hoch — basierend auf Quantilen.
class ProfitHeatmap extends StatefulWidget {
  final Map<DateTime, double> data;
  const ProfitHeatmap({super.key, required this.data});

  @override
  State<ProfitHeatmap> createState() => _ProfitHeatmapState();
}

class _ProfitHeatmapState extends State<ProfitHeatmap> {
  DateTime? _hoveredDay;

  static const _colors = [
    Color(0xFFF1F5F9), // 0
    Color(0xFFA7F3D0), // niedrig
    Color(0xFF34D399), // mittel
    Color(0xFF059669), // hoch
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 364));
    // Auf Montag der ersten Woche zurücksetzen, damit Spalten = Wochen sind.
    final firstMonday = start.subtract(Duration(days: start.weekday - 1));
    final totalDays = today.difference(firstMonday).inDays + 1;
    final weeks = (totalDays / 7).ceil();

    // Quantile bestimmen
    final values = widget.data.values.where((v) => v > 0).toList()..sort();
    double q1 = 0, q2 = 0;
    if (values.isNotEmpty) {
      q1 = values[(values.length * 0.33).floor()];
      q2 = values[(values.length * 0.66).floor()];
    }

    int level(double v) {
      if (v <= 0) return 0;
      if (v < q1) return 1;
      if (v < q2) return 2;
      return 3;
    }

    final money = NumberFormat.currency(locale: 'de_DE', symbol: '€');
    final dateFmt = DateFormat('EEEE, dd.MM.yyyy', 'de_DE');

    final hovered = _hoveredDay;
    final hoveredVal = hovered == null ? null : widget.data[hovered] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 110,
          child: LayoutBuilder(
            builder: (context, c) {
              const cellSize = 12.0;
              const cellGap = 2.5;
              final scrollable = (cellSize + cellGap) * weeks > c.maxWidth;
              final grid = SizedBox(
                width: (cellSize + cellGap) * weeks,
                child: Stack(
                  children: List.generate(weeks * 7, (i) {
                    final col = i ~/ 7;
                    final row = i % 7;
                    final day = firstMonday.add(Duration(days: col * 7 + row));
                    if (day.isBefore(start.subtract(const Duration(days: 1))) ||
                        day.isAfter(today)) {
                      return const SizedBox();
                    }
                    final v = widget.data[day] ?? 0;
                    final lvl = level(v);
                    final isHovered = hovered != null &&
                        day.year == hovered.year &&
                        day.month == hovered.month &&
                        day.day == hovered.day;
                    return Positioned(
                      left: col * (cellSize + cellGap),
                      top: row * (cellSize + cellGap),
                      child: MouseRegion(
                        onEnter: (_) => setState(() => _hoveredDay = day),
                        onExit: (_) {
                          if (_hoveredDay == day) {
                            setState(() => _hoveredDay = null);
                          }
                        },
                        child: GestureDetector(
                          onTap: () => setState(() => _hoveredDay = day),
                          child: Container(
                            width: cellSize,
                            height: cellSize,
                            decoration: BoxDecoration(
                              color: _colors[lvl],
                              borderRadius: BorderRadius.circular(2),
                              border: isHovered
                                  ? Border.all(
                                      color: const Color(0xFF111827),
                                      width: 1)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              );
              if (scrollable) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: grid,
                );
              }
              return grid;
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            if (hovered != null) ...[
              Icon(Icons.calendar_today_outlined,
                  size: 12, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                '${dateFmt.format(hovered)} — Profit ${money.format(hoveredVal ?? 0)}',
                style:
                    const TextStyle(fontSize: 11, color: Color(0xFF374151)),
              ),
            ] else
              Text(
                AppLocalizations.of(context).heatmapTapHint,
                style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            const Spacer(),
            Text(AppLocalizations.of(context).heatmapLess,
                style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
            const SizedBox(width: 4),
            for (final c in _colors)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            const SizedBox(width: 4),
            Text(AppLocalizations.of(context).heatmapMore,
                style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
          ],
        ),
      ],
    );
  }
}
