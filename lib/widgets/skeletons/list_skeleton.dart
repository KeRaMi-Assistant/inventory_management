import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// shouldShowSkeleton — Cold-Start-Race-Fix
// ─────────────────────────────────────────────────────────────────────────────

/// Pure helper to decide whether to show a skeleton loader instead of content.
///
/// Rules:
/// - If [initialLoadAttempted] is false AND [hasData] is false → show skeleton
///   (cold-start race: provider has not yet fired any load attempt).
/// - Otherwise → show skeleton only while [isLoading] AND NOT [hasData].
///   Once data is present a re-load (refresh) must NOT replace content with
///   skeleton (no layout jank).
///
/// Usage inside a Screen's build():
/// ```dart
/// AnimatedSwitcher(
///   duration: const Duration(milliseconds: 200),
///   child: shouldShowSkeleton(
///     isLoading: provider.isLoading,
///     hasData: provider.items.isNotEmpty,
///     initialLoadAttempted: provider.initialLoadAttempted,
///   )
///     ? const ListSkeleton(key: ValueKey('skeleton'))
///     : YourActualList(key: ValueKey('content')),
/// )
/// ```
bool shouldShowSkeleton({
  required bool isLoading,
  required bool hasData,
  bool initialLoadAttempted = true,
}) {
  if (!initialLoadAttempted && !hasData) return true;
  return isLoading && !hasData;
}

// ─────────────────────────────────────────────────────────────────────────────
// ListSkeleton
// ─────────────────────────────────────────────────────────────────────────────

/// Central skeleton-loading component for list screens.
///
/// Wraps a fixed-count list of placeholder cards inside a `Skeletonizer.zone`
/// with `enabled: true`. This widget IS the loading state — no conditional
/// wrapping based on `isLoading` happens inside; the caller decides when to
/// show this widget (e.g. via [shouldShowSkeleton] + `AnimatedSwitcher`).
///
/// IMPORTANT — itemCount is ALWAYS fixed (default 6). Never pass
/// `min(realData.length, N)` here; that breaks performance on Phone (Plan §5.1
/// risk 13). The skeleton must represent a plausible screen fill, not the
/// actual data shape.
///
/// The widget uses `ListView.builder` with `shrinkWrap: true` and
/// `NeverScrollableScrollPhysics` so it composes safely inside any parent
/// scrollable. When placed directly inside a bounded `Scaffold` body the
/// list clips naturally without overflow.
///
/// A11y key: `Key('skeletonLoader')` is placed on the root widget so
/// browser-tester / Playwright can detect the loading state reliably.
///
/// Example — swap skeleton ↔ content:
/// ```dart
/// AnimatedSwitcher(
///   duration: const Duration(milliseconds: 200),
///   child: shouldShowSkeleton(isLoading: p.isLoading, hasData: p.items.isNotEmpty)
///     ? const ListSkeleton(key: ValueKey('skeleton'))
///     : MyList(key: ValueKey('content')),
/// )
/// ```
class ListSkeleton extends StatelessWidget {
  /// Number of skeleton items to render. NEVER derive from real data length.
  final int itemCount;

  /// Height of each individual skeleton item card.
  final double itemHeight;

  /// Optional custom item builder. Receives [context] and [index].
  /// Even when provided, it is called only with placeholder / bone content —
  /// never with real data. The builder is responsible for returning a
  /// Skeletonizer-compatible placeholder widget.
  final Widget Function(BuildContext context, int index)? itemBuilder;

  /// Padding around the list.
  final EdgeInsetsGeometry padding;

  const ListSkeleton({
    super.key,
    this.itemCount = 6,
    this.itemHeight = 88,
    this.itemBuilder,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Skeletonizer.zone(
      key: const Key('skeletonLoader'),
      child: ListView.builder(
        padding: padding,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (ctx, index) => Padding(
          padding: index < itemCount - 1
              ? const EdgeInsets.only(bottom: 10)
              : EdgeInsets.zero,
          child: itemBuilder != null
              ? itemBuilder!(ctx, index)
              : _DefaultSkeletonCard(height: itemHeight),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DefaultSkeletonCard — generic bone-layout for a list item
// ─────────────────────────────────────────────────────────────────────────────

class _DefaultSkeletonCard extends StatelessWidget {
  final double height;

  const _DefaultSkeletonCard({required this.height});

  @override
  Widget build(BuildContext context) {
    final surface = AppTheme.bgSurfaceOf(context);
    final border = AppTheme.borderOf(context);
    final muted = AppTheme.textMutedOf(context);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Leading circle avatar bone
          const Bone.circle(size: 42),
          const SizedBox(width: 12),
          // Text lines
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title line
                Bone.text(
                  words: 3,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 6),
                // Subtitle line — slightly shorter
                Bone.text(
                  words: 4,
                  style: TextStyle(
                    fontSize: 12,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 6),
                // Third line — very short (e.g. status / date)
                Bone.text(
                  words: 2,
                  style: TextStyle(
                    fontSize: 12,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Trailing chip / badge bone
          const Bone(
            width: 56,
            height: 24,
            uniRadius: 12,
          ),
        ],
      ),
    );
  }
}
