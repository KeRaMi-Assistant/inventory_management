import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'confirm_dialog.dart';

/// Thin-Wrapper auf [showConfirmDialog] für die destruktive Member-Remove-
/// Bestätigung.
///
/// Rückgabe: `true` = User hat bestätigt, `false`/null = abgebrochen.
/// Alle bestehenden Aufrufer bleiben kompatibel — Signatur ist unverändert.
///
/// Beispiel:
/// ```dart
/// final confirmed = await MemberRemoveConfirmDialog.show(context, email);
/// if (confirmed) { /* remove member */ }
/// ```
class MemberRemoveConfirmDialog {
  MemberRemoveConfirmDialog._();

  static Future<bool> show(BuildContext context, String email) async {
    final l10n = AppLocalizations.of(context);
    return showConfirmDialog(
      context: context,
      title: l10n.teamMemberRemoveConfirmTitle,
      message: l10n.teamMemberRemoveConfirmBody(email),
      confirmLabel: l10n.teamMemberRemove,
      isDestructive: true,
    );
  }
}
