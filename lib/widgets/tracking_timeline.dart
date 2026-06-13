import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/live_tracking_status.dart';
import '../models/tracking_event.dart';
import '../providers/deals_provider.dart';

/// Klarna-Style-Sendungsverlauf (Paket 1): vertikale Timeline aller
/// Carrier-Scans eines Deals aus `tracking_events`.
///
/// Lädt on-demand beim Einblenden (kein globaler Provider-State — die
/// Timeline ist nur im Deal-Detail sichtbar und nach Retrack via
/// [refreshToken]-Wechsel sofort neu ladbar).
///
/// Mobile-First: einspaltig, keine horizontalen Scrolls, Touch-Target des
/// Expand-Buttons ≥ 48 dp.
class TrackingTimelineSection extends StatefulWidget {
  final int dealId;

  /// Multi-Parcel: filtert die Timeline auf EIN Paket. `null` = alle Events
  /// des Deals (Single-Parcel-Verhalten, dort gibt es nur eine Nummer).
  final String? tracking;

  /// Bei Wechsel dieses Tokens (z.B. nach Retrack) wird neu geladen.
  final Object? refreshToken;

  const TrackingTimelineSection({
    super.key,
    required this.dealId,
    this.tracking,
    this.refreshToken,
  });

  @override
  State<TrackingTimelineSection> createState() =>
      _TrackingTimelineSectionState();
}

class _TrackingTimelineSectionState extends State<TrackingTimelineSection> {
  static const int _collapsedCount = 4;

  late Future<List<TrackingEvent>> _future;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant TrackingTimelineSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dealId != widget.dealId ||
        oldWidget.tracking != widget.tracking ||
        oldWidget.refreshToken != widget.refreshToken) {
      setState(() => _future = _load());
    }
  }

  Future<List<TrackingEvent>> _load() => context
      .read<DealsProvider>()
      .fetchTrackingEvents(widget.dealId, tracking: widget.tracking);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<List<TrackingEvent>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // Timeline ist Zusatz-Info — Fehler still verschlucken statt das
          // Deal-Detail mit einem Error-Banner zu belasten.
          return const SizedBox.shrink();
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final events = snapshot.data!;
        if (events.isEmpty) {
          return const SizedBox.shrink();
        }

        final visible =
            _expanded ? events : events.take(_collapsedCount).toList();
        final hiddenCount = events.length - _collapsedCount;

        return Column(
          key: const Key('tracking-timeline'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text(
              l10n.trackingTimelineTitle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < visible.length; i++)
              _TimelineRow(
                event: visible[i],
                isFirst: i == 0,
                isLast: i == visible.length - 1 &&
                    (_expanded || hiddenCount <= 0),
              ),
            if (hiddenCount > 0)
              TextButton.icon(
                key: const Key('tracking-timeline-toggle'),
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                ),
                label: Text(
                  _expanded
                      ? l10n.trackingTimelineShowLess
                      : l10n.trackingTimelineShowAll(events.length),
                  style: const TextStyle(fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textMutedOf(context),
                  minimumSize: const Size(48, 48),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Eine Timeline-Zeile: Status-Dot + Verbindungslinien links, Event-Text
/// + Ort/Zeit rechts. Neuester Event (isFirst) ist hervorgehoben.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.event,
    required this.isFirst,
    required this.isLast,
  });

  final TrackingEvent event;
  final bool isFirst;
  final bool isLast;

  Color _dotColor(BuildContext context) => switch (event.status) {
        LiveTrackingStatus.delivered => AppTheme.successTextOf(context),
        LiveTrackingStatus.outForDelivery => AppTheme.warningTextOf(context),
        LiveTrackingStatus.exception => AppTheme.dangerTextOf(context),
        LiveTrackingStatus.inTransit => AppTheme.accentTextOf(context),
        _ => AppTheme.textMutedOf(context),
      };

  @override
  Widget build(BuildContext context) {
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final timeLabel =
        DateFormat.MMMd(localeTag).add_Hm().format(event.occurredAt.toLocal());
    final dotColor = _dotColor(context);
    final muted = AppTheme.textMutedOf(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dot + Linien-Spalte (fixe Breite, kein Overflow auf 360px).
          SizedBox(
            width: 20,
            child: Column(
              children: [
                SizedBox(
                  height: 4,
                  child: isFirst
                      ? null
                      : VerticalDivider(
                          width: 2, thickness: 2, color: AppTheme.borderOf(context)),
                ),
                Container(
                  width: isFirst ? 12 : 8,
                  height: isFirst ? 12 : 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFirst ? dotColor : dotColor.withAlpha(150),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: VerticalDivider(
                        width: 2, thickness: 2, color: AppTheme.borderOf(context)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.description,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isFirst ? FontWeight.w600 : FontWeight.w400,
                      color: isFirst
                          ? AppTheme.textPrimaryOf(context)
                          : AppTheme.textSecondaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    event.location != null && event.location!.isNotEmpty
                        ? '${event.location} · $timeLabel'
                        : timeLabel,
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
