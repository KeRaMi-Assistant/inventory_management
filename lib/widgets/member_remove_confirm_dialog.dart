import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';

/// AlertDialog für die destruktive Member-Remove-Bestätigung.
///
/// Rückgabe: `true` = User hat bestätigt, `false`/null = abgebrochen.
/// Verwendung:
/// ```dart
/// final confirmed = await MemberRemoveConfirmDialog.show(context, email);
/// if (confirmed) { /* remove member */ }
/// ```
class MemberRemoveConfirmDialog extends StatelessWidget {
  const MemberRemoveConfirmDialog({super.key, required this.email});

  final String email;

  static Future<bool> show(BuildContext context, String email) async {
    return (await showDialog<bool>(
          context: context,
          builder: (_) => MemberRemoveConfirmDialog(email: email),
        )) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      key: const Key('member-remove-confirm-dialog'),
      title: Text(l10n.teamMemberRemoveConfirmTitle),
      content: Text(l10n.teamMemberRemoveConfirmBody(email)),
      actions: [
        TextButton(
          key: const Key('member-remove-cancel-btn'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('member-remove-confirm-btn'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.dangerTextOf(context),
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.teamMemberRemove),
        ),
      ],
    );
  }
}
