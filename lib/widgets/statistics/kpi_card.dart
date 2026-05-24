import 'package:flutter/material.dart';
import '../../app_theme.dart';

/// Kanonisches KPI-Karten-Widget für die gesamte App.
///
/// Ersetzt das frühere `lib/widgets/kpi_card.dart` (left-accent-bar Variante),
/// das in Dashboard `_KpiGrid` genutzt wurde. Alle Screens verwenden jetzt
/// diesen Widget — Dashboard ohne [deltaPct], Statistics mit.
///
/// **Verwendung:**
/// - Dashboard (`dashboard_screen.dart`): `label`/`value`/`icon`/`accent`,
///   kein `deltaPct` → kompakter Look ohne Trend-Zeile.
/// - Statistics (`overview_tab.dart`): vollständige API inkl. Delta-Pfeil.
///
/// Das frühere `lib/widgets/kpi_card.dart` ist gelöscht (T4.1-Dedupe).
class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final double? deltaPct;
  final String? deltaLabel;
  final bool deltaInverted; // bei Forderungen ist "höher" schlechter

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.deltaPct,
    this.deltaLabel,
    this.deltaInverted = false,
  });

  /// Baut das Semantics-Label für Screen-Reader.
  ///
  /// Format: „KPI `label`, Wert `value`" — ohne Trend wenn kein [deltaPct]
  /// vorhanden. Mit Trend: „KPI `label`, Wert `value`, Trend `pct`%[ `deltaLabel`]".
  String _semanticsLabel() {
    if (deltaPct == null) {
      return 'KPI $label, Wert $value';
    }
    final pctStr = '${deltaPct!.abs().toStringAsFixed(1)}%';
    final sign = deltaPct! > 0 ? '+' : (deltaPct! < 0 ? '-' : '');
    final trendStr =
        deltaLabel != null ? '$sign$pctStr $deltaLabel' : '$sign$pctStr';
    return 'KPI $label, Wert $value, Trend $trendStr';
  }

  @override
  Widget build(BuildContext context) {
    final hasDelta = deltaPct != null;
    final isPositive = (deltaPct ?? 0) > 0.01;
    final isNegative = (deltaPct ?? 0) < -0.01;
    final goodDirection = deltaInverted ? isNegative : isPositive;
    final badDirection = deltaInverted ? isPositive : isNegative;
    final deltaColor = goodDirection
        ? AppTheme.successTextOf(context)
        : badDirection
            ? AppTheme.dangerTextOf(context)
            : AppTheme.textMutedOf(context);
    final arrow = isPositive
        ? Icons.arrow_upward
        : isNegative
            ? Icons.arrow_downward
            : Icons.remove;

    return Semantics(
      label: _semanticsLabel(),
      excludeSemantics: true,
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgSurfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withAlpha(
                      Theme.of(context).brightness == Brightness.dark
                          ? 50
                          : 20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMutedOf(context),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimaryOf(context),
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          if (hasDelta)
            Row(
              children: [
                Icon(arrow, size: 12, color: deltaColor),
                const SizedBox(width: 2),
                Text(
                  '${deltaPct!.abs().toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: deltaColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (deltaLabel != null) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      deltaLabel!,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textDisabledOf(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            )
          else
            const SizedBox(height: 12),
        ],
      ),
    ), // Container
    ); // Semantics
  }
}

/// Responsives Grid: 2 Spalten auf Mobile, 3 auf Tablet, 6 auf Desktop.
class KpiGrid extends StatelessWidget {
  final List<Widget> cards;
  const KpiGrid({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cols = w < 480
            ? 2
            : w < 800
                ? 3
                : w < 1200
                    ? 4
                    : 6;
        const gap = 12.0;
        final cardW = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards
              .map((c) => SizedBox(width: cardW, child: c))
              .toList(),
        );
      },
    );
  }
}
