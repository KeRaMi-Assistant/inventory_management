import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'confirm_dialog.dart';

/// Wickle den Body eines Dialogs/Forms in diesen Guard. Bei `isDirty: true`
/// wird Back-Button/Pop abgefangen und ein Discard-Confirm via [showConfirmDialog]
/// gezeigt. Pattern:
///
/// ```dart
/// showDialog(context: context, builder: (ctx) {
///   return Dialog(child: UnsavedChangesGuard(
///     isDirty: form.isDirty,
///     child: YourForm(...),
///   ));
/// });
/// ```
///
/// **Wichtig:** Der Guard muss INNERHALB des Dialog-Trees liegen, NICHT
/// um den showDialog-Call. Sonst greift PopScope nicht (showDialog-Routes
/// werden nicht von einem aussen-liegenden PopScope erfasst).
class UnsavedChangesGuard extends StatelessWidget {
  /// Wird der Dialog/Form-Inhalt als „dirty" angezeigt (geaenderte Werte vs. Original)?
  final bool isDirty;

  /// Discard-Dialog-Texte. Wenn null → Default-l10n-Keys.
  final String? discardConfirmTitle;
  final String? discardConfirmMessage;
  final String? discardConfirmLabel;

  /// Optional: zusaetzlicher Callback nach erfolgreichem Discard (z.B. Form-State reset).
  final VoidCallback? onDiscardConfirmed;

  /// Der zu schuetzende Inhalt (Dialog-Body, Form, etc.).
  final Widget child;

  const UnsavedChangesGuard({
    super.key,
    required this.isDirty,
    this.discardConfirmTitle,
    this.discardConfirmMessage,
    this.discardConfirmLabel,
    this.onDiscardConfirmed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      key: const Key('unsavedChangesGuard-dialog'),
      canPop: !isDirty,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return; // Pop bereits passiert
        // Pop wurde von canPop=false geblockt — Discard-Confirm zeigen:
        final navigator = Navigator.of(context);
        final l10n = AppLocalizations.of(context);
        final confirmed = await showConfirmDialog(
          context: context,
          title: discardConfirmTitle ?? l10n.unsavedChangesDiscardTitle,
          message: discardConfirmMessage ?? l10n.unsavedChangesDiscardMessage,
          confirmLabel: discardConfirmLabel ?? l10n.unsavedChangesDiscardLabel,
          isDestructive: true,
        );
        if (confirmed) {
          onDiscardConfirmed?.call();
          navigator.pop();
        }
      },
      child: child,
    );
  }
}
