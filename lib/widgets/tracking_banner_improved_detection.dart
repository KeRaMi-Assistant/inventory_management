import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';

/// Banner that informs the user that tracking detection was improved and asks
/// them to review deals flagged with `tracking_needs_review = true`.
///
/// Dismiss state is persisted via shared_preferences under
/// [_kDismissKey]. The banner reappears after a re-parse
/// (call [resetDismiss] from a Re-Parse trigger).
class TrackingBannerImprovedDetection extends StatelessWidget {
  static const String _kDismissKey = 'tracking_banner_dismissed_v1';

  final int needsReviewCount;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const TrackingBannerImprovedDetection({
    required this.needsReviewCount,
    required this.onDismiss,
    required this.onTap,
    super.key,
  });

  /// Call this after a re-parse so the banner becomes visible again.
  static Future<void> resetDismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDismissKey);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bgColor = AppTheme.warningBgOf(context);
    final borderColor = AppTheme.warningBorderOf(context);
    final textColor = AppTheme.warningTextOf(context);

    return Semantics(
      label: l10n.trackingBannerImprovedDetection,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          key: const Key('tracking-banner-improved-detection'),
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: textColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.trackingBannerImprovedDetection,
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Dismiss button — min 48x48 touch target via padding
              GestureDetector(
                onTap: onDismiss,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stateful wrapper that manages [SharedPreferences] dismiss state and only
/// renders [TrackingBannerImprovedDetection] when appropriate.
///
/// Usage:
/// ```dart
/// TrackingBannerController(
///   needsReviewCount: needsReviewCount,
///   onTap: () { /* navigate to filtered deals */ },
/// )
/// ```
class TrackingBannerController extends StatefulWidget {
  final int needsReviewCount;
  final VoidCallback onTap;

  const TrackingBannerController({
    required this.needsReviewCount,
    required this.onTap,
    super.key,
  });

  @override
  State<TrackingBannerController> createState() =>
      _TrackingBannerControllerState();
}

class _TrackingBannerControllerState extends State<TrackingBannerController> {
  bool _dismissed = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadDismissState();
  }

  Future<void> _loadDismissState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _dismissed =
          prefs.getBool(TrackingBannerImprovedDetection._kDismissKey) ?? false;
      _loaded = true;
    });
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(TrackingBannerImprovedDetection._kDismissKey, true);
    if (!mounted) return;
    setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _dismissed || widget.needsReviewCount == 0) {
      return const SizedBox.shrink();
    }
    return TrackingBannerImprovedDetection(
      needsReviewCount: widget.needsReviewCount,
      onDismiss: _dismiss,
      onTap: widget.onTap,
    );
  }
}
