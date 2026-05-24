import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/billing_profile.dart';
import '../models/workspace.dart';
import '../providers/billing_provider.dart';
import '../services/workspace_service.dart';
import '../utils/error_messages.dart';
import 'app_feedback.dart';

// ---------------------------------------------------------------------------
// InviteMemberDialog — Bottom-Sheet zum Einladen eines Teammitglieds
// ---------------------------------------------------------------------------

class InviteMemberDialog extends StatefulWidget {
  const InviteMemberDialog({
    super.key,
    required this.workspaceId,
    required this.workspaceService,
  });

  final String workspaceId;
  final WorkspaceService workspaceService;

  /// Öffnet das Bottom-Sheet und gibt die erstellte [WorkspaceInvite] zurück,
  /// oder `null` wenn der User abbricht.
  static Future<WorkspaceInvite?> show(
    BuildContext context, {
    required String workspaceId,
    required WorkspaceService workspaceService,
  }) {
    return showModalBottomSheet<WorkspaceInvite?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => InviteMemberDialog(
        workspaceId: workspaceId,
        workspaceService: workspaceService,
      ),
    );
  }

  @override
  State<InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends State<InviteMemberDialog> {
  final _emailCtrl = TextEditingController();
  WorkspaceRole _role = WorkspaceRole.editor;
  bool _loading = false;
  String? _emailError;

  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9.!#$%&'
    r"'"
    r'+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$',
  );

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  bool _validateEmail() {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !_emailRegex.hasMatch(email)) {
      final l10n = AppLocalizations.of(context);
      setState(() => _emailError = l10n.teamInviteEmailInvalid);
      return false;
    }
    setState(() => _emailError = null);
    return true;
  }

  Future<void> _submit() async {
    if (!_validateEmail()) return;

    // Capture root Scaffold-Messenger and l10n before the async gap
    // (Dialog-Context-Pattern: the modal bottom sheet may be gone by the
    // time the await returns, so we must not call ScaffoldMessenger.of(context)
    // after any await).
    final messenger = ScaffoldMessenger.of(context);
    final rootContext = context;
    final l10n = AppLocalizations.of(context);

    setState(() => _loading = true);
    try {
      final invite = await widget.workspaceService.createInvite(
        workspaceId: widget.workspaceId,
        email: _emailCtrl.text.trim(),
        role: _role,
      );
      if (!mounted) return;
      Navigator.of(context).pop(invite);
    } catch (e) {
      if (!rootContext.mounted) return;
      AppFeedback.errorOn(
        messenger,
        l10n.teamInviteFailed(sanitizeError(e, l10n: l10n)),
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
    final adminEnabled =
        billing.currentPlan.rank >= BillingPlan.team.rank;

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
              // --- Header row ---
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.teamInviteTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.textPrimaryOf(context),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  IconButton(
                    key: const Key('invite-member-close-btn'),
                    icon: const Icon(Icons.close),
                    tooltip: l10n.commonCancel,
                    onPressed:
                        _loading ? null : () => Navigator.of(context).pop(null),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // --- Email field ---
              TextField(
                key: const Key('invite-member-email-field'),
                controller: _emailCtrl,
                autofocus: true,
                enabled: !_loading,
                keyboardType: TextInputType.emailAddress,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: l10n.teamInviteEmailLabel,
                  hintText: 'name@example.com',
                  errorText: _emailError,
                  errorStyle: TextStyle(
                    color: AppTheme.dangerTextOf(context),
                    fontSize: 12,
                  ),
                ),
                onChanged: (_) {
                  if (_emailError != null) {
                    setState(() => _emailError = null);
                  }
                },
              ),
              const SizedBox(height: 16),

              // --- Role label ---
              Text(
                l10n.teamInviteRoleLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMutedOf(context),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),

              // --- Role tiles via RadioGroup ---
              // RadioGroup is the Flutter 3.32+ recommended way to manage
              // radio selection without deprecated groupValue/onChanged.
              RadioGroup<WorkspaceRole>(
                groupValue: _role,
                onChanged: _loading
                    ? (_) {}
                    : (v) {
                        if (v != null) setState(() => _role = v);
                      },
                child: Column(
                  children: [
                    // Editor
                    RadioListTile<WorkspaceRole>(
                      key: const Key('invite-role-editor'),
                      value: WorkspaceRole.editor,
                      title: Text(
                        l10n.teamInviteRoleEditor,
                        style:
                            TextStyle(color: AppTheme.textPrimaryOf(context)),
                      ),
                      subtitle: Text(
                        l10n.teamRoleEditorHint,
                        style: TextStyle(
                          color: AppTheme.textMutedOf(context),
                          fontSize: 12,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    // Observer
                    RadioListTile<WorkspaceRole>(
                      key: const Key('invite-role-observer'),
                      value: WorkspaceRole.observer,
                      title: Text(
                        l10n.teamInviteRoleObserver,
                        style:
                            TextStyle(color: AppTheme.textPrimaryOf(context)),
                      ),
                      subtitle: Text(
                        l10n.teamRoleObserverHint,
                        style: TextStyle(
                          color: AppTheme.textMutedOf(context),
                          fontSize: 12,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    // Admin (plan-gated) — IgnorePointer + Opacity when plan too low
                    IgnorePointer(
                      ignoring: !adminEnabled,
                      child: Opacity(
                        opacity: adminEnabled ? 1.0 : 0.5,
                        child: RadioListTile<WorkspaceRole>(
                          key: const Key('invite-role-admin'),
                          value: WorkspaceRole.admin,
                          enabled: adminEnabled,
                          title: Text(
                            l10n.teamInviteRoleAdminGated,
                            style: TextStyle(
                              color: adminEnabled
                                  ? AppTheme.textPrimaryOf(context)
                                  : AppTheme.textDisabledOf(context),
                            ),
                          ),
                          subtitle: Text(
                            adminEnabled
                                ? l10n.teamRoleAdminHint
                                : l10n.teamInviteAdminLockedTooltip,
                            style: TextStyle(
                              color: AppTheme.textMutedOf(context),
                              fontSize: 12,
                            ),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // --- Submit button ---
              SizedBox(
                height: 48,
                child: FilledButton(
                  key: const Key('invite-member-submit-btn'),
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.teamInvite),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// InviteSuccessSheet — zeigt den Invite-Token nach erfolgreichem Erstellen
// ---------------------------------------------------------------------------

class InviteSuccessSheet extends StatelessWidget {
  const InviteSuccessSheet({super.key, required this.token});

  final String token;

  /// Öffnet das Success-Sheet mit dem Invite-Token.
  static Future<void> show(BuildContext context, String token) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => InviteSuccessSheet(token: token),
    );
  }

  /// Kürzt den Token auf max 20 Zeichen mit "…" in der Mitte.
  static String _truncateToken(String token) {
    if (token.length <= 20) return token;
    final half = 9;
    return '${token.substring(0, half)}…${token.substring(token.length - half)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Title ---
            Text(
              l10n.teamInviteCreatedTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimaryOf(context),
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),

            // --- Body text ---
            Text(
              l10n.teamInviteShareBody,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryOf(context),
                  ),
            ),
            const SizedBox(height: 12),

            // --- Token display ---
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.bgSubtleOf(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderOf(context)),
              ),
              child: SelectableText(
                _truncateToken(token),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  color: AppTheme.textPrimaryOf(context),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- Action buttons ---
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('invite-success-close-btn'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.commonClose),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('invite-success-copy-btn'),
                    onPressed: () async {
                      // Capture messenger + rootContext before the async gap
                      // (Dialog-Context-Pattern — bottom sheet context may be
                      // detached after Clipboard.setData returns).
                      final messenger = ScaffoldMessenger.of(context);
                      final rootContext = context;
                      try {
                        await Clipboard.setData(ClipboardData(text: token));
                        if (!rootContext.mounted) return;
                        AppFeedback.successOn(
                          messenger,
                          l10n.teamInviteCopyLinkSnack,
                          rootContext: rootContext,
                        );
                      } catch (_) {
                        if (!rootContext.mounted) return;
                        AppFeedback.errorOn(
                          messenger,
                          l10n.teamInviteCopyFailed,
                          rootContext: rootContext,
                        );
                      }
                    },
                    child: Text(l10n.teamInviteCopyLink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // --- Email hint ---
            Text(
              l10n.teamInviteShareEmailHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMutedOf(context),
                    fontStyle: FontStyle.italic,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
