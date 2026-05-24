import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/workspace.dart';
import '../providers/active_workspace_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/invites_provider.dart';
import '../utils/role_labels.dart';
import 'app_feedback.dart';

/// Glocken-Icon im App-Header. Zeigt einen roten Badge mit der Anzahl
/// offener Workspace-Einladungen für den aktuellen User. Tap öffnet einen
/// Dialog mit Beitreten/Ablehnen-Buttons.
///
/// Hinweis: Wir verwenden `showDialog` statt `PopupMenuButton`, weil ein
/// `PopupMenuItem` mit `enabled: false` und interaktiven Buttons im Inneren
/// in der Praxis zu Race-Conditions führt (Item-Tap will Menü schließen,
/// während Button-onPressed noch läuft → setState auf disposed Widget).
class InvitesBell extends StatelessWidget {
  const InvitesBell({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final invites = context.watch<InvitesProvider>();
    final count = invites.count;
    // Badge-Border verwendet bgSurfaceOf für Dark-Mode-Kompatibilität.
    final badgeBorder = AppTheme.bgSurfaceOf(context);
    return IconButton(
      tooltip: l10n.invitesBellTooltip,
      onPressed: () => _openInvitesDialog(context),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.notifications_none_rounded,
              size: 18, color: AppTheme.textMutedOf(context)),
          if (count > 0)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                padding: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: AppTheme.danger,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: badgeBorder, width: 1.5),
                ),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    // White text on danger-red badge — semantically correct,
                    // no AppTheme.onDanger token exists; matches ElevatedButton
                    // foregroundColor: Colors.white in app_theme.dart.
                    color: AppTheme.bgSurface,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openInvitesDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _InvitesDialog(),
    );
  }
}

class _InvitesDialog extends StatelessWidget {
  const _InvitesDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final invites = context.watch<InvitesProvider>();
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final dateFmt = DateFormat.yMd(localeTag);
    return Dialog(
      // bgSurfaceOf adapts to dark mode (bgSurface / bgSurfaceDark).
      backgroundColor: AppTheme.bgSurfaceOf(context),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, minWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              child: Row(
                children: [
                  Icon(Icons.notifications_active_outlined,
                      size: 18, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.invitesHeader,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimaryOf(context)),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n.actionRefresh,
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: invites.loading
                        ? null
                        : () => context.read<InvitesProvider>().refresh(),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppTheme.borderOf(context)),
            if (invites.invites.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.invitesEmpty,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: AppTheme.textMutedOf(context)),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: invites.invites.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: AppTheme.borderOf(context)),
                  itemBuilder: (_, i) =>
                      _InviteRow(invite: invites.invites[i], dateFmt: dateFmt),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InviteRow extends StatefulWidget {
  final WorkspaceInvite invite;
  final DateFormat dateFmt;
  const _InviteRow({required this.invite, required this.dateFmt});

  @override
  State<_InviteRow> createState() => _InviteRowState();
}

class _InviteRowState extends State<_InviteRow> {
  bool _busy = false;

  /// Extrahiert eine sichere, kurze Fehlermeldung aus einer Exception.
  ///
  /// Nimmt nur die erste Zeile des `toString()`-Outputs und kürzt auf
  /// maximal 120 Zeichen, damit keine Stack-Traces an den User durchsickern.
  static String _sanitizeException(Object e) {
    final raw = e.toString();
    final firstLine = raw.split('\n').first.trim();
    return firstLine.length > 120 ? '${firstLine.substring(0, 120)}…' : firstLine;
  }

  Future<void> _accept() async {
    setState(() => _busy = true);
    // Dialog-Context-Pattern: Capture messenger + l10n before async gaps so
    // that we can show feedback even after the dialog has been popped.
    final messenger = ScaffoldMessenger.of(context);
    final rootContext = context;
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final invites = context.read<InvitesProvider>();
    final activeWs = context.read<ActiveWorkspaceProvider>();
    final auth = context.read<AuthProvider>();
    try {
      final wsId = await invites.accept(widget.invite.id);
      if (wsId != null && wsId.isNotEmpty && wsId != 'null') {
        await activeWs.presetActiveId(wsId);
        final uid = auth.currentUser?.id;
        if (uid != null) await activeWs.loadForCurrentUser(uid);
      }
      // Show snack before pop so rootContext is still valid for theme lookup.
      if (!rootContext.mounted) return;
      AppFeedback.successOn(
        messenger,
        l10n.invitesAcceptedSnack,
        rootContext: rootContext,
      );
      navigator.maybePop();
    } catch (e) {
      if (!rootContext.mounted) return;
      AppFeedback.errorOn(
        messenger,
        l10n.invitesAcceptFailed(_sanitizeException(e)),
        rootContext: rootContext,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    setState(() => _busy = true);
    // Dialog-Context-Pattern: capture before async gap.
    final messenger = ScaffoldMessenger.of(context);
    final rootContext = context;
    final l10n = AppLocalizations.of(context);
    final invites = context.read<InvitesProvider>();
    try {
      await invites.decline(widget.invite.id);
      if (!rootContext.mounted) return;
      AppFeedback.successOn(
        messenger,
        l10n.invitesDeclinedSnack,
        rootContext: rootContext,
      );
    } catch (e) {
      if (!rootContext.mounted) return;
      AppFeedback.errorOn(
        messenger,
        l10n.invitesDeclineFailed(_sanitizeException(e)),
        rootContext: rootContext,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final inv = widget.invite;
    final wsIdShort = inv.workspaceId.length >= 8
        ? inv.workspaceId.substring(0, 8)
        : inv.workspaceId;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.accentLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.workspaces_outlined,
                    size: 16, color: AppTheme.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.invitesFrom,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryOf(context)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      wsIdShort,
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMutedOf(context),
                          fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.invitesRoleLabel(roleLabel(context, inv.role)),
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textMutedOf(context)),
                    ),
                    Text(
                      l10n.invitesExpiresOn(
                          widget.dateFmt.format(inv.expiresAt.toLocal())),
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textMutedOf(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _busy ? null : _decline,
                style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textMutedOf(context),
                    visualDensity: VisualDensity.compact),
                child: Text(l10n.invitesDecline),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                onPressed: _busy ? null : _accept,
                icon: _busy
                    ? SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          // onPrimary adapts to theme (white in light mode,
                          // theme foreground in dark mode).
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.login, size: 14),
                label: Text(l10n.invitesAccept),
                style: ElevatedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
