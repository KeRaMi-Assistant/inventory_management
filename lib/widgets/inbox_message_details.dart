import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/inbox_message.dart';
import '../models/live_tracking_status.dart';
import '../models/tracking_confidence.dart';
import '../providers/inbox_provider.dart';
import 'tracking_status_block.dart';

/// Vollbild-fähiges Bottom-Sheet, das Header + extrahierte Felder einer
/// geparsten Mail anzeigt. Zeigt KEINE Rohinhalte (die werden ohnehin nach
/// Parse aus der DB entfernt). Aktionen (Verwerfen, Tracking, Deal anlegen)
/// werden über die Buttons unten ausgelöst.
///
/// Wenn [suggestion] übergeben wird, rendert das Versand-Section einen
/// vollwertigen [TrackingStatusBlock] mit allen Confidence-Aktionen.
class InboxMessageDetails extends StatelessWidget {
  final ParsedMessage message;

  /// Optionaler zugehöriger Suggestion-Eintrag für den TrackingStatusBlock.
  /// Wenn null, wird das Tracking aus `parsedPayload` als plain text gezeigt.
  final PendingDealSuggestion? suggestion;

  /// Optionaler Live-Status aus dem verknüpften Deal (A1/A2-Feature).
  final LiveTrackingStatus? dealLiveStatus;
  final String? dealLiveStatusLastEvent;
  final DateTime? dealLiveStatusUpdatedAt;

  final List<Widget> actions;

  const InboxMessageDetails({
    super.key,
    required this.message,
    this.suggestion,
    this.dealLiveStatus,
    this.dealLiveStatusLastEvent,
    this.dealLiveStatusUpdatedAt,
    this.actions = const [],
  });

  static Future<void> show(
    BuildContext context, {
    required ParsedMessage message,
    PendingDealSuggestion? suggestion,
    LiveTrackingStatus? dealLiveStatus,
    String? dealLiveStatusLastEvent,
    DateTime? dealLiveStatusUpdatedAt,
    List<Widget> actions = const [],
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => InboxMessageDetails(
        message: message,
        suggestion: suggestion,
        dealLiveStatus: dealLiveStatus,
        dealLiveStatusLastEvent: dealLiveStatusLastEvent,
        dealLiveStatusUpdatedAt: dealLiveStatusUpdatedAt,
        actions: actions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = message.parsedPayload ?? const {};
    final orderId = p['order_id'] as String?;
    final shopLabel = p['shop_label'] as String? ?? message.shopKey;
    final product = p['product'] as String?;
    final total = (p['total'] as num?)?.toDouble();
    final currency = p['currency'] as String? ?? 'EUR';
    final df = DateFormat.yMMMd('de_DE').add_Hm();

    // Tracking-Felder: bevorzuge Suggestion, fallback auf parsedPayload.
    final sug = suggestion;
    final String? tracking =
        sug?.tracking ?? p['tracking'] as String?;
    final String? carrier =
        sug?.carrier ?? p['carrier'] as String?;
    final String? etaStr = p['eta'] as String?;
    final TrackingConfidence? confidence = sug?.trackingConfidence ??
        TrackingConfidence.fromString(p['tracking_confidence'] as String?);
    final bool needsReview = sug?.trackingNeedsReview ??
        (p['tracking_needs_review'] as bool? ?? false);

    // Amazon-Shipment-ID-Hint: tracking_candidates enthält eine
    // amazon-shipment-id-Quelle UND primary tracking ist null/leer.
    final bool amazonShipmentIdHint = _detectAmazonShipmentIdOnly(p, tracking);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: AppTheme.bgSurfaceOf(ctx),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: ListView(
          controller: scrollCtrl,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderOf(ctx),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatusBadge(status: message.status),
                if (shopLabel != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accentLightOf(ctx),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      shopLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentTextOf(ctx),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message.subject ?? '— ohne Betreff —',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppTheme.textPrimaryOf(ctx),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Von: ${message.fromAddress ?? "—"}',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.textSecondaryOf(ctx)),
            ),
            Text(
              'Empfangen: ${df.format(message.receivedAt.toLocal())}',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.textSecondaryOf(ctx)),
            ),
            if (message.processedAt != null)
              Text(
                'Verarbeitet: ${df.format(message.processedAt!.toLocal())}',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textSecondaryOf(ctx)),
              ),
            const SizedBox(height: 20),
            if (orderId != null || product != null || total != null) ...[
              _SectionTitle(AppLocalizations.of(ctx).inboxSectionOrder),
              if (orderId != null)
                _DetailRow(
                  label: AppLocalizations.of(ctx).inboxFieldOrderId,
                  value: orderId,
                  copyable: true,
                ),
              if (product != null)
                _DetailRow(
                    label: AppLocalizations.of(ctx).inboxFieldProduct,
                    value: product),
              if (total != null)
                _DetailRow(
                  label: AppLocalizations.of(ctx).inboxFieldAmount,
                  value:
                      '${total.toStringAsFixed(2).replaceAll(".", ",")} '
                      '${_currencySymbol(currency)}',
                ),
              const SizedBox(height: 16),
            ],
            // ── Versand + TrackingStatusBlock ──────────────────────────
            _SectionTitle(AppLocalizations.of(ctx).inboxSectionShipping),
            const SizedBox(height: 6),
            TrackingStatusBlock(
              key: const Key('inbox-detail-tracking-status-block'),
              trackingNumber: tracking,
              confidence: confidence,
              carrier: carrier,
              needsReview: needsReview,
              amazonShipmentIdHint: amazonShipmentIdHint,
              onManualInput: sug != null
                  ? () => _openManualInputDialog(ctx, sug)
                  : null,
              onAcceptAsCorrect: (sug != null && needsReview)
                  ? () => _acceptTrackingAsCorrect(ctx, sug)
                  : null,
              onDiscard: (sug != null && (tracking != null || needsReview))
                  ? () => _discardTracking(ctx, sug)
                  : null,
              liveStatus: dealLiveStatus,
              liveStatusLastEvent: dealLiveStatusLastEvent,
              liveStatusUpdatedAt: dealLiveStatusUpdatedAt,
            ),
            if (etaStr != null) ...[
              const SizedBox(height: 6),
              _DetailRow(
                  label: AppLocalizations.of(ctx).inboxFieldEta,
                  value: etaStr),
            ],
            const SizedBox(height: 16),
            if (message.matchDealId != null) ...[
              _SectionTitle(AppLocalizations.of(ctx).inboxSectionLinkedTo),
              _DetailRow(
                label: AppLocalizations.of(ctx).inboxFieldDeal,
                value: '#${message.matchDealId}',
              ),
              const SizedBox(height: 16),
            ],
            if (actions.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ],
        ),
      ),
    );
  }

  /// Prüft ob tracking_candidates eine amazon-shipment-id-Quelle enthält
  /// UND das primäre Tracking null/leer ist.
  static bool _detectAmazonShipmentIdOnly(
    Map<String, dynamic> payload,
    String? tracking,
  ) {
    if (tracking != null && tracking.isNotEmpty) return false;
    final candidates = payload['tracking_candidates'];
    if (candidates is! List) return false;
    return candidates.any((c) {
      if (c is! Map) return false;
      return c['source'] == 'amazon-shipment-id';
    });
  }

  Future<void> _openManualInputDialog(
    BuildContext context,
    PendingDealSuggestion sug,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: sug.tracking ?? '');
    final newValue = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.trackingEnterManuallyCta),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.trackingEnterManuallyCta,
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.actionCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(l10n.actionOk),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (newValue == null || newValue.isEmpty) return;
    if (!context.mounted) return;
    try {
      await context
          .read<InboxProvider>()
          .updateSuggestionTrackingManually(sug.id, newValue);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).trackingUpdateError(e.toString())),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _acceptTrackingAsCorrect(
    BuildContext context,
    PendingDealSuggestion sug,
  ) async {
    try {
      await context
          .read<InboxProvider>()
          .acceptSuggestionTrackingAsManual(sug.id);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).trackingAcceptError(e.toString())),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _discardTracking(
    BuildContext context,
    PendingDealSuggestion sug,
  ) async {
    try {
      await context
          .read<InboxProvider>()
          .discardSuggestionTracking(sug.id);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).trackingDiscardError(e.toString())),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  static String _currencySymbol(String c) {
    switch (c) {
      case 'EUR':
        return '€';
      case 'USD':
        return '\$';
      case 'GBP':
        return '£';
      case 'PLN':
        return 'zł';
      default:
        return c;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final ParsedMessageStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ParsedMessageStatus.matched =>
        ('Aktualisiert', AppTheme.successTextOf(context)),
      ParsedMessageStatus.suggested =>
        ('Vorschlag', AppTheme.accentTextOf(context)),
      ParsedMessageStatus.unclassified =>
        ('Unklassifiziert', AppTheme.warningTextOf(context)),
      ParsedMessageStatus.failed =>
        ('Fehler', AppTheme.dangerTextOf(context)),
      ParsedMessageStatus.dismissed =>
        ('Verworfen', AppTheme.textMutedOf(context)),
      ParsedMessageStatus.pending =>
        ('In Arbeit', AppTheme.textSecondaryOf(context)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
          color: AppTheme.textMutedOf(context),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool copyable;
  const _DetailRow({
    required this.label,
    required this.value,
    this.copyable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
          ),
          if (copyable)
            IconButton(
              icon: const Icon(Icons.copy_outlined, size: 14),
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints.tightFor(width: 28, height: 28),
              tooltip: 'Kopieren',
              onPressed: () => Clipboard.setData(ClipboardData(text: value)),
            ),
        ],
      ),
    );
  }
}
