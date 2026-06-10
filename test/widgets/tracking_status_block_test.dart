import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/l10n/app_localizations.dart';
import 'package:inventory_management/models/live_tracking_status.dart';
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
  // Touch-Target ≥ 48dp (CLAUDE.md Mobile-First)
  // -------------------------------------------------------------------------
  group('TrackingStatusBlock — touch targets >= 48dp', () {
    testWidgets('needsReview CTAs (accept / manual-input / discard) all >= 48dp',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          TrackingStatusBlock(
            trackingNumber: '1Z999AA10123456784',
            confidence: TrackingConfidence.strong,
            carrier: 'UPS',
            needsReview: true,
            onManualInput: () {},
            onAcceptAsCorrect: () {},
            onDiscard: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final keyStr in [
        'tracking-accept-cta',
        'tracking-manual-input-cta',
        'tracking-discard-cta',
      ]) {
        final finder = find.byKey(Key(keyStr));
        if (finder.evaluate().isEmpty) continue; // state may hide some
        final size = tester.getSize(finder);
        expect(size.width, greaterThanOrEqualTo(48),
            reason: '$keyStr width >= 48dp (was ${size.width})');
        expect(size.height, greaterThanOrEqualTo(48),
            reason: '$keyStr height >= 48dp (was ${size.height})');
      }
    });

    testWidgets('strong state: edit icon-cta hit-box >= 48dp', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TrackingStatusBlock(
            trackingNumber: '1Z999AA10123456784',
            confidence: TrackingConfidence.strong,
            carrier: 'UPS',
            onManualInput: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final finder = find.byKey(const Key('tracking-edit-cta-strong'));
      expect(finder, findsOneWidget,
          reason:
              'tracking-edit-cta-strong must be present when onManualInput is set');
      final size = tester.getSize(finder);
      expect(size.width, greaterThanOrEqualTo(48),
          reason: 'edit-cta-strong width >= 48dp (was ${size.width})');
      expect(size.height, greaterThanOrEqualTo(48),
          reason: 'edit-cta-strong height >= 48dp (was ${size.height})');
    });

    testWidgets('manual state: edit icon-cta hit-box >= 48dp', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TrackingStatusBlock(
            trackingNumber: '1234567890',
            confidence: TrackingConfidence.manual,
            onManualInput: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final finder = find.byKey(const Key('tracking-edit-cta-manual'));
      expect(finder, findsOneWidget,
          reason:
              'tracking-edit-cta-manual must be present when onManualInput is set');
      final size = tester.getSize(finder);
      expect(size.width, greaterThanOrEqualTo(48),
          reason: 'edit-cta-manual width >= 48dp (was ${size.width})');
      expect(size.height, greaterThanOrEqualTo(48),
          reason: 'edit-cta-manual height >= 48dp (was ${size.height})');
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

  // -------------------------------------------------------------------------
  // Live-Status-Slot tests (A3)
  // -------------------------------------------------------------------------
  group('TrackingStatusBlock — Live-Status-Slot', () {
    testWidgets(
        'strong + liveStatus=inTransit → slot visible, correct icon key',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TrackingStatusBlock(
            trackingNumber: '1Z999AA10123456784',
            confidence: TrackingConfidence.strong,
            carrier: 'UPS',
            liveStatus: LiveTrackingStatus.inTransit,
            liveStatusLastEvent: 'Versendet',
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Slot muss sichtbar sein
      expect(find.byKey(const Key('live-status-slot')), findsOneWidget);
      // DE-Label "Unterwegs" muss erscheinen
      expect(find.text('Unterwegs'), findsOneWidget);
      // Last-Event-Text
      expect(find.text('Versendet'), findsOneWidget);
    });

    testWidgets('strong + liveStatus=null → kein Slot', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TrackingStatusBlock(
            trackingNumber: '1Z999AA10123456784',
            confidence: TrackingConfidence.strong,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('live-status-slot')), findsNothing);
    });

    testWidgets('liveStatus=exception → DE-Label "Problem — bitte prüfen"',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TrackingStatusBlock(
            trackingNumber: '1Z999AA10123456784',
            confidence: TrackingConfidence.strong,
            liveStatus: LiveTrackingStatus.exception,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Problem — bitte prüfen'), findsOneWidget);
    });

    testWidgets('liveStatus=delivered → DE-Label "Zugestellt"',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TrackingStatusBlock(
            trackingNumber: '1Z999AA10123456784',
            confidence: TrackingConfidence.strong,
            liveStatus: LiveTrackingStatus.delivered,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Zugestellt'), findsOneWidget);
    });

    testWidgets(
        'long last_event → ellipsis: widget renders without overflow on narrow viewport',
        (tester) async {
      // 360px Phone viewport
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrap(
          const TrackingStatusBlock(
            trackingNumber: '1Z999AA10123456784',
            confidence: TrackingConfidence.strong,
            liveStatus: LiveTrackingStatus.inTransit,
            liveStatusLastEvent:
                'Das ist ein sehr langer Carrier-Event-Text der sicher '
                'nicht in eine Zeile passt und truncated werden muss',
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Widget muss ohne Exception rendern
      expect(find.byKey(const Key('live-status-slot')), findsOneWidget);
      // Kein RenderFlex-Overflow — pumpAndSettle würde bei Overflow eine Exception werfen
    });

    testWidgets('relative time: updatedAt 5min ago → "vor 5 min" (DE)',
        (tester) async {
      final fiveMinAgo =
          DateTime.now().subtract(const Duration(minutes: 5));
      await tester.pumpWidget(
        _wrap(
          TrackingStatusBlock(
            trackingNumber: '1Z999AA10123456784',
            confidence: TrackingConfidence.strong,
            liveStatus: LiveTrackingStatus.inTransit,
            liveStatusUpdatedAt: fiveMinAgo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('vor 5 min'), findsOneWidget);
    });

    testWidgets(
        'relative time in EN locale: updatedAt 10min ago → "10 min ago"',
        (tester) async {
      final tenMinAgo =
          DateTime.now().subtract(const Duration(minutes: 10));
      await tester.pumpWidget(
        _wrap(
          TrackingStatusBlock(
            trackingNumber: '1Z999AA10123456784',
            confidence: TrackingConfidence.strong,
            liveStatus: LiveTrackingStatus.inTransit,
            liveStatusUpdatedAt: tenMinAgo,
          ),
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('10 min ago'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Re-Track CTA (Klarna-Pattern) — sichtbar nur im strong-State, wenn ein
  // Callback gesetzt ist. Spinner ersetzt das Refresh-Icon während eines
  // laufenden Polls.
  // -------------------------------------------------------------------------
  group('TrackingStatusBlock — re-track CTA', () {
    testWidgets('strong + onRetrack → button visible + tap fires callback',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          TrackingStatusBlock(
            trackingNumber: '1Z999AA10123456784',
            confidence: TrackingConfidence.strong,
            carrier: 'UPS',
            onRetrack: () => taps++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final btn = find.byKey(const Key('tracking-retrack-cta'));
      expect(btn, findsOneWidget);
      await tester.tap(btn);
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('strong without onRetrack → no refresh button rendered',
        (tester) async {
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
      expect(find.byKey(const Key('tracking-retrack-cta')), findsNothing);
    });

    testWidgets('retrackInProgress=true → spinner shown, taps blocked',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          TrackingStatusBlock(
            trackingNumber: '1Z999AA10123456784',
            confidence: TrackingConfidence.strong,
            carrier: 'UPS',
            onRetrack: () => taps++,
            retrackInProgress: true,
          ),
        ),
      );
      await tester.pump(); // do NOT pumpAndSettle (spinner animates forever)
      final btn = find.byKey(const Key('tracking-retrack-cta'));
      expect(btn, findsOneWidget);
      expect(
        find.descendant(
          of: btn,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      // Tap while in-progress should not invoke callback (onTap=null).
      await tester.tap(btn);
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('refresh button has 48dp touch target', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TrackingStatusBlock(
            trackingNumber: '1Z999AA10123456784',
            confidence: TrackingConfidence.strong,
            carrier: 'UPS',
            onRetrack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final btn = find.byKey(const Key('tracking-retrack-cta'));
      final size = tester.getSize(btn);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });

  // -------------------------------------------------------------------------
  // Paket 1: ETA-Zeile + Copy-/Carrier-Link-CTAs im strong-State
  // -------------------------------------------------------------------------
  group('TrackingStatusBlock — ETA + Copy/Carrier-Link (Paket 1)', () {
    final eta = DateTime(2026, 6, 11, 16);

    testWidgets(
        'strong + liveEta + carrierId=dhl → ETA-Zeile, Copy- und Verfolgen-CTA',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          TrackingStatusBlock(
            trackingNumber: 'JJD0123456789012345',
            confidence: TrackingConfidence.strong,
            carrier: 'DHL',
            carrierId: 'dhl',
            liveStatus: LiveTrackingStatus.outForDelivery,
            liveEta: eta,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tracking-eta-row')), findsOneWidget);
      expect(find.byKey(const Key('tracking-copy-cta')), findsOneWidget);
      expect(
          find.byKey(const Key('tracking-open-carrier-cta')), findsOneWidget);
    });

    testWidgets('delivered → ETA-Zeile wird ausgeblendet', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TrackingStatusBlock(
            trackingNumber: 'JJD0123456789012345',
            confidence: TrackingConfidence.strong,
            carrierId: 'dhl',
            liveStatus: LiveTrackingStatus.delivered,
            liveEta: eta,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tracking-eta-row')), findsNothing);
    });

    testWidgets('ohne carrierId → kein Verfolgen-CTA, Copy bleibt',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TrackingStatusBlock(
            trackingNumber: 'JJD0123456789012345',
            confidence: TrackingConfidence.strong,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tracking-open-carrier-cta')), findsNothing);
      expect(find.byKey(const Key('tracking-copy-cta')), findsOneWidget);
    });

    testWidgets('Copy-CTA zeigt Bestätigungs-SnackBar', (tester) async {
      // Clipboard-Platform-Channel mocken — ohne Handler wirft
      // Clipboard.setData im Test MissingPluginException.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => null,
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.pumpWidget(
        _wrap(
          const TrackingStatusBlock(
            trackingNumber: 'JJD0123456789012345',
            confidence: TrackingConfidence.strong,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tracking-copy-cta')));
      // Zwei Pumps: erst läuft der async Clipboard-Call durch, dann wird
      // die SnackBar eingefügt.
      await tester.pump();
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
      // SnackBar-Dismiss-Timer (2s) ablaufen lassen — sonst meckert das
      // Test-Framework über pending Timers.
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
