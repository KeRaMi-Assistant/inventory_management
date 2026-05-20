import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../models/billing_profile.dart';
import '../models/workspace.dart';
import '../providers/active_workspace_provider.dart';
import '../providers/billing_provider.dart';
import '../utils/role_labels.dart';
import 'create_workspace_dialog.dart';
import 'limit_reached_dialog.dart';

/// Workspace-Switcher-Widget für den Settings-Screen → Team-Tab.
///
/// Zeigt alle Workspaces des Users, markiert den aktiven mit einem Chip
/// und erlaubt das Wechseln per Tap bzw. TextButton. Unten eine Card
/// zum Anlegen eines neuen Workspace (inkl. Plan-Limit-Prüfung).
class WorkspaceSwitcher extends StatelessWidget {
  const WorkspaceSwitcher({super.key, this.onSwitch});

  final void Function(Workspace)? onSwitch;

  Future<void> _switch(BuildContext context, Workspace ws) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final provider = context.read<ActiveWorkspaceProvider>();
    await provider.setActive(ws, uid);
    if (context.mounted) {
      onSwitch?.call(ws);
    }
  }

  Future<void> _create(
    BuildContext context,
    BillingPlan plan,
    int limit, {
    required int count,
  }) async {
    if (limit != -1 && count >= limit) {
      await LimitReachedDialog.show(context);
      return;
    }
    final created = await CreateWorkspaceDialog.show(context);
    if (created != null && context.mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.teamWorkspacesCreateSuccess(created.name)),
          duration: const Duration(seconds: 3),
        ),
      );
      onSwitch?.call(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeProvider = context.watch<ActiveWorkspaceProvider>();
    final billing = context.watch<BillingProvider>();
    final plan = billing.currentPlan;
    final limit = plan.workspaceLimit;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final workspaces = activeProvider.workspaces;
    final activeWs = activeProvider.active;
    final myUid = Supabase.instance.client.auth.currentUser?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header row ──────────────────────────────────────────────────
        Row(
          children: [
            Text(
              l10n.teamWorkspacesTitle,
              style: theme.textTheme.titleMedium,
            ),
            const Spacer(),
            _UsagePill(plan: plan, limit: limit, count: workspaces.length),
          ],
        ),
        const SizedBox(height: 8),

        // ── Workspace-Liste / Empty-State ────────────────────────────────
        if (workspaces.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.teamWorkspacesEmpty,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          )
        else
          ...workspaces.map(
            (ws) => _WorkspaceCard(
              key: ValueKey(ws.id),
              ws: ws,
              isActive: ws.id == activeWs?.id,
              roleLabel: ws.id == activeWs?.id && activeProvider.role != null
                  ? roleLabel(context, activeProvider.role!)
                  : null,
              onSwitch: () => _switch(context, ws),
              myUid: myUid,
            ),
          ),

        // ── „Neuer Workspace"-Card ───────────────────────────────────────
        Card(
          key: const Key('workspace-switcher-create-card'),
          margin: const EdgeInsets.symmetric(vertical: 4),
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          child: ListTile(
            minVerticalPadding: 12,
            leading: Icon(
              Icons.add_circle_outline,
              color: theme.colorScheme.primary,
            ),
            title: Text(
              l10n.teamWorkspacesCreate,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () => _create(
              context,
              plan,
              limit,
              count: workspaces.length,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Private helper widgets ─────────────────────────────────────────────────

class _UsagePill extends StatelessWidget {
  const _UsagePill({
    required this.plan,
    required this.limit,
    required this.count,
  });

  final BillingPlan plan;
  final int limit;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final text = limit == -1
        ? l10n.teamWorkspacesPlanUsageUnlimited(plan.label, count)
        : l10n.teamWorkspacesPlanUsage(plan.label, count, limit);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({
    super.key,
    required this.ws,
    required this.isActive,
    required this.roleLabel,
    required this.onSwitch,
    required this.myUid,
  });

  final Workspace ws;
  final bool isActive;
  final String? roleLabel;
  final VoidCallback onSwitch;
  final String? myUid;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        minVerticalPadding: 12,
        title: Text(ws.displayLabel(myUid)),
        subtitle: roleLabel != null
            ? Text(
                roleLabel!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        trailing: isActive
            ? Tooltip(
                message: l10n.teamWorkspacesActiveBadgeTooltip,
                child: Chip(
                  label: Text(l10n.teamWorkspacesActiveLabel),
                ),
              )
            : TextButton(
                onPressed: onSwitch,
                child: Text(l10n.teamWorkspacesSwitchTo),
              ),
        onTap: isActive ? null : onSwitch,
      ),
    );
  }
}
