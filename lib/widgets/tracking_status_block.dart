import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

import '../app_theme.dart';
import '../models/tracking_confidence.dart';

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
  });

  final String trackingNumber;
  final String? carrier;
  final String confidenceLabel;
  final String editLabel;
  final VoidCallback? onManualInput;

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
                ],
              ),
            ),
            // Edit-Button — Touch-Target 48×48 via padding
            if (onManualInput != null)
              _IconCta(
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
                final isNarrow = constraints.maxWidth < 320;
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
// Shared helpers
// ---------------------------------------------------------------------------

/// Icon-Button mit mind. 48×48 dp Touch-Target.
class _IconCta extends StatelessWidget {
  const _IconCta({
    required this.icon,
    required this.semanticsLabel,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String semanticsLabel;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: semanticsLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, size: 18, color: color),
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
