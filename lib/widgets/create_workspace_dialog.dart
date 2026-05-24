import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/workspace.dart';
import '../providers/active_workspace_provider.dart';
import '../providers/billing_provider.dart';
import '../services/workspace_service.dart';
import 'app_feedback.dart';
import 'limit_reached_dialog.dart';

/// Bottom-Sheet zum Anlegen eines neuen Workspace.
///
/// Verwendung:
/// ```dart
/// final ws = await CreateWorkspaceDialog.show(context);
/// if (ws != null) {
///   ScaffoldMessenger.of(context).showSnackBar(
///     SnackBar(content: Text(l10n.teamWorkspacesCreateSuccess(ws.name))),
///   );
/// }
/// ```
class CreateWorkspaceDialog extends StatefulWidget {
  const CreateWorkspaceDialog({super.key});

  static Future<Workspace?> show(BuildContext context) {
    return showModalBottomSheet<Workspace?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const CreateWorkspaceDialog(),
    );
  }

  @override
  State<CreateWorkspaceDialog> createState() => _CreateWorkspaceDialogState();
}

class _CreateWorkspaceDialogState extends State<CreateWorkspaceDialog> {
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  String? _nameError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final nameClean = _nameCtrl.text.trim();

    if (nameClean.isEmpty || nameClean.length > 80) {
      setState(() => _nameError = l10n.teamWorkspacesCreateValidationLength);
      return;
    }
    setState(() {
      _nameError = null;
      _loading = true;
    });

    // Dialog-Context-Pattern: capture messenger + rootContext before any
    // Navigator.pop() call so the SnackBar is shown on the root Scaffold,
    // not on the already-closing bottom-sheet context.
    final messenger = ScaffoldMessenger.of(context);
    final rootContext = context;

    try {
      final currentUserId =
          Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) {
        if (!mounted) return;
        Navigator.of(context).pop(null);
        if (!rootContext.mounted) return;
        AppFeedback.errorOn(
          messenger,
          l10n.appFeedbackErrorDefault,
          rootContext: rootContext,
        );
        return;
      }
      final wsProvider =
          Provider.of<ActiveWorkspaceProvider>(context, listen: false);
      final ws = await wsProvider.createAndSwitchTo(
        name: nameClean,
        currentUserId: currentUserId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(ws);
    } on WorkspaceLimitException {
      if (!mounted) return;
      Navigator.of(context).pop(null);
      if (!rootContext.mounted) return;
      await LimitReachedDialog.show(rootContext);
    } on ArgumentError {
      if (!mounted) return;
      Navigator.of(context).pop(null);
      if (!rootContext.mounted) return;
      AppFeedback.errorOn(
        messenger,
        l10n.teamWorkspacesCreateValidationLength,
        rootContext: rootContext,
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop(null);
      if (!rootContext.mounted) return;
      AppFeedback.errorOn(
        messenger,
        l10n.appFeedbackErrorDefault,
        rootContext: rootContext,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final billing = Provider.of<BillingProvider>(context, listen: false);
    final wsProvider = Provider.of<ActiveWorkspaceProvider>(context);
    final plan = billing.currentPlan;
    final usedCount = wsProvider.workspaces.length;
    final limit = plan.workspaceLimit;

    final planUsageText = limit == -1
        ? l10n.teamWorkspacesPlanUsageUnlimited(plan.label, usedCount)
        : l10n.teamWorkspacesPlanUsage(plan.label, usedCount, limit);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.teamWorkspacesCreateTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.textPrimaryOf(context),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  IconButton(
                    key: const Key('create-ws-close-btn'),
                    icon: const Icon(Icons.close),
                    tooltip: l10n.commonCancel,
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Name field
              TextField(
                key: const Key('create-ws-name-field'),
                controller: _nameCtrl,
                autofocus: true,
                maxLength: 80,
                enabled: !_loading,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: l10n.teamWorkspacesCreateLabel,
                  hintText: l10n.teamWorkspacesCreateHint,
                  errorText: _nameError,
                  errorStyle: TextStyle(
                    color: AppTheme.dangerTextOf(context),
                    fontSize: 12,
                  ),
                ),
                onChanged: (_) {
                  if (_nameError != null) {
                    setState(() => _nameError = null);
                  }
                },
              ),
              const SizedBox(height: 8),
              // Plan usage info
              Text(
                planUsageText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMutedOf(context),
                    ),
              ),
              const SizedBox(height: 16),
              // Submit button
              SizedBox(
                height: 48,
                child: FilledButton(
                  key: const Key('create-ws-submit-btn'),
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(l10n.teamWorkspacesCreateSubmit),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
