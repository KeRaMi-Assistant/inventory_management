import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../utils/responsive.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppScreenScaffold
// ─────────────────────────────────────────────────────────────────────────────

/// Generisches Scaffold-Wrapper-Widget mit `maxWidth`-Content-Container für
/// Desktop und vollbreitem Layout auf Phone.
///
/// **Warum dieses Widget?**
/// Alle Screen-Level-Scaffolds bauen heute ihren AppBar/SafeArea/Body-Stack
/// neu. `AppScreenScaffold` zieht diese Logik heraus und fügt einen
/// `maxWidth`-Container hinzu, damit Screens auf Desktop nicht als
/// gestreckte Phone-Säulen erscheinen (Kernproblem §0.2 aus dem
/// Responsive-Overhaul-Plan).
///
/// **Layout-Verhalten:**
/// - **Phone/Compact** (`constraints.maxWidth < Breakpoints.phone`):
///   Content füllt die gesamte verfügbare Breite.
/// - **Tablet/Desktop** (`constraints.maxWidth ≥ Breakpoints.phone`):
///   Content wird auf [maxContentWidth] begrenzt und horizontal zentriert.
/// - Die Breitenklasse wird über `widthClassOf(constraints.maxWidth)` aus
///   einem `LayoutBuilder` bestimmt — **niemals** `MediaQuery`, da die
///   Desktop-Sidebar die nutzbare Breite reduziert (Viewport-vs-Container-
///   Bug-Mitigation, Plan §5.1).
///
/// **Pflicht-Slots:**
/// - [body]: Pflicht. Der Haupt-Inhalt des Screens.
/// - [appBar]: Optional. Wenn vorhanden, wird es als `Scaffold.appBar`
///   gesetzt (kein Re-Wrapping).
/// - [floatingActionButton]: Optional. Durchgereicht an `Scaffold.floatingActionButton`.
///
/// **Optionale Slots:**
/// - [header]: Schmaler Sub-Header unterhalb der AppBar, z.B. für
///   Filter/Search-Bars. Wird ebenfalls im `maxWidth`-Container gehalten.
/// - [isEmpty] + [emptyState]: Wenn `isEmpty == true`, rendert das Widget
///   [emptyState] statt [body]. Pragmatisch: kein zusätzlicher
///   State-Provider nötig.
///
/// **A11y:** `Key('appScreenContent')` auf dem `maxWidth`-Container, damit
/// Browser-Tester ihn ansprechen kann.
///
/// **Mobile-First:** `SafeArea` um den gesamten Scroll-Bereich — schützt vor
/// Notch und Home-Indicator auf iPhone/Android.
///
/// Beispiel:
/// ```dart
/// AppScreenScaffold(
///   appBar: AppBar(title: Text(l10n.categoriesTitle)),
///   floatingActionButton: FloatingActionButton.extended(
///     key: const Key('categoryNewFab'),
///     onPressed: _openAddDialog,
///     icon: const Icon(Icons.add),
///     label: Text(l10n.categoryNew),
///   ),
///   isEmpty: categories.isEmpty,
///   emptyState: EmptyState(
///     icon: Icons.category_outlined,
///     title: l10n.categoriesEmpty,
///     subtitle: l10n.categoriesEmptyHint,
///     keySlug: 'categories',
///   ),
///   body: _CategoryList(items: categories),
/// )
/// ```
class AppScreenScaffold extends StatelessWidget {
  /// AppBar. Optional — wenn `null`, kein AppBar (für eingebettete Screens).
  final PreferredSizeWidget? appBar;

  /// Haupt-Inhalt. Wird durch [isEmpty] übersteuert wenn `true`.
  final Widget body;

  /// FAB — durchgereicht an `Scaffold.floatingActionButton`.
  final Widget? floatingActionButton;

  /// Optionaler Sub-Header unter der AppBar, z.B. für Filter/Search-Bar.
  /// Wird im selben `maxWidth`-Container wie [body] gerendert.
  final Widget? header;

  /// Wenn `true` und [emptyState] gesetzt ist, wird [emptyState] statt
  /// [body] gerendert.
  final bool isEmpty;

  /// Empty-State-Widget. Nur sichtbar wenn `isEmpty == true`.
  final Widget? emptyState;

  /// Maximale Content-Breite auf Tablet/Desktop. Default: 1200 px.
  /// Auf Phone (Container-Breite < [Breakpoints.phone]) hat diese Konstante
  /// keine Wirkung — Content füllt dann immer die ganze Breite.
  final double maxContentWidth;

  const AppScreenScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.header,
    this.isEmpty = false,
    this.emptyState,
    this.maxContentWidth = 1200,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgAppOf(context),
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wc = widthClassOf(constraints.maxWidth);
            final isCompactWidth = wc == WidthClass.compact;

            // Determine which content widget to render.
            final content = (isEmpty && emptyState != null)
                ? emptyState!
                : body;

            // On compact (phone), no horizontal constraint — fill the width.
            // On medium/expanded/large (tablet/desktop), center and limit.
            Widget contentArea;
            if (isCompactWidth) {
              contentArea = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ?header,
                  Expanded(child: content),
                ],
              );
            } else {
              contentArea = Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ?header,
                      Expanded(child: content),
                    ],
                  ),
                ),
              );
            }

            return Container(
              key: const Key('appScreenContent'),
              color: AppTheme.bgAppOf(context),
              child: contentArea,
            );
          },
        ),
      ),
    );
  }
}
