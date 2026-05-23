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
/// **`cardStyle`:** Wenn `true`, wird der Inhalt in eine Card-artige
/// `BoxDecoration` (Surface-BG, Border, BorderRadius 12) eingebettet.
/// Nützlich z.B. auf dem Dashboard, wo der Empty-State als prominentes
/// Onboarding-Panel innerhalb des Scrollbereichs gerendert wird — nicht
/// zentriert auf leerem Screen.
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

  /// Wenn `true`, wird der Empty-State in eine Card-artige Wrapper-Box
  /// (`bgSurface` + Border) eingebettet statt auf leerem Hintergrund zentriert.
  ///
  /// Einsatz z.B. auf dem Dashboard, wo der Empty-State als Panel im
  /// Scrollbereich erscheint (nicht als Vollbild-Centered-State).
  /// Standard: `false`.
  final bool cardStyle;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.keySlug = 'default',
    this.cardStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      key: Key('emptyState-$keySlug'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          cardStyle ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 56,
          color: AppTheme.textMutedOf(context),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: cardStyle ? TextAlign.start : TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: cardStyle ? TextAlign.start : TextAlign.center,
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
    );

    if (cardStyle) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.bgSurfaceOf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderOf(context)),
        ),
        child: content,
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: content,
      ),
    );
  }
}
