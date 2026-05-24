/// AppFeedback — Zentraler SnackBar-Helper für konsistentes User-Feedback.
///
/// Alle Methoden arbeiten entweder mit [BuildContext] (Standard-Variante)
/// oder direkt mit [ScaffoldMessengerState] (Dialog-Context-Pattern, s.u.).
///
/// **Farbkodierung:**
/// - success → [AppTheme.successBgOf] + [AppTheme.successTextOf]
/// - error   → [AppTheme.dangerBgOf]  + [AppTheme.dangerTextOf]
/// - info    → [AppTheme.infoBgOf]    + [AppTheme.infoTextOf]
///
/// **Bottom-Margin auf Phone:**
/// Die SnackBar liegt standardmäßig über der Bottom-Navigation (80 dp
/// + SafeArea-Bottom-Inset + 8 dp Abstand). Auf Desktop/Tablet ist der
/// Abstand 16 dp.
///
/// **Dialog-Context-Pattern:**
/// Wenn du AppFeedback aus einem Dialog aufrufst, wird die SnackBar
/// ggf. nicht angezeigt, weil der Dialog-Scaffold-Messenger gleichzeitig
/// schließt. Nutze stattdessen das Messenger-Overload:
///
/// ```dart
/// // Root-Scaffold-Messenger *vor* dem Dialog merken:
/// final messenger = ScaffoldMessenger.of(context);
/// final l10n = AppLocalizations.of(context);
/// final confirmed = await showConfirmDialog(context, /* … */);
/// if (confirmed == true) {
///   await repo.delete(item);
///   AppFeedback.successOn(messenger, l10n.feedbackSuccessDefault);
/// }
/// ```
///
/// Wenn der Dialog bereits geschlossen ist und der Context noch mounted ist:
/// ```dart
/// Navigator.of(context).pop();  // Dialog schließen
/// if (context.mounted) AppFeedback.success(context, l10n.savedSuccessfully);
/// ```
library;

import 'package:flutter/material.dart';
import 'package:inventory_management/app_theme.dart';
import 'package:inventory_management/l10n/app_localizations.dart';
import 'package:inventory_management/utils/responsive.dart';

/// M3 NavigationBar-Standardhöhe (dp). Identisch mit dem impliziten Default
/// des [NavigationBar]-Widgets, das in `main_screen.dart` verwendet wird.
const double kBottomNavHeight = 80.0;

abstract class AppFeedback {
  // ── Convenience-Konstanten ─────────────────────────────────────────────────

  /// Dauer für Success- und Info-SnackBars (4 Sekunden).
  static const Duration _durationNormal = Duration(seconds: 4);

  /// Dauer für Error-SnackBars (6 Sekunden — etwas länger, damit der User
  /// den Fehlertext lesen kann).
  static const Duration _durationError = Duration(seconds: 6);

  // ── Context-Varianten (Standard) ─────────────────────────────────────────

  /// Zeigt eine grüne Erfolgs-SnackBar.
  ///
  /// [onUndo] und [undoLabel] sind optional. Wenn [onUndo] gesetzt ist,
  /// wird eine „Rückgängig"-Action angezeigt.
  static void success(
    BuildContext context,
    String message, {
    VoidCallback? onUndo,
    String? undoLabel,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final resolvedUndoLabel = undoLabel ?? l10n.appFeedbackUndoAction;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        _buildSnackBar(
          key: const Key('appFeedbackSuccess'),
          message: message,
          bgColor: AppTheme.successBgOf(context),
          textColor: AppTheme.successTextOf(context),
          icon: Icons.check_circle_outline_rounded,
          duration: _durationNormal,
          bottomMargin: _bottomMargin(context),
          action: onUndo != null
              ? SnackBarAction(
                  key: const Key('appFeedbackUndoAction'),
                  label: resolvedUndoLabel,
                  textColor: AppTheme.successTextOf(context),
                  onPressed: onUndo,
                )
              : null,
        ),
      );
  }

  /// Zeigt eine rote Fehler-SnackBar.
  static void error(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        _buildSnackBar(
          key: const Key('appFeedbackError'),
          message: message,
          bgColor: AppTheme.dangerBgOf(context),
          textColor: AppTheme.dangerTextOf(context),
          icon: Icons.error_outline_rounded,
          duration: _durationError,
          bottomMargin: _bottomMargin(context),
        ),
      );
  }

  /// Zeigt eine blaue Info-SnackBar.
  static void info(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        _buildSnackBar(
          key: const Key('appFeedbackInfo'),
          message: message,
          bgColor: AppTheme.infoBgOf(context),
          textColor: AppTheme.infoTextOf(context),
          icon: Icons.info_outline_rounded,
          duration: _durationNormal,
          bottomMargin: _bottomMargin(context),
        ),
      );
  }

  // ── ScaffoldMessengerState-Varianten (Dialog-Context-Pattern) ────────────
  //
  // Diese Varianten nehmen zusätzlich den [BuildContext] des Root-Scaffolds
  // entgegen, um Theme-Farben und l10n korrekt aufzulösen. Der [messenger]
  // wird getrennt übergeben, weil er vor dem Dialog-Close gecaptured werden
  // muss (s. Klassen-Doc-Comment).

  /// Erfolgs-SnackBar via [ScaffoldMessengerState] — für Dialog-Context-
  /// Pattern (s. Klassen-Doc-Comment).
  ///
  /// [rootContext] ist der BuildContext des Root-Scaffolds (außerhalb des
  /// Dialogs), von dem die Theme-Farben und l10n abgeleitet werden.
  static void successOn(
    ScaffoldMessengerState messenger,
    String message, {
    required BuildContext rootContext,
    VoidCallback? onUndo,
    String? undoLabel,
  }) {
    final l10n = AppLocalizations.of(rootContext);
    final resolvedUndoLabel = undoLabel ?? l10n.appFeedbackUndoAction;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        _buildSnackBar(
          key: const Key('appFeedbackSuccess'),
          message: message,
          bgColor: AppTheme.successBgOf(rootContext),
          textColor: AppTheme.successTextOf(rootContext),
          icon: Icons.check_circle_outline_rounded,
          duration: _durationNormal,
          bottomMargin: _bottomMargin(rootContext),
          action: onUndo != null
              ? SnackBarAction(
                  key: const Key('appFeedbackUndoAction'),
                  label: resolvedUndoLabel,
                  textColor: AppTheme.successTextOf(rootContext),
                  onPressed: onUndo,
                )
              : null,
        ),
      );
  }

  /// Fehler-SnackBar via [ScaffoldMessengerState].
  ///
  /// [rootContext] ist der BuildContext des Root-Scaffolds.
  static void errorOn(
    ScaffoldMessengerState messenger,
    String message, {
    required BuildContext rootContext,
  }) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        _buildSnackBar(
          key: const Key('appFeedbackError'),
          message: message,
          bgColor: AppTheme.dangerBgOf(rootContext),
          textColor: AppTheme.dangerTextOf(rootContext),
          icon: Icons.error_outline_rounded,
          duration: _durationError,
          bottomMargin: _bottomMargin(rootContext),
        ),
      );
  }

  /// Info-SnackBar via [ScaffoldMessengerState].
  ///
  /// [rootContext] ist der BuildContext des Root-Scaffolds.
  static void infoOn(
    ScaffoldMessengerState messenger,
    String message, {
    required BuildContext rootContext,
  }) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        _buildSnackBar(
          key: const Key('appFeedbackInfo'),
          message: message,
          bgColor: AppTheme.infoBgOf(rootContext),
          textColor: AppTheme.infoTextOf(rootContext),
          icon: Icons.info_outline_rounded,
          duration: _durationNormal,
          bottomMargin: _bottomMargin(rootContext),
        ),
      );
  }

  // ── Interner Builder ──────────────────────────────────────────────────────

  static SnackBar _buildSnackBar({
    required Key key,
    required String message,
    required Color bgColor,
    required Color textColor,
    required IconData icon,
    required Duration duration,
    required double bottomMargin,
    SnackBarAction? action,
  }) {
    return SnackBar(
      key: key,
      behavior: SnackBarBehavior.floating,
      backgroundColor: bgColor,
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: bottomMargin,
      ),
      duration: duration,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      content: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      action: action,
    );
  }

  // ── Margin-Berechnung ─────────────────────────────────────────────────────

  /// Berechnet den Bottom-Margin für die floating SnackBar.
  ///
  /// Auf Phone (Viewport-Breite < [Breakpoints.phone]):
  ///   Bottom-Nav-Höhe (80 dp) + SafeArea-Inset + 8 dp Puffer.
  ///
  /// Auf Tablet/Desktop:
  ///   16 dp Puffer.
  static double _bottomMargin(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < Breakpoints.phone;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return isPhone ? (kBottomNavHeight + safeBottom + 8.0) : 16.0;
  }
}
