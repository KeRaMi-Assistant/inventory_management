import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/l10n/app_localizations.dart';
import 'package:inventory_management/models/tracking_confidence.dart';
import 'package:inventory_management/widgets/tracking_status_block.dart';

// ---------------------------------------------------------------------------
// Helper: wraps widget with required Localizations + Material app
// ---------------------------------------------------------------------------
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
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  );
}

void main() {
  // -------------------------------------------------------------------------
  // Smoke tests — 1 per state
  // -------------------------------------------------------------------------
  group('TrackingStatusBlock — smoke tests (1 per state)', () {
    testWidgets('state: strong — renders without crash', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TrackingStatusBlock(
            trackingNumber: '1Z999AA10123456784',
            confidence: TrackingConfidence.strong,
            carrier: 'UPS',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tracking-status-block-strong')),
          findsOneWidget);
    });

    testWidgets('state: manual — renders without crash', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TrackingStatusBlock(
            trackingNumber: '1234567890',
            confidence: TrackingConfidence.manual,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tracking-status-block-manual')),
          findsOneWidget);
    });

    testWidgets('state: empty — renders without crash', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TrackingStatusBlock(
            trackingNumber: null,
            confidence: null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tracking-status-block-empty')),
          findsOneWidget);
    });

    testWidgets('state: needsReview — renders without crash', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TrackingStatusBlock(
            trackingNumber: 'DE123456789',
            confidence: TrackingConfidence.none,
            needsReview: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tracking-status-block-needsReview')),
          findsOneWidget);
    });

    testWidgets('state: amazonShipmentIdOnly — renders without crash',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TrackingStatusBlock(
            trackingNumber: null,
            confidence: null,
            amazonShipmentIdHint: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
          find.byKey(
              const Key('tracking-status-block-amazonShipmentIdOnly')),
          findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Callback tests
  // -------------------------------------------------------------------------
  group('TrackingStatusBlock — callback tests', () {
    testWidgets('empty state: tap "Manuell eingeben" fires onManualInput',
        (tester) async {
      var called = false;
      await tester.pumpWidget(
        _wrap(
          TrackingStatusBlock(
            trackingNumber: null,
            confidence: null,
            onManualInput: () => called = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tracking-manual-input-cta')));
      await tester.pump();
      expect(called, isTrue);
    });

    testWidgets(
        'needsReview state: tap "Übernehmen" fires onAcceptAsCorrect',
        (tester) async {
      var acceptCalled = false;
      await tester.pumpWidget(
        _wrap(
          TrackingStatusBlock(
            trackingNumber: 'DE123456789',
            confidence: TrackingConfidence.none,
            needsReview: true,
            onAcceptAsCorrect: () => acceptCalled = true,
            onManualInput: () {},
            onDiscard: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tracking-accept-cta')));
      await tester.pump();
      expect(acceptCalled, isTrue);
    });

    testWidgets('needsReview state: tap "Verwerfen" fires onDiscard',
        (tester) async {
      var discardCalled = false;
      await tester.pumpWidget(
        _wrap(
          TrackingStatusBlock(
            trackingNumber: 'DE123456789',
            confidence: TrackingConfidence.none,
            needsReview: true,
            onAcceptAsCorrect: () {},
            onManualInput: () {},
            onDiscard: () => discardCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tracking-discard-cta')));
      await tester.pump();
      expect(discardCalled, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // l10n label tests
  // -------------------------------------------------------------------------
  group('TrackingStatusBlock — l10n label tests', () {
    testWidgets(
        'confidence=strong shows trackingConfidenceLabelStrong text (DE)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TrackingStatusBlock(
            trackingNumber: '1Z999AA10123456784',
            confidence: TrackingConfidence.strong,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // DE: "Verifiziert"
      expect(find.text('Verifiziert'), findsOneWidget);
    });

    testWidgets(
        'confidence=manual shows trackingConfidenceLabelManual text (DE)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TrackingStatusBlock(
            trackingNumber: '1234567890',
            confidence: TrackingConfidence.manual,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // DE: "Manuell"
      expect(find.text('Manuell'), findsOneWidget);
    });

    testWidgets(
        'confidence=null + trackingNumber=null → state empty, shows trackingNoneDetectedTitle (DE)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TrackingStatusBlock(
            trackingNumber: null,
            confidence: null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // DE: "Keine Sendungsnummer erkannt"
      expect(find.text('Keine Sendungsnummer erkannt'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Key assertions
  // -------------------------------------------------------------------------
  group('TrackingStatusBlock — key assertions', () {
    testWidgets('needsReview banner has Key tracking-needs-review-banner',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TrackingStatusBlock(
            trackingNumber: 'DE123456789',
            confidence: null,
            needsReview: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tracking-needs-review-banner')),
          findsOneWidget);
    });

    testWidgets('empty state has Key tracking-empty-state', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TrackingStatusBlock(
            trackingNumber: null,
            confidence: null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
          find.byKey(const Key('tracking-empty-state')), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // State resolution edge cases
  // -------------------------------------------------------------------------
  group('TrackingStatusBlock — state resolution edge cases', () {
    testWidgets(
        'amazonShipmentIdHint=true + non-empty trackingNumber → NOT amazonShipmentIdOnly',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TrackingStatusBlock(
            trackingNumber: 'TBA123456789000',
            confidence: TrackingConfidence.strong,
            amazonShipmentIdHint: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Has a non-null trackingNumber → resolves to strong, not amazonShipmentIdOnly
      expect(find.byKey(const Key('tracking-status-block-strong')),
          findsOneWidget);
    });

    testWidgets(
        'needsReview=true + empty trackingNumber → falls through to empty state',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TrackingStatusBlock(
            trackingNumber: '',
            confidence: null,
            needsReview: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
          find.byKey(const Key('tracking-status-block-empty')), findsOneWidget);
    });
  });
}
