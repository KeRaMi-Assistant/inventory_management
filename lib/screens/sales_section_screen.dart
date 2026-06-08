import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import 'deals_screen.dart';
import 'inbox_screen.dart';
import 'main_tab.dart';
import 'tickets_screen.dart';

/// Verkauf-Sektion (Tier-2b, T2.3).
///
/// Bündelt die drei Sub-Bereiche [MainTab.deals], [MainTab.tickets] und
/// [MainTab.inbox] unter einem `SegmentedButton`. Der Inbox-Sub-Tab ist
/// plan-gated ([inboxEnabled]) — bei Free-Plan verschwindet nur das
/// Segment, die übergeordnete Bottom-Nav-/Rail-Slot-Struktur bleibt
/// stabil (kein Index-Shift-Bug, Plan §1).
///
/// Das Widget ist „dumm": aller State (welcher Sub-Tab aktiv ist, welcher
/// Ticket geöffnet werden soll) lebt im Owner (`main_screen.dart`).
class SalesSectionScreen extends StatelessWidget {
  /// Aktiver Sub-Tab — einer von deals/tickets/inbox.
  final MainTab activeTab;

  /// Ob der Inbox-Sub-Tab freigeschaltet ist (Plan ≥ Starter).
  final bool inboxEnabled;

  /// Aggregierter Tracking-Needs-Review-Count für den Inbox-Badge.
  final int badgeCount;

  /// Callback bei Sub-Tab-Wechsel (liefert deals/tickets/inbox).
  final ValueChanged<MainTab> onSelectSubTab;

  /// Reicht den Ticket-Open-Flow aus Deals/Inbox an den Owner durch.
  final ValueChanged<String> onOpenTicket;

  /// Vom Owner gehaltenes, zuletzt geöffnetes Ticket (für TicketsScreen).
  final String? selectedTicket;

  /// Inbox-Aktion „zu den Deals-Reviews springen".
  final VoidCallback onGoToDealsReview;

  const SalesSectionScreen({
    super.key,
    required this.activeTab,
    required this.inboxEnabled,
    required this.badgeCount,
    required this.onSelectSubTab,
    required this.onOpenTicket,
    required this.selectedTicket,
    required this.onGoToDealsReview,
  });

  /// Defensiver Clamp: ist Inbox aktiv aber nicht freigeschaltet, behandeln
  /// wir die Sektion als deals (z.B. nach einem Plan-Downgrade).
  MainTab get _effectiveTab =>
      (activeTab == MainTab.inbox && !inboxEnabled) ? MainTab.deals : activeTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final effective = _effectiveTab;

    final body = switch (effective) {
      MainTab.tickets => TicketsScreen(initialTicket: selectedTicket),
      MainTab.inbox => InboxScreen(
          onOpenTicket: onOpenTicket,
          onGoToDealsReview: onGoToDealsReview,
        ),
      // deals + jeder defensive Fallback.
      _ => DealsScreen(onOpenTicket: onOpenTicket),
    };

    return Column(
      key: const Key('salesSection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Mobile-First: 3 Label+Icon-Segmente überlaufen auf 360px.
              // Unter ~430px Container-Breite → Icon-only-Segmente mit
              // Tooltip (Label), damit nichts horizontal scrollt.
              final iconOnly = constraints.maxWidth < 430;
              return _SalesSegmentedBar(
                activeTab: effective,
                inboxEnabled: inboxEnabled,
                badgeCount: badgeCount,
                iconOnly: iconOnly,
                onSelectSubTab: onSelectSubTab,
                expand: constraints.maxWidth < 600,
                l10n: l10n,
              );
            },
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}

/// Der eigentliche `SegmentedButton<MainTab>` für die Verkauf-Sub-Tabs.
class _SalesSegmentedBar extends StatelessWidget {
  final MainTab activeTab;
  final bool inboxEnabled;
  final int badgeCount;
  final bool iconOnly;
  final bool expand;
  final ValueChanged<MainTab> onSelectSubTab;
  final AppLocalizations l10n;

  const _SalesSegmentedBar({
    required this.activeTab,
    required this.inboxEnabled,
    required this.badgeCount,
    required this.iconOnly,
    required this.expand,
    required this.onSelectSubTab,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final segments = <ButtonSegment<MainTab>>[
      _segment(
        tab: MainTab.deals,
        keyName: 'salesSeg-deals',
        label: l10n.navDeals,
        icon: Icons.list_alt_outlined,
      ),
      _segment(
        tab: MainTab.tickets,
        keyName: 'salesSeg-tickets',
        label: l10n.navTickets,
        icon: Icons.confirmation_number_outlined,
      ),
      if (inboxEnabled)
        _segment(
          tab: MainTab.inbox,
          keyName: 'salesSeg-inbox',
          label: l10n.navInbox,
          icon: Icons.mail_outlined,
          badgeCount: badgeCount,
        ),
    ];

    return SegmentedButton<MainTab>(
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      expandedInsets: expand ? EdgeInsets.zero : null,
      showSelectedIcon: false,
      segments: segments,
      selected: {activeTab},
      onSelectionChanged: (selection) {
        if (selection.isNotEmpty) onSelectSubTab(selection.first);
      },
    );
  }

  ButtonSegment<MainTab> _segment({
    required MainTab tab,
    required String keyName,
    required String label,
    required IconData icon,
    int badgeCount = 0,
  }) {
    // ButtonSegment nimmt keinen `key` → Anker landet auf dem Icon-Subtree.
    Widget iconWidget = KeyedSubtree(
      key: Key(keyName),
      child: Icon(icon, size: 16),
    );
    if (badgeCount > 0) {
      iconWidget = Badge(
        label: Text(
          '$badgeCount',
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.warning,
        child: iconWidget,
      );
    }
    if (iconOnly) {
      // Nur Icon — Tooltip trägt das Label (Touch-Target ≥48dp via
      // SegmentedButton-VisualDensity + Mindesthöhe der Segmente).
      return ButtonSegment<MainTab>(
        value: tab,
        tooltip: label,
        icon: Tooltip(message: label, child: iconWidget),
      );
    }
    return ButtonSegment<MainTab>(
      value: tab,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
