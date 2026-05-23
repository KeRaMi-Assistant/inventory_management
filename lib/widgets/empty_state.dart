import 'package:flutter/material.dart';

import '../app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EmptyState
// ─────────────────────────────────────────────────────────────────────────────

/// Gemeinsames Empty-State-Widget für alle Screens.
///
/// Zeigt Icon, Titel, Subtitle und optional eine CTA-Schaltfläche zentriert
/// an. Alle sichtbaren Strings kommen vom Caller via l10n — dieses Widget
/// hardcodet keine Strings.
///
/// Übernimmt das Pattern der bisherigen lokalen `_EmptyState`-Widgets in
/// `categories_screen.dart`, `warehouses_screen.dart` etc. und vereinheitlicht
/// es als wiederverwendbare Komponente.
///
/// **A11y:** `Key('emptyState-<keySlug>')` auf dem Root-Container, damit der
/// Browser-Tester den State ansprechen kann. [keySlug] ist optional; Standard
/// ist `"default"`.
///
/// **Mobile-First:** Funktioniert auf 360×640 ohne horizontalen Overflow.
/// Padding (32 dp rundum) begrenzt den Content auf mindestens 296 px auf dem
/// kleinsten Phone; kein `FittedBox` — Text darf umbrechen.
///
/// Beispiel:
/// ```dart
/// EmptyState(
///   icon: Icons.category_outlined,
///   title: l10n.categoriesEmpty,
///   subtitle: l10n.categoriesEmptyHint,
///   action: ElevatedButton(
///     onPressed: _openAddDialog,
///     child: Text(l10n.categoryNew),
///   ),
/// )
/// ```
class EmptyState extends StatelessWidget {
  /// Pflicht-Icon. Größe wird intern auf 56 gesetzt.
  final IconData icon;

  /// Pflicht-Titel (fett, 16 sp). Vom Caller via l10n übergeben.
  final String title;

  /// Pflicht-Subtitle (normal, 14 sp). Vom Caller via l10n übergeben.
  final String subtitle;

  /// Optionale CTA-Schaltfläche (z.B. `ElevatedButton` oder `TextButton`).
  /// Wird unterhalb des Subtitles mit 16 dp Abstand angezeigt.
  final Widget? action;

  /// Slug für den A11y-Key (`Key('emptyState-<keySlug>')`).
  /// Standard: `"default"`.
  final String keySlug;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.keySlug = 'default',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          key: Key('emptyState-$keySlug'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 56,
                color: AppTheme.textMutedOf(context),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryOf(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textMutedOf(context),
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: 16),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
