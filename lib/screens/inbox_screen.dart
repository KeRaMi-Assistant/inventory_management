import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/deal.dart';
import '../models/inbox_message.dart';
import '../models/mailbox_account.dart';
import '../providers/inbox_provider.dart';
import '../providers/deals_provider.dart';
import '../utils/mail_link.dart';
import '../utils/responsive.dart';
import '../utils/url_helper.dart';
import '../widgets/add_edit_deal_dialog.dart';
import '../widgets/app_feedback.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/deal_picker_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/inbox_message_details.dart';
import '../widgets/skeletons/list_skeleton.dart';
import '../widgets/tracking_banner_improved_detection.dart';

/// Postfach-Inbox: Vorschläge → vorausgefüllter Edit-Dialog beim Annehmen,
/// Aktualisiert → Quick-View inkl. Mail-Link, Unklassifiziert → manueller
/// Workflow. Alle Listen unterstützen Verwerfen, Tracking-Übernahme,
/// Zu-Deal-zuweisen und das Öffnen der Original-Mail im Web-Mailer.
class InboxScreen extends StatefulWidget {
  final void Function(String ticket)? onOpenTicket;
  /// Optional callback when user taps the tracking-review banner.
  /// Typically navigates to the Deals tab with the needs-review filter active.
  final VoidCallback? onGoToDealsReview;
  const InboxScreen({
    super.key,
    this.onOpenTicket,
    this.onGoToDealsReview,
  });

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<InboxProvider>().refresh();
      });
    }
  }

  Future<void> _refresh() => context.read<InboxProvider>().refresh();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Consumer<InboxProvider>(
        builder: (context, provider, _) {
          final needsReviewCount =
              context.watch<DealsProvider>().trackingNeedsReviewCount;
          return Scaffold(
            backgroundColor: AppTheme.bgAppOf(context),
            body: Column(
              children: [
                _InboxHeader(provider: provider, onRefresh: _refresh),
                TrackingBannerController(
                  needsReviewCount: needsReviewCount,
                  onTap: widget.onGoToDealsReview ?? () {},
                ),
                _InboxFilterBar(provider: provider),
                Material(
                  color: AppTheme.bgSurfaceOf(context),
                  child: TabBar(
                    indicatorColor: AppTheme.accentTextOf(context),
                    labelColor: AppTheme.accentTextOf(context),
                    unselectedLabelColor: AppTheme.textMutedOf(context),
                    dividerColor: AppTheme.borderOf(context),
                    tabs: [
                      Tab(
                        icon: Badge.count(
                          count: provider.unreadSuggestionsCount,
                          isLabelVisible:
                              provider.unreadSuggestionsCount > 0,
                          child: const Icon(
                              Icons.add_box_outlined,
                              size: 18),
                        ),
                        text: AppLocalizations.of(context)
                            .inboxTabSuggestions(provider.pendingSuggestions.length),
                      ),
                      Tab(
                        icon: Badge.count(
                          count: provider.unreadMatchedCount,
                          isLabelVisible:
                              provider.unreadMatchedCount > 0,
                          child: const Icon(Icons.sync, size: 18),
                        ),
                        text: AppLocalizations.of(context)
                            .inboxTabUpdated(provider.matchedRecently.length),
                      ),
                      Tab(
                        icon: Badge.count(
                          count: provider.unreadUnclassifiedCount,
                          isLabelVisible:
                              provider.unreadUnclassifiedCount > 0,
                          child: const Icon(
                              Icons.help_outlined,
                              size: 18),
                        ),
                        text: AppLocalizations.of(context)
                            .inboxTabUnclassified(provider.unclassified.length),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _SuggestionsTab(
                        suggestions: provider.pendingSuggestions,
                        accounts: provider.accounts,
                        onRefresh: _refresh,
                        onGoToDeals: widget.onGoToDealsReview,
                        isLoading: provider.isLoading,
                        initialLoadAttempted: provider.initialLoadAttempted,
                      ),
                      _MatchedTab(
                        messages: provider.matchedRecently,
                        accounts: provider.accounts,
                        onRefresh: _refresh,
                        onOpenTicket: widget.onOpenTicket,
                        isLoading: provider.isLoading,
                        initialLoadAttempted: provider.initialLoadAttempted,
                      ),
                      _UnclassifiedTab(
                        messages: provider.unclassified,
                        accounts: provider.accounts,
                        onRefresh: _refresh,
                        isLoading: provider.isLoading,
                        initialLoadAttempted: provider.initialLoadAttempted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InboxHeader extends StatelessWidget {
  final InboxProvider provider;
  final Future<void> Function() onRefresh;
  const _InboxHeader({required this.provider, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final hasAccount = provider.accounts.isNotEmpty;
    return Container(
      color: AppTheme.bgSurfaceOf(context),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Icon(
            hasAccount ? Icons.mail_outline : Icons.warning_amber_outlined,
            color: hasAccount
                ? AppTheme.accentTextOf(context)
                : AppTheme.warningTextOf(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasAccount
                      ? AppLocalizations.of(context)
                          .inboxMailboxConnectedCount(provider.accounts.length)
                      : AppLocalizations.of(context).inboxMailboxNone,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasAccount
                      ? AppLocalizations.of(context).inboxPollingHint
                      : AppLocalizations.of(context).inboxMailboxNoneHint,
                  style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondaryOf(context)),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: provider.dismissalCount == 0
                ? AppLocalizations.of(context).inboxDismissalFilterTooltipEmpty
                : AppLocalizations.of(context)
                    .inboxDismissalFilterTooltipCount(provider.dismissalCount),
            icon: Icon(
              provider.dismissalCount == 0
                  ? Icons.filter_alt_outlined
                  : Icons.filter_alt_off_outlined,
              color: provider.dismissalCount == 0
                  ? AppTheme.textMutedOf(context)
                  : null,
            ),
            onPressed: provider.dismissalCount == 0 || provider.isLoading
                ? null
                : () => _confirmClearDismissals(context, provider),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context)
                .inboxMarkAllReadTooltip(provider.unreadCount),
            icon: const Icon(Icons.mark_email_read_outlined),
            color: provider.unreadCount == 0
                ? AppTheme.textMutedOf(context)
                : null,
            onPressed: provider.unreadCount == 0 || provider.isLoading
                ? null
                : () => _confirmMarkAllRead(context, provider),
          ),
          IconButton(
            tooltip: provider.isPumping
                ? AppLocalizations.of(context)
                    .inboxImportingTooltip(provider.pumpStored)
                : hasAccount
                    ? AppLocalizations.of(context).inboxPollNowTooltip
                    : AppLocalizations.of(context).inboxConnectFirstTooltip,
            icon: provider.isPumping
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_download_outlined),
            color: hasAccount && !provider.isLoading && !provider.isPumping
                ? null
                : AppTheme.textMutedOf(context),
            onPressed:
                !hasAccount || provider.isLoading || provider.isPumping
                    ? null
                    : () => _triggerPoll(context, provider),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context).actionRefresh,
            icon: provider.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: provider.isLoading ? null : onRefresh,
          ),
          PopupMenuButton<String>(
            tooltip: AppLocalizations.of(context).navMore,
            icon: const Icon(Icons.more_vert),
            enabled: !provider.isLoading && !provider.isPumping,
            onSelected: (value) {
              if (value == 'reparse-tracking') {
                _triggerReparseTracking(context, provider);
              }
            },
            itemBuilder: (ctx) {
              final l10n = AppLocalizations.of(ctx);
              return [
                PopupMenuItem<String>(
                  value: 'reparse-tracking',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.refresh_outlined),
                    title: Text(l10n.inboxReparseTrackingTitle),
                    subtitle: Text(l10n.inboxReparseTrackingSubtitle),
                  ),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }
}

/// Filter-Leiste über den Tabs. Zwei Pill-Dropdowns: Shop und Status.
/// Versteckt sich, wenn weder Shops bekannt noch Suggestions vorhanden
/// sind (z.B. Free-Plan, leere Inbox) — in dem Fall hat der User nichts
/// zu filtern und die Pills wären nur Lärm.
class _InboxFilterBar extends StatelessWidget {
  final InboxProvider provider;
  const _InboxFilterBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    final shopKeys = provider.availableShopKeys;
    if (shopKeys.isEmpty && !provider.hasActiveFilter) {
      return const SizedBox.shrink();
    }
    return Container(
      color: AppTheme.bgSurfaceOf(context),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          _FilterPill(
            icon: Icons.store_outlined,
            label: provider.shopFilter == null
                ? AppLocalizations.of(context).inboxFilterAllShops
                : provider.shopLabelFor(provider.shopFilter!),
            active: provider.shopFilter != null,
            onTap: () => _pickShop(context, provider, shopKeys),
            onClear: provider.shopFilter == null
                ? null
                : () => provider.setShopFilter(null),
          ),
          const SizedBox(width: 8),
          _FilterPill(
            icon: Icons.local_shipping_outlined,
            label: provider.statusFilter == null
                ? AppLocalizations.of(context).inboxFilterAllStatus
                : provider.statusFilter!.label(),
            active: provider.statusFilter != null,
            onTap: () => _pickStatus(context, provider),
            onClear: provider.statusFilter == null
                ? null
                : () => provider.setStatusFilter(null),
          ),
          if (provider.hasActiveFilter) ...[
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.clear_all, size: 16),
              label: Text(AppLocalizations.of(context).inboxFilterResetLabel),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.accentTextOf(context),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: provider.clearFilters,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickShop(
    BuildContext context,
    InboxProvider provider,
    List<String> shopKeys,
  ) async {
    final picked = await showModalBottomSheet<String?>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.all_inbox),
              title: Text(AppLocalizations.of(sheetCtx).inboxFilterAllShops),
              trailing: provider.shopFilter == null
                  ? const Icon(Icons.check, color: Color(0xFF2563EB))
                  : null,
              onTap: () => Navigator.pop(context, _kAllShops),
            ),
            const Divider(height: 1),
            for (final key in shopKeys)
              ListTile(
                leading: const Icon(Icons.store_outlined),
                title: Text(provider.shopLabelFor(key)),
                trailing: provider.shopFilter == key
                    ? const Icon(Icons.check, color: Color(0xFF2563EB))
                    : null,
                onTap: () => Navigator.pop(context, key),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    provider.setShopFilter(picked == _kAllShops ? null : picked);
  }

  Future<void> _pickStatus(
    BuildContext context,
    InboxProvider provider,
  ) async {
    // Wrapper, damit wir "Alle Status" vom echten "Bestellt"-Pick und vom
    // Cancel (null) sauber unterscheiden können.
    final picked = await showModalBottomSheet<Object?>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.all_inbox),
              title: Text(AppLocalizations.of(sheetCtx).inboxFilterAllStatus),
              trailing: provider.statusFilter == null
                  ? const Icon(Icons.check, color: Color(0xFF2563EB))
                  : null,
              onTap: () => Navigator.pop(context, _kAllStatusesSentinel),
            ),
            const Divider(height: 1),
            for (final s in SuggestionShipStatus.values)
              ListTile(
                leading: Icon(_statusIcon(s)),
                title: Text(s.label()),
                trailing: provider.statusFilter == s
                    ? const Icon(Icons.check, color: Color(0xFF2563EB))
                    : null,
                onTap: () => Navigator.pop(context, s),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    if (picked is SuggestionShipStatus) {
      provider.setStatusFilter(picked);
    } else {
      provider.setStatusFilter(null);
    }
  }

  // Sentinel-Wert für die Shop-Sheet ("Alle Shops"). String reicht, weil
  // echte Shop-Keys nie diesen Wert haben.
  static const String _kAllShops = '__all__';
  // Eigene Sentinel-Instanz für die Status-Sheet — type-distinct von
  // SuggestionShipStatus, damit `is SuggestionShipStatus` zuverlässig
  // greift.
  static const Object _kAllStatusesSentinel = Object();

  static IconData _statusIcon(SuggestionShipStatus s) {
    switch (s) {
      case SuggestionShipStatus.ordered:
        return Icons.shopping_cart_outlined;
      case SuggestionShipStatus.shipped:
        return Icons.local_shipping_outlined;
      case SuggestionShipStatus.delivered:
        return Icons.check_circle_outlined;
      case SuggestionShipStatus.cancelled:
        return Icons.cancel_outlined;
      case SuggestionShipStatus.refunded:
        return Icons.undo_outlined;
    }
  }
}

class _FilterPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const _FilterPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active
        ? AppTheme.accentLightOf(context)
        : AppTheme.bgSubtleOf(context);
    final fg = active
        ? AppTheme.accentTextOf(context)
        : AppTheme.textSecondaryOf(context);
    final border = active
        ? AppTheme.accentBorderOf(context)
        : AppTheme.borderOf(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              onClear == null ? Icons.expand_more : Icons.close,
              size: 14,
              color: fg,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _confirmClearDismissals(
  BuildContext context,
  InboxProvider provider,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final confirmed = await showConfirmDialog(
    context: context,
    title: l10n.inboxFilterResetTitle,
    message: l10n.inboxFilterResetBodyCount(provider.dismissalCount),
    confirmLabel: l10n.actionReset,
  );
  if (!confirmed) return;

  // Snapshot vor dem optimistischen Clear für Undo.
  if (!context.mounted) return;
  final snapshot = provider.clearDismissalsOptimistic();
  bool undone = false;

  AppFeedback.successOn(
    messenger,
    l10n.inboxDiscardFilterClearedFeedback,
    rootContext: context,
    onUndo: () {
      undone = true;
      provider.restoreDismissals(snapshot.keys, snapshot.count);
    },
  );

  // DB-DELETE nach SnackBar-Timeout: 4,5 Sek. damit der Undo-Callback
  // garantiert zuerst läuft, falls der User ihn drückt.
  Future.delayed(const Duration(milliseconds: 4500), () async {
    if (undone) return; // Undo wurde gedrückt — kein DB-DELETE.
    try {
      await provider.clearDismissals();
    } catch (e) {
      if (kDebugMode) debugPrint('clearDismissals delayed commit failed: $e');
    }
  });
}

Future<void> _confirmMarkAllRead(
  BuildContext context,
  InboxProvider provider,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final unreadCount = provider.unreadCount;

  final confirmed = await showConfirmDialog(
    context: context,
    title: l10n.inboxMarkAllReadConfirmTitle,
    message: l10n.inboxMarkAllReadConfirmBody(unreadCount),
    confirmLabel: l10n.inboxMarkAllRead,
  );
  if (!confirmed) return;

  try {
    await provider.markAllRead();
    if (!context.mounted) return;
    final markedCount = unreadCount - provider.unreadCount;
    AppFeedback.successOn(
      messenger,
      l10n.inboxMarkAllReadSuccess(markedCount > 0 ? markedCount : unreadCount),
      rootContext: context,
    );
  } catch (_) {
    if (!context.mounted) return;
    AppFeedback.errorOn(
      messenger,
      l10n.appFeedbackErrorDefault,
      rootContext: context,
    );
  }
}

Future<void> _triggerPoll(BuildContext context, InboxProvider provider) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  // Info-SnackBar vor dem async Poll (kein mounted-Problem).
  AppFeedback.infoOn(messenger, l10n.inboxPolling, rootContext: context);
  final result = await provider.pollNow();
  if (!context.mounted) return;
  // Ab hier: context.mounted garantiert — direkte AppFeedback-Variante nutzen.
  if (result != null) {
    final parts = <String>[];
    if (result.fetched > 0) {
      parts.add(l10n.inboxPollFetched(result.fetched));
    }
    if (result.stored > 0) {
      parts.add(l10n.inboxPollStored(result.stored));
    }
    final s = result.suggested ?? 0;
    final m = result.matched ?? 0;
    if (s > 0 || m > 0) {
      parts.add(l10n.inboxPollSuggestedMerged(s, m));
    }
    final msg = parts.isEmpty
        ? l10n.inboxPollUpToDate
        : '${parts.join(', ')}.';
    AppFeedback.success(context, msg); // ignore: use_build_context_synchronously
  } else if (provider.lastError != null) {
    AppFeedback.error(context, l10n.appFeedbackErrorDefault); // ignore: use_build_context_synchronously
  }
}

Future<void> _triggerReparseTracking(
  BuildContext context,
  InboxProvider provider,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  AppFeedback.infoOn(messenger, l10n.inboxRetracking, rootContext: context);
  final result = await provider.reparseTracking();
  if (!context.mounted) return;
  if (result != null) {
    final msg = result.rescued > 0
        ? l10n.inboxReparseRescued(result.rescued, result.scanned)
        : l10n.inboxReparseNoCorrections(result.scanned);
    AppFeedback.successOn(messenger, msg, rootContext: context);
  } else if (provider.lastError != null) {
    AppFeedback.errorOn(
      messenger,
      l10n.appFeedbackErrorDefault,
      rootContext: context,
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────

String? _imapHostFor(List<MailboxAccount> accounts, {String? accountId}) {
  if (accounts.isEmpty) return null;
  if (accountId != null) {
    final match =
        accounts.where((a) => a.id == accountId).firstOrNull;
    if (match != null) return match.imapHost;
  }
  return accounts.first.imapHost;
}

Future<void> _openMail(
  BuildContext context, {
  required String? messageId,
  required String? imapHost,
}) async {
  final url = buildMailDeepLink(messageId: messageId, imapHost: imapHost);
  if (url == null) {
    if (messageId != null && messageId.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: messageId));
      if (context.mounted) {
        AppFeedback.info(
          context,
          AppLocalizations.of(context).inboxCopyMessageIdSnackbar,
        );
      }
    } else {
      if (context.mounted) {
        AppFeedback.info(
          context,
          AppLocalizations.of(context).inboxNoMailLinkSnackbar,
        );
      }
    }
    return;
  }
  if (!context.mounted) return;
  await openUrlWithFallback(context, url);
}

/// Verwirft eine ParsedMessage nach Bestätigung durch einen Confirm-Dialog.
///
/// **Kein Undo** — per A7-Audit-Verdict ist `parsed_messages` nicht
/// über den User-Client UPDATE-bar (keine `FOR UPDATE`-RLS-Policy).
/// Nur Confirm-Dialog + Standard-SnackBar.
Future<void> _confirmDismissMessage(
  BuildContext context,
  ParsedMessage message,
) async {
  final inbox = context.read<InboxProvider>();
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);

  // Messenger vor showConfirmDialog sichern (Dialog-Context-Pattern).
  final confirmed = await showConfirmDialog(
    context: context,
    title: l10n.inboxDiscardMailTitle,
    message: l10n.inboxDiscardMailBody(message.subject ?? ''),
    confirmLabel: l10n.inboxSuggestionDismiss,
    isDestructive: true,
  );
  if (!confirmed) return;

  try {
    await inbox.dismissParsedMessage(message.id);
    // ignore: use_build_context_synchronously
    AppFeedback.successOn(messenger, l10n.inboxMailDiscarded, rootContext: context);
  } catch (_) {
    // ignore: use_build_context_synchronously
    AppFeedback.errorOn(messenger, l10n.appFeedbackErrorDefault, rootContext: context);
  }
}

String _moneyFmt(double v, String currency) {
  final symbol = switch (currency) {
    'EUR' => '€',
    'USD' => '\$',
    'GBP' => '£',
    'PLN' => 'zł',
    _ => currency,
  };
  return '${v.toStringAsFixed(2).replaceAll('.', ',')} $symbol';
}

// ── Suggestions Tab ────────────────────────────────────────────────────

class _SuggestionsTab extends StatelessWidget {
  final List<PendingDealSuggestion> suggestions;
  final List<MailboxAccount> accounts;
  final Future<void> Function() onRefresh;
  final VoidCallback? onGoToDeals;
  final bool isLoading;
  final bool initialLoadAttempted;
  const _SuggestionsTab({
    required this.suggestions,
    required this.accounts,
    required this.onRefresh,
    required this.isLoading,
    required this.initialLoadAttempted,
    this.onGoToDeals,
  });

  @override
  Widget build(BuildContext context) {
    final showSkeleton = shouldShowSkeleton(
      isLoading: isLoading,
      hasData: suggestions.isNotEmpty,
      initialLoadAttempted: initialLoadAttempted,
    );
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: showSkeleton
            ? const ListSkeleton(key: ValueKey('skeleton'), itemCount: 6)
            : suggestions.isEmpty
                ? CustomScrollView(
                    key: const ValueKey('content'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverFillRemaining(
                        child: EmptyState(
                          icon: Icons.check_circle_outlined,
                          title:
                              AppLocalizations.of(context).inboxSuggestionsEmpty,
                          subtitle: AppLocalizations.of(context)
                              .inboxSuggestionsEmptyHint,
                          keySlug: 'inboxSuggestionsEmpty',
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    key: const ValueKey('content'),
                    padding: const EdgeInsets.all(16),
                    itemCount: suggestions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _SuggestionCard(
                      suggestion: suggestions[i],
                      imapHost: _imapHostFor(accounts),
                      onGoToDeals: onGoToDeals,
                    ),
                  ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final PendingDealSuggestion suggestion;
  final String? imapHost;
  final VoidCallback? onGoToDeals;
  const _SuggestionCard({
    required this.suggestion,
    this.imapHost,
    this.onGoToDeals,
  });

  Deal _toDraftDeal() {
    final shopName = suggestion.shopLabel ?? suggestion.shopKey;
    final orderId = suggestion.orderId;
    final dealStatus = suggestion.status?.toDealStatus() ??
        (suggestion.tracking != null ? 'Unterwegs' : 'Bestellt');
    return Deal(
      id: Deal.unsavedId,
      product: (suggestion.product ?? '').trim().isEmpty
          ? (orderId != null
              ? 'Bestellung $orderId'
              : 'Erkannter Auftrag ($shopName)')
          : suggestion.product!.trim(),
      quantity: suggestion.quantity,
      isDropship: false,
      shop: shopName,
      orderDate: suggestion.createdAt,
      ekBrutto: suggestion.total,
      ticketNumber: orderId,
      tracking: suggestion.tracking,
      // Multi-Parcel: alle Nummern der Suggestion in den Draft übernehmen —
      // bisher ging bei Split-Shipments alles außer der ersten verloren.
      trackings: suggestion.trackings.isNotEmpty
          ? suggestion.trackings
          : [if (suggestion.tracking != null) suggestion.tracking!],
      arrivalDate: suggestion.eta,
      status: dealStatus,
      currency: suggestion.currency,
    );
  }

  Future<void> _accept(BuildContext context) async {
    final inbox = context.read<InboxProvider>();
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final goToDeals = onGoToDeals;
    final saved = await showDialog<Deal>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditDealDialog(prefill: _toDraftDeal()),
    );
    // saved.id == unsavedId → User hat den Dialog ohne Speichern verlassen.
    if (saved == null || saved.id == Deal.unsavedId) return;
    // Messenger und l10n wurden vor den async-Gaps gesichert (Dialog-Context-Pattern).
    // rootContext nach dem Dialog-Close noch valide (StatelessWidget, kein mounted).
    try {
      await inbox.markSuggestionAccepted(suggestion.id, createdDealId: saved.id);
      final tracking = suggestion.tracking;
      final snackContent = (tracking != null && tracking.isNotEmpty)
          ? l10n.inboxAcceptedSnack(tracking, saved.id)
          : l10n.inboxAcceptedSnackNoTracking(saved.id);
      AppFeedback.successOn( // ignore: use_build_context_synchronously
        messenger, snackContent,
        rootContext: context, // ignore: use_build_context_synchronously
        onUndo: goToDeals,
        undoLabel: goToDeals != null ? l10n.inboxAcceptedShowDeal : null,
      );
    } catch (_) {
      AppFeedback.errorOn( // ignore: use_build_context_synchronously
        messenger, l10n.appFeedbackErrorDefault,
        rootContext: context, // ignore: use_build_context_synchronously
      );
    }
  }

  void _reject(BuildContext context) {
    final inbox = context.read<InboxProvider>();
    final l10n = AppLocalizations.of(context);
    final id = suggestion.id;

    // Optimistic-Local-Restore: sofort aus UI entfernen, DB-Commit nach 4 Sek.
    inbox.rejectSuggestionWithUndo(id);

    AppFeedback.success(
      context,
      l10n.inboxSuggestionRejectedFeedback,
      onUndo: () => inbox.cancelPendingReject(id),
    );
  }

  /// Opens AddEditDealDialog prefilled with suggestion data.
  /// On Save: marks suggestion accepted. On Cancel: no-op.
  Future<void> _editBeforeAccept(BuildContext context) async {
    final inbox = context.read<InboxProvider>();
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final goToDeals = onGoToDeals;
    final saved = await showDialog<Deal>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditDealDialog(prefill: _toDraftDeal()),
    );
    if (saved == null || saved.id == Deal.unsavedId) return;
    try {
      await inbox.markSuggestionAccepted(suggestion.id, createdDealId: saved.id);
      final tracking = suggestion.tracking;
      final snackContent = (tracking != null && tracking.isNotEmpty)
          ? l10n.inboxAcceptedSnack(tracking, saved.id)
          : l10n.inboxAcceptedSnackNoTracking(saved.id);
      AppFeedback.successOn(
        messenger,
        snackContent,
        rootContext: context, // ignore: use_build_context_synchronously
        onUndo: goToDeals,
        undoLabel: goToDeals != null ? l10n.inboxAcceptedShowDeal : null,
      );
    } catch (_) {
      AppFeedback.errorOn(
        messenger,
        l10n.appFeedbackErrorDefault,
        rootContext: context, // ignore: use_build_context_synchronously
      );
    }
  }

  Future<void> _showSuggestionSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.bgSurfaceOf(context),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          key: const Key('inboxSuggestionSheet'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.bgSubtleOf(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              key: Key('inboxSuggestion-dismiss-${suggestion.id}'),
              leading: Icon(Icons.close, color: AppTheme.dangerTextOf(context)),
              title: Text(l10n.inboxSuggestionDismiss),
              onTap: () {
                Navigator.pop(sheetCtx);
                _reject(context);
              },
            ),
            ListTile(
              key: Key('inboxSuggestion-edit-${suggestion.id}'),
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.inboxSuggestionEdit),
              onTap: () {
                Navigator.pop(sheetCtx);
                _editBeforeAccept(context);
              },
            ),
            ListTile(
              key: Key('inboxSuggestion-accept-${suggestion.id}'),
              leading: Icon(Icons.check, color: AppTheme.accentTextOf(context)),
              title: Text(l10n.inboxSuggestionAccept),
              onTap: () {
                Navigator.pop(sheetCtx);
                _accept(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyTracking(BuildContext context) async {
    final inbox = context.read<InboxProvider>();
    final l10n = AppLocalizations.of(context);
    if (suggestion.tracking == null || suggestion.tracking!.isEmpty) {
      AppFeedback.info(context, l10n.inboxNoTrackingSnackbar);
      return;
    }
    final deal = await DealPickerDialog.show(
      context,
      title: l10n.inboxApplyTrackingToDeal,
      hint: l10n.inboxApplyTrackingHint(suggestion.tracking!),
    );
    if (deal == null) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await inbox.applyTrackingFromSuggestion(
          suggestion: suggestion, dealId: deal.id);
      AppFeedback.successOn(
        messenger,
        l10n.inboxTrackingAdopted(deal.id),
        rootContext: context, // ignore: use_build_context_synchronously
      );
    } catch (_) {
      AppFeedback.errorOn(
        messenger,
        l10n.appFeedbackErrorDefault,
        rootContext: context, // ignore: use_build_context_synchronously
      );
    }
  }

  void _showDetails(BuildContext context) {
    final parsedMessage = ParsedMessage(
      id: suggestion.parsedMessageId,
      workspaceId: suggestion.workspaceId,
      accountId: '',
      receivedAt: suggestion.receivedAt,
      status: ParsedMessageStatus.suggested,
      fromAddress: null,
      subject: suggestion.product,
      shopKey: suggestion.shopKey,
      parsedPayload: {
        'order_id': suggestion.orderId,
        'shop_label': suggestion.shopLabel,
        'product': suggestion.product,
        'total': suggestion.total,
        'currency': suggestion.currency,
        'tracking': suggestion.tracking,
        'carrier': suggestion.carrier,
        'eta': suggestion.eta?.toIso8601String(),
        'tracking_confidence': suggestion.trackingConfidence?.toJson(),
        'tracking_needs_review': suggestion.trackingNeedsReview,
      },
    );
    InboxMessageDetails.show(
      context,
      message: parsedMessage,
      suggestion: suggestion,
    );
  }

  Future<void> _linkToDeal(BuildContext context) async {
    final inbox = context.read<InboxProvider>();
    final l10n = AppLocalizations.of(context);
    final deal = await DealPickerDialog.show(
      context,
      title: l10n.inboxLinkToDealTitle,
      hint: l10n.inboxLinkToDealHint,
    );
    if (deal == null) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await inbox.linkSuggestionToDeal(suggestion: suggestion, dealId: deal.id);
      AppFeedback.successOn(
        messenger,
        l10n.inboxSuggestionLinked(deal.id),
        rootContext: context, // ignore: use_build_context_synchronously
      );
    } catch (_) {
      AppFeedback.errorOn(
        messenger,
        l10n.appFeedbackErrorDefault,
        rootContext: context, // ignore: use_build_context_synchronously
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dfDate = DateFormat('dd.MM.yyyy', 'de_DE');
    final dfDateTime = DateFormat('dd.MM.yyyy · HH:mm', 'de_DE');
    final hasMailLink = buildMailDeepLink(
          messageId: suggestion.messageId,
          imapHost: imapHost,
        ) !=
        null;
    final shopName = suggestion.shopLabel ?? suggestion.shopKey;
    final productTitle =
        (suggestion.product ?? '').trim().isEmpty ? null : suggestion.product;
    final inbox = context.watch<InboxProvider>();
    final referenceNow = inbox.lastRefreshedAt;
    final visDays = inbox.visibilityDays;
    final daysLeft =
        visDays - referenceNow.difference(suggestion.receivedAt).inDays;
    final unread = inbox.isUnread(suggestion.parsedMessageId);

    return GestureDetector(
      onLongPress: () => _showSuggestionSheet(context),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppTheme.borderOf(context)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                _ShopBadge(label: shopName),
                const SizedBox(width: 8),
                if (suggestion.status != null)
                  _ShipStatusBadge(status: suggestion.status!),
                const SizedBox(width: 6),
                _CountdownPill(daysLeft: daysLeft, totalDays: visDays),
                const Spacer(),
                Text(
                  dfDateTime.format(suggestion.receivedAt.toLocal()),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMutedOf(context),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  tooltip: 'Aktionen',
                  itemBuilder: (ctx) {
                    final l10n = AppLocalizations.of(ctx);
                    return [
                    PopupMenuItem(
                      value: 'details',
                      child: ListTile(
                        leading: const Icon(Icons.info_outlined),
                        title: Text(l10n.inboxDetailsAndTracking),
                        dense: true,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'tracking',
                      child: ListTile(
                        leading: const Icon(Icons.local_shipping_outlined),
                        title: Text(l10n.inboxApplyTrackingToDeal),
                        dense: true,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'link',
                      child: ListTile(
                        leading: const Icon(Icons.link),
                        title: Text(l10n.inboxLinkToExistingDeal),
                        dense: true,
                      ),
                    ),
                    if (hasMailLink || suggestion.messageId != null)
                      PopupMenuItem(
                        value: 'mail',
                        child: ListTile(
                          leading: const Icon(Icons.open_in_new),
                          title: Text(l10n.inboxOpenMailInBrowserMenuItem),
                          dense: true,
                        ),
                      ),
                    PopupMenuItem(
                      value: 'reject',
                      child: ListTile(
                        leading: const Icon(Icons.delete_outlined,
                            color: Color(0xFFB91C1C)),
                        title: Text(l10n.inboxSuggestionDismiss),
                        dense: true,
                      ),
                    ),
                  ];
                  },
                  onSelected: (v) {
                    switch (v) {
                      case 'details':
                        _showDetails(context);
                        break;
                      case 'tracking':
                        _applyTracking(context);
                        break;
                      case 'link':
                        _linkToDeal(context);
                        break;
                      case 'mail':
                        _openMail(
                          context,
                          messageId: suggestion.messageId,
                          imapHost: imapHost,
                        );
                        break;
                      case 'reject':
                        _reject(context);
                        break;
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              productTitle ?? '— ohne Produktnamen —',
              style: TextStyle(
                fontSize: 14,
                fontWeight: unread ? FontWeight.w800 : FontWeight.w700,
                color: productTitle != null
                    ? AppTheme.textPrimaryOf(context)
                    : AppTheme.textMutedOf(context),
                fontStyle: productTitle == null ? FontStyle.italic : null,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                if (suggestion.orderId != null)
                  _MetaItem(
                    icon: Icons.tag,
                    label: suggestion.orderId!,
                    monospace: true,
                  ),
                _MetaItem(
                  icon: Icons.inventory_2_outlined,
                  label: '${suggestion.quantity} Stk.',
                ),
                if (suggestion.total != null)
                  _MetaItem(
                    icon: Icons.euro_outlined,
                    label: _moneyFmt(suggestion.total!, suggestion.currency),
                  ),
                if (suggestion.eta != null)
                  _MetaItem(
                    icon: Icons.event_outlined,
                    label: 'ETA ${dfDate.format(suggestion.eta!)}',
                  ),
              ],
            ),
            if (suggestion.trackings.isNotEmpty ||
                suggestion.trackingNeedsReview) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tn in suggestion.trackings)
                    _TrackingPill(tracking: tn, carrier: suggestion.carrier),
                  if (suggestion.trackingNeedsReview)
                    _TrackingNeedsReviewBadge(key: const Key('inbox-suggestion-card-needs-review-badge')),
                ],
              ),
            ],
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < Breakpoints.legacyInboxNarrow;
                final l10n = AppLocalizations.of(context);
                return Row(
                  children: [
                    Tooltip(
                      message: l10n.inboxSuggestionDismiss,
                      child: narrow
                          ? IconButton(
                              key: Key('inboxSuggestion-dismiss-${suggestion.id}'),
                              icon: const Icon(Icons.close, size: 20),
                              color: AppTheme.dangerTextOf(context),
                              onPressed: () => _reject(context),
                            )
                          : TextButton.icon(
                              key: Key('inboxSuggestion-dismiss-${suggestion.id}'),
                              icon: const Icon(Icons.close, size: 16),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.dangerTextOf(context),
                              ),
                              onPressed: () => _reject(context),
                              label: Text(l10n.inboxSuggestionDismiss),
                            ),
                    ),
                    const Spacer(),
                    if (hasMailLink)
                      IconButton(
                        icon: const Icon(Icons.open_in_new, size: 18),
                        tooltip: AppLocalizations.of(context).inboxOpenMailLabel,
                        onPressed: () => _openMail(
                          context,
                          messageId: suggestion.messageId,
                          imapHost: imapHost,
                        ),
                      ),
                    Tooltip(
                      message: l10n.inboxSuggestionEdit,
                      child: narrow
                          ? IconButton(
                              key: Key('inboxSuggestion-edit-${suggestion.id}'),
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _editBeforeAccept(context),
                            )
                          : TextButton.icon(
                              key: Key('inboxSuggestion-edit-${suggestion.id}'),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              onPressed: () => _editBeforeAccept(context),
                              label: Text(l10n.inboxSuggestionEdit),
                            ),
                    ),
                    const SizedBox(width: 4),
                    Tooltip(
                      message: l10n.inboxSuggestionAccept,
                      child: narrow
                          ? IconButton(
                              key: Key('inboxSuggestion-accept-${suggestion.id}'),
                              icon: const Icon(Icons.check, size: 20),
                              color: AppTheme.accentTextOf(context),
                              onPressed: () => _accept(context),
                            )
                          : ElevatedButton.icon(
                              key: Key('inboxSuggestion-accept-${suggestion.id}'),
                              icon: const Icon(Icons.check, size: 16),
                              onPressed: () => _accept(context),
                              label: Text(l10n.inboxSuggestionAccept),
                            ),
                    ),
                  ],
                );
              },
            ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Matched Tab ────────────────────────────────────────────────────────

class _MatchedTab extends StatelessWidget {
  final List<ParsedMessage> messages;
  final List<MailboxAccount> accounts;
  final Future<void> Function() onRefresh;
  final void Function(String ticket)? onOpenTicket;
  final bool isLoading;
  final bool initialLoadAttempted;
  const _MatchedTab({
    required this.messages,
    required this.accounts,
    required this.onRefresh,
    required this.isLoading,
    required this.initialLoadAttempted,
    this.onOpenTicket,
  });

  @override
  Widget build(BuildContext context) {
    final showSkeleton = shouldShowSkeleton(
      isLoading: isLoading,
      hasData: messages.isNotEmpty,
      initialLoadAttempted: initialLoadAttempted,
    );
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: showSkeleton
            ? const ListSkeleton(key: ValueKey('skeleton'), itemCount: 6)
            : messages.isEmpty
                ? CustomScrollView(
                    key: const ValueKey('content'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverFillRemaining(
                        child: EmptyState(
                          icon: Icons.inbox_outlined,
                          title: AppLocalizations.of(context).inboxUpdatedEmpty,
                          subtitle: AppLocalizations.of(context)
                              .inboxUpdatedEmptyHint,
                          keySlug: 'inboxUpdatedEmpty',
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    key: const ValueKey('content'),
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                final msg = messages[i];
                final payload = msg.parsedPayload ?? const {};
                final orderId = payload['order_id'] as String?;
                final product = payload['product'] as String?;
                final tracking = payload['tracking'] as String?;
                final shopLabel =
                    payload['shop_label'] as String? ?? msg.shopKey ?? '—';
                final unread = context
                    .watch<InboxProvider>()
                    .isUnread(msg.id);
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppTheme.borderOf(context)),
                  ),
                  child: ListTile(
                    onTap: () => InboxMessageDetails.show(
                      context,
                      message: msg,
                      actions: _detailActionsFor(context, msg, orderId),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.successBgOf(context),
                      child: Icon(Icons.sync,
                          color: AppTheme.successTextOf(context), size: 20),
                    ),
                    title: Text(
                      product ?? msg.subject ?? 'Aktualisierter Deal',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight:
                            unread ? FontWeight.w800 : FontWeight.w600,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(
                          '$shopLabel${orderId != null ? " · #$orderId" : ""}'
                          '${msg.matchDealId != null ? " → Deal #${msg.matchDealId}" : ""}',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryOf(context)),
                        ),
                        if (tracking != null)
                          Text(
                            'Tracking: $tracking',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondaryOf(context)),
                          ),
                      ],
                    ),
                    trailing: Text(
                      DateFormat.MMMd('de_DE').add_Hm().format(
                            (msg.processedAt ?? msg.receivedAt).toLocal(),
                          ),
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textMutedOf(context)),
                    ),
                  ),
                );
              },
                  ),
      ),
    );
  }

  List<Widget> _detailActionsFor(
    BuildContext context,
    ParsedMessage msg,
    String? orderId,
  ) {
    final imapHost = _imapHostFor(accounts, accountId: msg.accountId);
    final canOpenMail = buildMailDeepLink(
          messageId: msg.messageId,
          imapHost: imapHost,
        ) !=
        null;
    return [
      if (orderId != null && onOpenTicket != null)
        ElevatedButton.icon(
          icon: const Icon(Icons.open_in_new, size: 16),
          label: Text(AppLocalizations.of(context).inboxOpenTicketLabel),
          onPressed: () {
            Navigator.pop(context);
            onOpenTicket!(orderId);
          },
        ),
      if (canOpenMail)
        OutlinedButton.icon(
          icon: const Icon(Icons.mail_outline, size: 16),
          label: Text(AppLocalizations.of(context).inboxOpenMailLabel),
          onPressed: () {
            Navigator.pop(context);
            _openMail(context, messageId: msg.messageId, imapHost: imapHost);
          },
        ),
      OutlinedButton.icon(
        icon: const Icon(Icons.delete_outlined, size: 16),
        label: Text(AppLocalizations.of(context).inboxSuggestionDismiss),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.dangerTextOf(context),
        ),
        onPressed: () {
          Navigator.pop(context);
          _confirmDismissMessage(context, msg);
        },
      ),
    ];
  }
}

// ── Unclassified Tab ───────────────────────────────────────────────────

class _UnclassifiedTab extends StatelessWidget {
  final List<ParsedMessage> messages;
  final List<MailboxAccount> accounts;
  final Future<void> Function() onRefresh;
  final bool isLoading;
  final bool initialLoadAttempted;
  const _UnclassifiedTab({
    required this.messages,
    required this.accounts,
    required this.onRefresh,
    required this.isLoading,
    required this.initialLoadAttempted,
  });

  @override
  Widget build(BuildContext context) {
    final showSkeleton = shouldShowSkeleton(
      isLoading: isLoading,
      hasData: messages.isNotEmpty,
      initialLoadAttempted: initialLoadAttempted,
    );
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: showSkeleton
            ? const ListSkeleton(key: ValueKey('skeleton'), itemCount: 6)
            : messages.isEmpty
                ? CustomScrollView(
                    key: const ValueKey('content'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverFillRemaining(
                        child: EmptyState(
                          icon: Icons.help_outlined,
                          title: AppLocalizations.of(context)
                              .inboxUnclassifiedEmpty,
                          subtitle: AppLocalizations.of(context)
                              .inboxUnclassifiedEmptyHint,
                          keySlug: 'inboxUnclassifiedEmpty',
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    key: const ValueKey('content'),
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _UnclassifiedRow(
                      message: messages[i],
                      imapHost: _imapHostFor(
                          accounts, accountId: messages[i].accountId),
                    ),
                  ),
      ),
    );
  }
}

class _UnclassifiedRow extends StatelessWidget {
  final ParsedMessage message;
  final String? imapHost;
  const _UnclassifiedRow({required this.message, this.imapHost});

  String? _trackingFromMessage() =>
      message.parsedPayload?['tracking'] as String?;
  String? _carrierFromMessage() =>
      message.parsedPayload?['carrier'] as String?;
  DateTime? _etaFromMessage() {
    final raw = message.parsedPayload?['eta'] as String?;
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> _createDeal(BuildContext context) async {
    final p = message.parsedPayload ?? const {};
    final shopLabel =
        (p['shop_label'] as String?) ?? (message.shopKey ?? 'Sonstige');
    final tracking = _trackingFromMessage();
    final draft = Deal(
      id: Deal.unsavedId,
      product: message.subject ?? 'Manueller Eintrag aus Mail',
      quantity: 1,
      isDropship: false,
      shop: shopLabel,
      orderDate: message.receivedAt,
      tracking: tracking,
      status: tracking != null ? 'Unterwegs' : 'Bestellt',
    );
    final saved = await showDialog<Deal>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditDealDialog(prefill: draft),
    );
    if (saved == null || saved.id == Deal.unsavedId) return;
    if (context.mounted) {
      AppFeedback.success(
        context,
        AppLocalizations.of(context).inboxDealCreatedFromMail(saved.id),
      );
    }
  }

  Future<void> _applyTracking(BuildContext context) async {
    final inbox = context.read<InboxProvider>();
    final l10n = AppLocalizations.of(context);
    final tn = _trackingFromMessage();
    if (tn == null || tn.isEmpty) {
      AppFeedback.info(context, l10n.inboxNoTrackingSnackbar);
      return;
    }
    final deal = await DealPickerDialog.show(
      context,
      title: l10n.inboxApplyTrackingToDeal,
      hint: l10n.inboxApplyTrackingHintShort(tn),
    );
    if (deal == null) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await inbox.applyTrackingFromMessage(
        message: message,
        dealId: deal.id,
        tracking: tn,
        carrier: _carrierFromMessage(),
        eta: _etaFromMessage(),
      );
      AppFeedback.successOn(
        messenger,
        l10n.inboxTrackingAdopted(deal.id),
        rootContext: context, // ignore: use_build_context_synchronously
      );
    } catch (_) {
      AppFeedback.errorOn(
        messenger,
        l10n.appFeedbackErrorDefault,
        rootContext: context, // ignore: use_build_context_synchronously
      );
    }
  }

  void _showDetails(BuildContext context) {
    final hasMailLink = buildMailDeepLink(
          messageId: message.messageId,
          imapHost: imapHost,
        ) !=
        null;
    InboxMessageDetails.show(
      context,
      message: message,
      actions: [
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: Text(AppLocalizations.of(context).inboxCreateDeal),
          onPressed: () {
            Navigator.pop(context);
            _createDeal(context);
          },
        ),
        if (_trackingFromMessage() != null)
          OutlinedButton.icon(
            icon: const Icon(Icons.local_shipping_outlined, size: 16),
            label: Text(AppLocalizations.of(context).inboxApplyTrackingToDealShort),
            onPressed: () {
              Navigator.pop(context);
              _applyTracking(context);
            },
          ),
        if (hasMailLink)
          OutlinedButton.icon(
            icon: const Icon(Icons.mail_outline, size: 16),
            label: Text(AppLocalizations.of(context).inboxOpenMailLabel),
            onPressed: () {
              Navigator.pop(context);
              _openMail(
                context,
                messageId: message.messageId,
                imapHost: imapHost,
              );
            },
          ),
        OutlinedButton.icon(
          icon: const Icon(Icons.delete_outlined, size: 16),
          label: Text(AppLocalizations.of(context).inboxSuggestionDismiss),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.dangerTextOf(context),
          ),
          onPressed: () {
            Navigator.pop(context);
            _confirmDismissMessage(context, message);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final shopLabel = (message.parsedPayload?['shop_label'] as String?) ??
        message.shopKey;
    final hasMailLink = buildMailDeepLink(
          messageId: message.messageId,
          imapHost: imapHost,
        ) !=
        null;
    final unread =
        context.watch<InboxProvider>().isUnread(message.id);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.borderOf(context)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        onTap: () => _showDetails(context),
        leading: CircleAvatar(
          backgroundColor: AppTheme.warningBgOf(context),
          child: Icon(Icons.help_outlined,
              color: AppTheme.warningTextOf(context), size: 20),
        ),
        title: Text(
          message.subject ?? '— ohne Betreff —',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
            color: AppTheme.textPrimaryOf(context),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '${shopLabel ?? "Unbekannt"} · ${message.fromAddress ?? "—"}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, color: AppTheme.textSecondaryOf(context)),
            ),
            Text(
              DateFormat.yMMMd('de_DE')
                  .add_Hm()
                  .format(message.receivedAt.toLocal()),
              style: TextStyle(
                  fontSize: 11, color: AppTheme.textMutedOf(context)),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20),
          tooltip: 'Aktionen',
          itemBuilder: (ctx) {
            final l10n = AppLocalizations.of(ctx);
            return [
            PopupMenuItem(
              value: 'create',
              child: ListTile(
                leading: const Icon(Icons.add),
                title: Text(l10n.inboxCreateDeal),
                dense: true,
              ),
            ),
            if (_trackingFromMessage() != null)
              PopupMenuItem(
                value: 'tracking',
                child: ListTile(
                  leading: const Icon(Icons.local_shipping_outlined),
                  title: Text(l10n.inboxApplyTrackingToDeal),
                  dense: true,
                ),
              ),
            PopupMenuItem(
              value: 'details',
              child: ListTile(
                leading: const Icon(Icons.info_outlined),
                title: Text(l10n.inboxShowDetails),
                dense: true,
              ),
            ),
            if (hasMailLink)
              PopupMenuItem(
                value: 'mail',
                child: ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: Text(l10n.inboxOpenMailLabel),
                  dense: true,
                ),
              ),
            PopupMenuItem(
              value: 'dismiss',
              child: ListTile(
                leading: const Icon(
                    Icons.delete_outlined, color: Color(0xFFB91C1C)),
                title: Text(l10n.inboxSuggestionDismiss),
                dense: true,
              ),
            ),
          ];
          },
          onSelected: (v) {
            switch (v) {
              case 'create':
                _createDeal(context);
                break;
              case 'tracking':
                _applyTracking(context);
                break;
              case 'details':
                _showDetails(context);
                break;
              case 'mail':
                _openMail(
                  context,
                  messageId: message.messageId,
                  imapHost: imapHost,
                );
                break;
              case 'dismiss':
                _confirmDismissMessage(context, message);
                break;
            }
          },
        ),
      ),
    );
  }
}

// ── Building blocks ────────────────────────────────────────────────────

class _CountdownPill extends StatelessWidget {
  /// Anzahl Tage, die diese Suggestion noch in der Inbox sichtbar bleibt.
  /// Referenz ist [InboxProvider.lastRefreshedAt], damit der Countdown
  /// bis zum nächsten Pull stabil bleibt — nicht jede Sekunde tickt.
  final int daysLeft;

  /// Volles Sichtbarkeitsfenster nach aktuellem Plan (Free=0, Starter=7,
  /// Pro=30, Business=90, Ultimate=365). Wird für Clamping + Tooltip
  /// genutzt, damit die Pill nicht oberhalb des Plan-Maximums anzeigt.
  final int totalDays;
  const _CountdownPill({required this.daysLeft, required this.totalDays});

  @override
  Widget build(BuildContext context) {
    final clamped = daysLeft.clamp(0, totalDays);
    final (bg, fg) = clamped <= 3
        ? (AppTheme.dangerBgOf(context), AppTheme.dangerTextOf(context))
        : clamped <= 7
            ? (AppTheme.warningBgOf(context), AppTheme.warningTextOf(context))
            : (AppTheme.infoBgOf(context), AppTheme.infoTextOf(context));
    final l10n = AppLocalizations.of(context);
    final label = clamped == 0
        ? l10n.inboxCountdownToday
        : clamped == 1
            ? l10n.inboxCountdownOneDay
            : l10n.inboxCountdownDays(clamped);
    return Tooltip(
      message: l10n.inboxCountdownTooltip(totalDays),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, size: 11, color: fg),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopBadge extends StatelessWidget {
  final String label;
  const _ShopBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.accentLightOf(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.accentTextOf(context),
        ),
      ),
    );
  }
}

class _ShipStatusBadge extends StatelessWidget {
  final SuggestionShipStatus status;
  const _ShipStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (bg, fg) = switch (status) {
      SuggestionShipStatus.ordered => (
          AppTheme.infoBgOf(context),
          AppTheme.infoTextOf(context)
        ),
      SuggestionShipStatus.shipped => (
          AppTheme.warningBgOf(context),
          AppTheme.warningTextOf(context)
        ),
      SuggestionShipStatus.delivered => (
          AppTheme.successBgOf(context),
          AppTheme.successTextOf(context)
        ),
      SuggestionShipStatus.cancelled => (
          AppTheme.dangerBgOf(context),
          AppTheme.dangerTextOf(context)
        ),
      SuggestionShipStatus.refunded => dark
          ? (const Color(0xFF2E1065), const Color(0xFFC4B5FD))
          : (const Color(0xFFEDE9FE), const Color(0xFF6D28D9)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool monospace;
  const _MetaItem({
    required this.icon,
    required this.label,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.textMutedOf(context)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondaryOf(context),
            fontFamily: monospace ? 'monospace' : null,
          ),
        ),
      ],
    );
  }
}

class _TrackingPill extends StatelessWidget {
  final String tracking;
  final String? carrier;
  const _TrackingPill({required this.tracking, this.carrier});

  @override
  Widget build(BuildContext context) {
    final semanticsLabel = carrier != null ? '$carrier $tracking' : tracking;
    return Semantics(
      label: semanticsLabel,
      button: true,
      container: true,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('tracking-pill-$tracking'),
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: tracking));
          if (context.mounted) {
            AppFeedback.info(
              context,
              AppLocalizations.of(context).inboxTrackingCopied,
            );
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.bgSubtleOf(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_shipping_outlined,
                  size: 14, color: AppTheme.textSecondaryOf(context)),
              const SizedBox(width: 6),
              Text(
                tracking,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryOf(context),
                ),
              ),
              if (carrier != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurfaceOf(context),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: AppTheme.borderStrongOf(context)),
                  ),
                  child: Text(
                    carrier!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondaryOf(context),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Icon(Icons.copy_outlined,
                  size: 12, color: AppTheme.textMutedOf(context)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kompakter gelber Badge in der Suggestion-Card-Tracking-Zeile.
/// Signalisiert, dass die Tracking-Nummer auf Prüfung wartet.
class _TrackingNeedsReviewBadge extends StatelessWidget {
  const _TrackingNeedsReviewBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.warningBgOf(context),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.warningBorderOf(context)),
      ),
      child: Text(
        l10n.trackingReviewNeededBadge,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.warningTextOf(context),
        ),
      ),
    );
  }
}

