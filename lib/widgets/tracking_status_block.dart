import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

import '../app_theme.dart';
import '../models/live_tracking_status.dart';
import '../models/tracking_confidence.dart';
import '../utils/relative_time.dart';
import '../utils/responsive.dart';

/// Interne Enum für die 5 Display-States des Widgets.
enum TrackingDisplayState {
  /// Strukturell verifizierte Tracking-Nummer (confidence=strong).
  strong,

  /// Manuell eingegebene Tracking-Nummer (confidence=manual).
  manual,

  /// Kein Tracking erkannt (tracking=null, needs_review=false).
  empty,

  /// Tracking vorhanden, aber als unsicher markiert (needs_review=true).
  needsReview,

  /// Amazon-Logistics-Shipment-ID ohne vollwertige externe Sendungsnummer.
  amazonShipmentIdOnly,
}

/// Zeigt den Tracking-Status eines Deals in 5 verschiedenen States.
///
/// Das Widget ist "dumb" — kein State, keine Provider. Der Caller liefert
/// alle Daten. Wird in Inbox-Detail und Deal-Detail in eine Card eingebettet.
///
/// Touch-Targets: alle Buttons ≥ 48×48 dp.
/// Layout: vertikaler Stack — auch auf 360px-Phone ohne horizontalen Scroll.
/// Keys gesetzt für Browser-Tester (T15).
class TrackingStatusBlock extends StatelessWidget {
  /// Aktuelles Tracking (oder null wenn leer).
  final String? trackingNumber;
  final TrackingConfidence? confidence;
  final String? carrier;

  /// True, wenn ein unsicherer Wert auf Bestätigung wartet.
  final bool needsReview;

  /// True, wenn tracking_candidates eine Amazon-Shipment-ID enthält
  /// (kein vollwertiges Carrier-Tracking). Nur relevant wenn
  /// [trackingNumber] null oder leer ist.
  final bool amazonShipmentIdHint;

  /// Callback bei Tap "Manuell eingeben" / "Manuell ändern".
  final VoidCallback? onManualInput;

  /// Callback "Übernehmen" — akzeptiert das needs_review-Tracking.
  final VoidCallback? onAcceptAsCorrect;

  /// Callback "Verwerfen" — entfernt das needs_review-Tracking.
  final VoidCallback? onDiscard;

  /// Live-Status aus dem externen Adapter-Poll. `null` = noch nie gepollt.
  final LiveTrackingStatus? liveStatus;

  /// Letztes Carrier-Event als Freitext (z.B. "Out for delivery, Berlin").
  final String? liveStatusLastEvent;

  /// Zeitpunkt des letzten Adapter-Polls.
  final DateTime? liveStatusUpdatedAt;

  /// Callback "Status aktualisieren" — triggert sofortigen Re-Track für
  /// genau diesen Deal (Klarna-Pattern). Wenn null, wird der Refresh-Button
  /// nicht angezeigt (z.B. in der Inbox-Vorschau, wo es noch keinen Deal
  /// gibt).
  final VoidCallback? onRetrack;

  /// Wenn true, wird der Refresh-Button als Spinner gerendert + disabled.
  /// Caller setzt das während des Edge-Function-Calls.
  final bool retrackInProgress;

  const TrackingStatusBlock({
    super.key,
    this.trackingNumber,
    this.confidence,
    this.carrier,
    this.needsReview = false,
    this.amazonShipmentIdHint = false,
    this.onManualInput,
    this.onAcceptAsCorrect,
    this.onDiscard,
    this.liveStatus,
    this.liveStatusLastEvent,
    this.liveStatusUpdatedAt,
    this.onRetrack,
    this.retrackInProgress = false,
  });

  TrackingDisplayState _resolveState() {
    if (amazonShipmentIdHint &&
        (trackingNumber == null || trackingNumber!.isEmpty)) {
      return TrackingDisplayState.amazonShipmentIdOnly;
    }
    if (needsReview &&
        trackingNumber != null &&
        trackingNumber!.isNotEmpty) {
      return TrackingDisplayState.needsReview;
    }
    if (confidence == TrackingConfidence.manual) {
      return TrackingDisplayState.manual;
    }
    if (confidence == TrackingConfidence.strong &&
        trackingNumber != null &&
        trackingNumber!.isNotEmpty) {
      return TrackingDisplayState.strong;
    }
    return TrackingDisplayState.empty;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = _resolveState();
    return Semantics(
      label: l10n.trackingStatusBlockA11yLabel,
      child: KeyedSubtree(
        key: Key('tracking-status-block-${state.name}'),
        child: _buildForState(context, state, l10n),
      ),
    );
  }

  /// Gibt den lokalisierten Label-String für einen LiveTrackingStatus zurück.
  static String? _liveStatusLabel(
      AppLocalizations l10n, LiveTrackingStatus? status) {
    if (status == null) return null;
    return switch (status) {
      LiveTrackingStatus.pending => l10n.liveStatusPending,
      LiveTrackingStatus.inTransit => l10n.liveStatusInTransit,
      LiveTrackingStatus.outForDelivery => l10n.liveStatusOutForDelivery,
      LiveTrackingStatus.delivered => l10n.liveStatusDelivered,
      LiveTrackingStatus.exception => l10n.liveStatusException,
      LiveTrackingStatus.expired => l10n.liveStatusExpired,
    };
  }

  Widget _buildForState(
    BuildContext context,
    TrackingDisplayState state,
    AppLocalizations l10n,
  ) {
    switch (state) {
      case TrackingDisplayState.strong:
        return _StrongState(
          trackingNumber: trackingNumber!,
          carrier: carrier,
          confidenceLabel: l10n.trackingConfidenceLabelStrong,
          onManualInput: onManualInput,
          editLabel: l10n.actionEdit,
          liveStatus: liveStatus,
          liveStatusLastEvent: liveStatusLastEvent,
          liveStatusUpdatedAt: liveStatusUpdatedAt,
          liveStatusLabel: _liveStatusLabel(l10n, liveStatus),
          onRetrack: onRetrack,
          retrackInProgress: retrackInProgress,
          retrackLabel: l10n.trackingRetrackCta,
        );
      case TrackingDisplayState.manual:
        return _ManualState(
          trackingNumber: trackingNumber,
          carrier: carrier,
          confidenceLabel: l10n.trackingConfidenceLabelManual,
          onManualInput: onManualInput,
          editLabel: l10n.actionEdit,
        );
      case TrackingDisplayState.empty:
        return _EmptyState(
          title: l10n.trackingNoneDetectedTitle,
          subtitle: l10n.trackingNoneDetectedSubtitle,
          ctaLabel: l10n.trackingEnterManuallyCta,
          onManualInput: onManualInput,
        );
      case TrackingDisplayState.needsReview:
        return _NeedsReviewState(
          trackingNumber: trackingNumber!,
          carrier: carrier,
          badgeLabel: l10n.trackingReviewNeededBadge,
          acceptLabel: l10n.trackingReviewAcceptCta,
          editLabel: l10n.trackingEnterManuallyCta,
          discardLabel: l10n.trackingReviewDismissCta,
          onAcceptAsCorrect: onAcceptAsCorrect,
          onManualInput: onManualInput,
          onDiscard: onDiscard,
        );
      case TrackingDisplayState.amazonShipmentIdOnly:
        return _AmazonShipmentIdState(
          hint: l10n.trackingCarrierAmazonLogisticsHintShort,
          detail: l10n.trackingAmazonShipmentIdHint,
          ctaLabel: l10n.trackingEnterManuallyCta,
          onManualInput: onManualInput,
        );
    }
  }
}

// ---------------------------------------------------------------------------
// State: strong
// ---------------------------------------------------------------------------
class _StrongState extends StatelessWidget {
  const _StrongState({
    required this.trackingNumber,
    required this.confidenceLabel,
    required this.editLabel,
    this.carrier,
    this.onManualInput,
    this.liveStatus,
    this.liveStatusLabel,
    this.liveStatusLastEvent,
    this.liveStatusUpdatedAt,
    this.onRetrack,
    this.retrackInProgress = false,
    this.retrackLabel,
  });

  final String trackingNumber;
  final String? carrier;
  final String confidenceLabel;
  final String editLabel;
  final VoidCallback? onManualInput;
  final LiveTrackingStatus? liveStatus;
  final String? liveStatusLabel;
  final String? liveStatusLastEvent;
  final DateTime? liveStatusUpdatedAt;
  final VoidCallback? onRetrack;
  final bool retrackInProgress;
  final String? retrackLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.successBgOf(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.successBorderOf(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 20,
              color: AppTheme.successTextOf(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        confidenceLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.successTextOf(context),
                        ),
                      ),
                      if (carrier != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          carrier!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMutedOf(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    trackingNumber,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                  // ── Live-Status-Slot ─────────────────────────────────
                  if (liveStatus != null) ...[
                    const SizedBox(height: 8),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: AppTheme.successBorderOf(context),
                    ),
                    const SizedBox(height: 8),
                    _LiveStatusSlot(
                      key: const Key('live-status-slot'),
                      liveStatus: liveStatus!,
                      liveStatusLabel: liveStatusLabel ?? '',
                      liveStatusLastEvent: liveStatusLastEvent,
                      liveStatusUpdatedAt: liveStatusUpdatedAt,
                    ),
                  ],
                ],
              ),
            ),
            // Re-Track-Button — Touch-Target 48×48. Sichtbar nur, wenn
            // ein Callback gesetzt ist (Deal-Detail), nicht in der Inbox-
            // Vorschau.
            if (onRetrack != null)
              _IconCta(
                key: const Key('tracking-retrack-cta'),
                icon: Icons.refresh_rounded,
                semanticsLabel: retrackLabel ?? '',
                onTap: retrackInProgress ? null : onRetrack,
                color: AppTheme.textMutedOf(context),
                showSpinner: retrackInProgress,
              ),
            // Edit-Button — Touch-Target 48×48 via SizedBox
            if (onManualInput != null)
              _IconCta(
                key: const Key('tracking-edit-cta-strong'),
                icon: Icons.edit_outlined,
                semanticsLabel: editLabel,
                onTap: onManualInput,
                color: AppTheme.textMutedOf(context),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// State: manual
// ---------------------------------------------------------------------------
class _ManualState extends StatelessWidget {
  const _ManualState({
    required this.confidenceLabel,
    required this.editLabel,
    this.trackingNumber,
    this.carrier,
    this.onManualInput,
  });

  final String? trackingNumber;
  final String? carrier;
  final String confidenceLabel;
  final String editLabel;
  final VoidCallback? onManualInput;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgSubtleOf(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.edit_rounded,
              size: 20,
              color: AppTheme.textMutedOf(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        confidenceLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMutedOf(context),
                        ),
                      ),
                      if (carrier != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          carrier!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMutedOf(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (trackingNumber != null &&
                      trackingNumber!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    SelectableText(
                      trackingNumber!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onManualInput != null)
              _IconCta(
                key: const Key('tracking-edit-cta-manual'),
                icon: Icons.edit_outlined,
                semanticsLabel: editLabel,
                onTap: onManualInput,
                color: AppTheme.textMutedOf(context),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// State: empty
// ---------------------------------------------------------------------------
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    this.onManualInput,
  });

  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback? onManualInput;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('tracking-empty-state'),
      decoration: BoxDecoration(
        color: AppTheme.bgSubtleOf(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_shipping_outlined,
                  size: 20,
                  color: AppTheme.textMutedOf(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textMutedOf(context),
              ),
            ),
            if (onManualInput != null) ...[
              const SizedBox(height: 10),
              _CtaButton(
                key: const Key('tracking-manual-input-cta'),
                label: ctaLabel,
                icon: Icons.add_rounded,
                onTap: onManualInput!,
                isPrimary: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// State: needsReview
// ---------------------------------------------------------------------------
class _NeedsReviewState extends StatelessWidget {
  const _NeedsReviewState({
    required this.trackingNumber,
    required this.badgeLabel,
    required this.acceptLabel,
    required this.editLabel,
    required this.discardLabel,
    this.carrier,
    this.onAcceptAsCorrect,
    this.onManualInput,
    this.onDiscard,
  });

  final String trackingNumber;
  final String? carrier;
  final String badgeLabel;
  final String acceptLabel;
  final String editLabel;
  final String discardLabel;
  final VoidCallback? onAcceptAsCorrect;
  final VoidCallback? onManualInput;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('tracking-needs-review-banner'),
      decoration: BoxDecoration(
        color: AppTheme.warningBgOf(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.warningBorderOf(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 20,
                  color: AppTheme.warningTextOf(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    trackingNumber,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Badge "Prüfen"
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppTheme.warning.withAlpha(80),
                    ),
                  ),
                  child: Text(
                    badgeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.warningTextOf(context),
                    ),
                  ),
                ),
              ],
            ),
            if (carrier != null) ...[
              const SizedBox(height: 2),
              Text(
                carrier!,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMutedOf(context),
                ),
              ),
            ],
            const SizedBox(height: 10),
            // Action-Buttons — auf 360px Phone vertikal gestapelt
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < Breakpoints.legacyTrackingNarrow;
                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (onAcceptAsCorrect != null)
                        _CtaButton(
                          key: const Key('tracking-accept-cta'),
                          label: acceptLabel,
                          icon: Icons.check_rounded,
                          onTap: onAcceptAsCorrect!,
                          isPrimary: true,
                                  ),
                      if (onManualInput != null) ...[
                        const SizedBox(height: 6),
                        _CtaButton(
                          key: const Key('tracking-manual-input-cta'),
                          label: editLabel,
                          icon: Icons.edit_outlined,
                          onTap: onManualInput!,
                          isPrimary: false,
                                  ),
                      ],
                      if (onDiscard != null) ...[
                        const SizedBox(height: 6),
                        _CtaButton(
                          key: const Key('tracking-discard-cta'),
                          label: discardLabel,
                          icon: Icons.close_rounded,
                          onTap: onDiscard!,
                          isPrimary: false,
                          isDanger: true,
                                  ),
                      ],
                    ],
                  );
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (onAcceptAsCorrect != null)
                      _CtaButton(
                        key: const Key('tracking-accept-cta'),
                        label: acceptLabel,
                        icon: Icons.check_rounded,
                        onTap: onAcceptAsCorrect!,
                        isPrimary: true,
                              ),
                    if (onManualInput != null)
                      _CtaButton(
                        key: const Key('tracking-manual-input-cta'),
                        label: editLabel,
                        icon: Icons.edit_outlined,
                        onTap: onManualInput!,
                        isPrimary: false,
                              ),
                    if (onDiscard != null)
                      _CtaButton(
                        key: const Key('tracking-discard-cta'),
                        label: discardLabel,
                        icon: Icons.close_rounded,
                        onTap: onDiscard!,
                        isPrimary: false,
                        isDanger: true,
                              ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// State: amazonShipmentIdOnly
// ---------------------------------------------------------------------------
class _AmazonShipmentIdState extends StatelessWidget {
  const _AmazonShipmentIdState({
    required this.hint,
    required this.detail,
    required this.ctaLabel,
    this.onManualInput,
  });

  final String hint;
  final String detail;
  final String ctaLabel;
  final VoidCallback? onManualInput;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.infoBgOf(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.infoBorderOf(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: AppTheme.infoTextOf(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hint,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMutedOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (onManualInput != null) ...[
              const SizedBox(height: 10),
              _CtaButton(
                key: const Key('tracking-manual-input-cta'),
                label: ctaLabel,
                icon: Icons.add_rounded,
                onTap: onManualInput!,
                isPrimary: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Live-Status-Slot (nur in strong-State sichtbar)
// ---------------------------------------------------------------------------

/// Zeigt Icon + Status-Label + optionalen Last-Event-Text + relative Zeit.
///
/// Layout: [Icon]  [status-label]  ·  [last-event ellipsis]  [relativezeit]
/// Mobile-First: auf 360px kein Overflow — last-event ist maxLines:1 + ellipsis.
class _LiveStatusSlot extends StatelessWidget {
  const _LiveStatusSlot({
    super.key,
    required this.liveStatus,
    required this.liveStatusLabel,
    this.liveStatusLastEvent,
    this.liveStatusUpdatedAt,
  });

  final LiveTrackingStatus liveStatus;
  final String liveStatusLabel;
  final String? liveStatusLastEvent;
  final DateTime? liveStatusUpdatedAt;

  /// Gibt das passende Icon für den Status zurück.
  static IconData _iconFor(LiveTrackingStatus s) => switch (s) {
        LiveTrackingStatus.pending => Icons.schedule,
        LiveTrackingStatus.inTransit => Icons.local_shipping_outlined,
        LiveTrackingStatus.outForDelivery => Icons.delivery_dining_outlined,
        LiveTrackingStatus.delivered => Icons.check_circle_outline,
        LiveTrackingStatus.exception => Icons.warning_amber_rounded,
        LiveTrackingStatus.expired => Icons.help_outline,
      };

  /// Gibt die passende Farbe für den Status zurück (context-aware).
  static Color _colorFor(BuildContext context, LiveTrackingStatus s) =>
      switch (s) {
        LiveTrackingStatus.pending => AppTheme.textMutedOf(context),
        LiveTrackingStatus.inTransit => AppTheme.accentTextOf(context),
        LiveTrackingStatus.outForDelivery => AppTheme.warningTextOf(context),
        LiveTrackingStatus.delivered => AppTheme.successTextOf(context),
        LiveTrackingStatus.exception => AppTheme.dangerTextOf(context),
        LiveTrackingStatus.expired => AppTheme.textMutedOf(context),
      };

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(context, liveStatus);
    final relTime = liveStatusUpdatedAt != null
        ? formatRelativeTime(context, liveStatusUpdatedAt!)
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(_iconFor(liveStatus), size: 16, color: color),
        const SizedBox(width: 6),
        // Status-Label — fest, nie abschneiden
        Text(
          liveStatusLabel,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        // Last-Event (optional, flexibel, ellipsis)
        if (liveStatusLastEvent != null &&
            liveStatusLastEvent!.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '·',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textMutedOf(context),
              ),
            ),
          ),
          Expanded(
            child: Text(
              liveStatusLastEvent!,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textMutedOf(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ] else
          const Spacer(),
        // Relative-Zeit (optional)
        if (relTime != null) ...[
          const SizedBox(width: 6),
          Text(
            relTime,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textMutedOf(context),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// Icon-Button mit mind. 48×48 dp Touch-Target.
///
/// Hit-Box: SizedBox 48×48 → 48dp unabhängig von Icon-Größe.
/// Das 18px-Icon bleibt visuell unverändert — nur die Hit-Box wächst.
class _IconCta extends StatelessWidget {
  const _IconCta({
    super.key,
    required this.icon,
    required this.semanticsLabel,
    required this.color,
    this.onTap,
    this.showSpinner = false,
  });

  final IconData icon;
  final String semanticsLabel;
  final Color color;
  final VoidCallback? onTap;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: semanticsLabel,
      child: SizedBox(
        width: 48,
        height: 48,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: showSpinner
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  )
                : Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}

/// Text-Button mit Icon. Touch-Target ≥ 48dp via minSize.
class _CtaButton extends StatelessWidget {
  const _CtaButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    required this.isPrimary,
    this.isDanger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final Color fg;
    if (isDanger) {
      fg = AppTheme.dangerTextOf(context);
    } else if (isPrimary) {
      fg = AppTheme.accentTextOf(context);
    } else {
      fg = AppTheme.textSecondaryOf(context);
    }

    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 13),
      ),
      style: TextButton.styleFrom(
        foregroundColor: fg,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
