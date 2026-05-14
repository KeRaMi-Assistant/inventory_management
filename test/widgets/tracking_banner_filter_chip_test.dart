import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inventory_management/l10n/app_localizations.dart';
import 'package:inventory_management/widgets/tracking_banner_improved_detection.dart';

// ─── Helper ──────────────────────────────────────────────────────────────────

Widget _wrap(Widget child, {Locale locale = const Locale('de')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  );
}

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // TrackingBannerImprovedDetection — pure widget tests
  // ─────────────────────────────────────────────────────────────────────────
  group('TrackingBannerImprovedDetection', () {
    testWidgets('renders banner text when visible', (tester) async {
      int dismissCalls = 0;
      int tapCalls = 0;
      await tester.pumpWidget(
        _wrap(
          TrackingBannerImprovedDetection(
            needsReviewCount: 3,
            onDismiss: () => dismissCalls++,
            onTap: () => tapCalls++,
          ),
        ),
      );
      await tester.pump();

      // Banner key present
      expect(
        find.byKey(const Key('tracking-banner-improved-detection')),
        findsOneWidget,
      );
      // Banner text present (DE)
      expect(
        find.textContaining('Tracking-Erkennung verbessert'),
        findsOneWidget,
      );
    });

    testWidgets('tapping banner body calls onTap', (tester) async {
      int tapCalls = 0;
      await tester.pumpWidget(
        _wrap(
          TrackingBannerImprovedDetection(
            needsReviewCount: 2,
            onDismiss: () {},
            onTap: () => tapCalls++,
          ),
        ),
      );
      await tester.pump();

      // Tap the banner (not the close button)
      await tester.tap(
        find.byKey(const Key('tracking-banner-improved-detection')),
      );
      await tester.pump();

      expect(tapCalls, greaterThan(0));
    });

    testWidgets('tapping close icon calls onDismiss', (tester) async {
      int dismissCalls = 0;
      await tester.pumpWidget(
        _wrap(
          TrackingBannerImprovedDetection(
            needsReviewCount: 2,
            onDismiss: () => dismissCalls++,
            onTap: () {},
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(dismissCalls, equals(1));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // TrackingBannerController — SharedPreferences dismiss state
  // ─────────────────────────────────────────────────────────────────────────
  group('TrackingBannerController', () {
    setUp(() {
      // Fresh SharedPreferences for each test
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('visible when count > 0 and not dismissed', (tester) async {
      int tapCalls = 0;
      await tester.pumpWidget(
        _wrap(
          TrackingBannerController(
            needsReviewCount: 5,
            onTap: () => tapCalls++,
          ),
        ),
      );
      // Wait for SharedPreferences async load
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('tracking-banner-improved-detection')),
        findsOneWidget,
      );
    });

    testWidgets('hidden when count == 0', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TrackingBannerController(
            needsReviewCount: 0,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('tracking-banner-improved-detection')),
        findsNothing,
      );
    });

    testWidgets('hidden after dismiss, visible again after resetDismiss',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          TrackingBannerController(
            needsReviewCount: 3,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Banner is visible
      expect(
        find.byKey(const Key('tracking-banner-improved-detection')),
        findsOneWidget,
      );

      // Dismiss it
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Banner gone
      expect(
        find.byKey(const Key('tracking-banner-improved-detection')),
        findsNothing,
      );

      // Reset dismiss state
      await TrackingBannerImprovedDetection.resetDismiss();

      // Rebuild with a different key so a fresh State is created.
      await tester.pumpWidget(
        _wrap(
          TrackingBannerController(
            key: const Key('banner-after-reset'),
            needsReviewCount: 3,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Banner visible again
      expect(
        find.byKey(const Key('tracking-banner-improved-detection')),
        findsOneWidget,
      );
    });

    testWidgets('already dismissed: hidden on first load', (tester) async {
      SharedPreferences.setMockInitialValues({
        'tracking_banner_dismissed_v1': true,
      });

      await tester.pumpWidget(
        _wrap(
          TrackingBannerController(
            needsReviewCount: 5,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('tracking-banner-improved-detection')),
        findsNothing,
      );
    });
  });
}
