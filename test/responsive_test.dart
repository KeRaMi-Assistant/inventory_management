import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/utils/responsive.dart';

// ---------------------------------------------------------------------------
// responsive_test.dart
//
// Testet beide Achsen der Zwei-Achsen-API aus lib/utils/responsive.dart:
//
//   (a) Container-Achse — pure Functions: widthClassOf / isCompact / isMedium
//       / isExpanded / isLarge. Keine Widgets nötig, Grenzwerte vollständig.
//
//   (b) Viewport-Achse — Widget-Tests: screenSizeOf / isPhoneViewport /
//       isDesktopViewport. Viewport wird via tester.view gesetzt.
//
//   (c) Constraint-vs-Viewport-Bug-Test — PFLICHT-Regressionsschutz für die
//       schwerste Fehlerklasse des Responsive-Overhauls (§6.1 / §0.2):
//       ein schmaler Container bei breitem Viewport muss Container-Klasse
//       liefern, NICHT Viewport-Klasse.
//
// Siehe Plan plans/2026-05-22_ui-ux-responsive-overhaul.md §5.1 + §6.1.
// ---------------------------------------------------------------------------

// ── Viewport-Achse: Helper ──────────────────────────────────────────────────

/// Rendert ein minimales Widget und liest Viewport-Helper aus dem BuildContext.
Widget _viewportProbe({
  required ValueSetter<BuildContext> onContext,
}) {
  return MaterialApp(
    home: Builder(
      builder: (context) {
        onContext(context);
        return const SizedBox.shrink();
      },
    ),
  );
}

void main() {
  // =========================================================================
  // (a) Container-Achse — pure-Function-Tests
  // =========================================================================

  group('Container-Achse — widthClassOf(double)', () {
    // ── Grenzwerte exakt bei 600 ──────────────────────────────────────────
    test('599.9 → compact', () {
      expect(widthClassOf(599.9), WidthClass.compact);
    });

    test('600.0 → medium (exakt auf Breakpoints.phone)', () {
      expect(widthClassOf(600.0), WidthClass.medium);
    });

    test('600.1 → medium', () {
      expect(widthClassOf(600.1), WidthClass.medium);
    });

    // ── Grenzwerte exakt bei 900 ──────────────────────────────────────────
    test('899.9 → medium', () {
      expect(widthClassOf(899.9), WidthClass.medium);
    });

    test('900.0 → expanded (exakt auf Breakpoints.navRail)', () {
      expect(widthClassOf(900.0), WidthClass.expanded);
    });

    test('900.1 → expanded', () {
      expect(widthClassOf(900.1), WidthClass.expanded);
    });

    // ── Grenzwerte exakt bei 1200 ─────────────────────────────────────────
    test('1199.9 → expanded', () {
      expect(widthClassOf(1199.9), WidthClass.expanded);
    });

    test('1200.0 → large (exakt auf Breakpoints.master)', () {
      expect(widthClassOf(1200.0), WidthClass.large);
    });

    test('1200.1 → large', () {
      expect(widthClassOf(1200.1), WidthClass.large);
    });

    // ── Sonderwerte ───────────────────────────────────────────────────────
    test('0.0 → compact', () {
      // Ein auf 0 geshrinkter Container ist compact.
      expect(widthClassOf(0.0), WidthClass.compact);
    });

    test('sehr groß (10000.0) → large', () {
      expect(widthClassOf(10000.0), WidthClass.large);
    });

    // negative Breite: double.infinity und negative Werte treten in der Praxis
    // nicht auf (LayoutBuilder liefert immer ≥0), wir dokumentieren das
    // Verhalten aber explizit für spätere Leser:
    test('negative Breite (-1.0) → compact (treat-as-zero, kein Crash)', () {
      // widthClassOf(-1.0) < Breakpoints.phone → compact. Korrekt definiertes
      // Verhalten durch den guard `width < Breakpoints.phone`.
      expect(widthClassOf(-1.0), WidthClass.compact);
    });

    // ── Repräsentative Innen-Werte ────────────────────────────────────────
    test('360.0 (kleinstes Phone) → compact', () {
      expect(widthClassOf(360.0), WidthClass.compact);
    });

    test('750.0 (mittelbreiter Container) → medium', () {
      expect(widthClassOf(750.0), WidthClass.medium);
    });

    test('1050.0 (expanded Container) → expanded', () {
      expect(widthClassOf(1050.0), WidthClass.expanded);
    });

    test('1440.0 (Vollbild Desktop) → large', () {
      expect(widthClassOf(1440.0), WidthClass.large);
    });
  });

  // ── isCompact / isMedium / isExpanded / isLarge ──────────────────────────

  group('Container-Achse — isCompact / isMedium / isExpanded / isLarge', () {
    const values = [0.0, 360.0, 390.0, 599.9, 600.0, 768.0, 899.9, 900.0, 1199.9, 1200.0, 1440.0, 10000.0];

    test('isCompact ist exklusiv true für width < 600', () {
      for (final w in values) {
        expect(
          isCompact(w),
          w < Breakpoints.phone,
          reason: 'isCompact($w) sollte ${w < Breakpoints.phone} sein',
        );
      }
    });

    test('isMedium ist exklusiv true für 600 ≤ width < 900', () {
      for (final w in values) {
        final expected = w >= Breakpoints.phone && w < Breakpoints.navRail;
        expect(
          isMedium(w),
          expected,
          reason: 'isMedium($w) sollte $expected sein',
        );
      }
    });

    test('isExpanded ist exklusiv true für 900 ≤ width < 1200', () {
      for (final w in values) {
        final expected = w >= Breakpoints.navRail && w < Breakpoints.master;
        expect(
          isExpanded(w),
          expected,
          reason: 'isExpanded($w) sollte $expected sein',
        );
      }
    });

    test('isLarge ist exklusiv true für width ≥ 1200', () {
      for (final w in values) {
        expect(
          isLarge(w),
          w >= Breakpoints.master,
          reason: 'isLarge($w) sollte ${w >= Breakpoints.master} sein',
        );
      }
    });

    test('genau eine der 4 Funktionen ist true für jeden Wert (Partition)', () {
      for (final w in values) {
        final trueCount = [isCompact(w), isMedium(w), isExpanded(w), isLarge(w)]
            .where((b) => b)
            .length;
        expect(
          trueCount,
          1,
          reason:
              'Für width=$w soll exakt eine Klasse true sein (war $trueCount)',
        );
      }
    });
  });

  // ── ScreenSize-Enum vs. WidthClass-Enum — semantisch getrennt, mathematisch gleich ──

  group('ScreenSize vs. WidthClass — gleiche Schwellen, gleiche Klassen', () {
    // Beide Enums nutzen dieselben Breakpoints — ein Viewport von 500px
    // ergibt ScreenSize.compact und WidthClass.compact. Die Enums sind
    // bewusst getrennt (Viewport-Achse vs. Container-Achse), aber die
    // Grenzwerte sind identisch.

    final testCases = <(double, ScreenSize, WidthClass)>[
      (0.0, ScreenSize.compact, WidthClass.compact),
      (360.0, ScreenSize.compact, WidthClass.compact),
      (599.9, ScreenSize.compact, WidthClass.compact),
      (600.0, ScreenSize.medium, WidthClass.medium),
      (768.0, ScreenSize.medium, WidthClass.medium),
      (899.9, ScreenSize.medium, WidthClass.medium),
      (900.0, ScreenSize.expanded, WidthClass.expanded),
      (1050.0, ScreenSize.expanded, WidthClass.expanded),
      (1199.9, ScreenSize.expanded, WidthClass.expanded),
      (1200.0, ScreenSize.large, WidthClass.large),
      (1440.0, ScreenSize.large, WidthClass.large),
    ];

    test('widthClassOf(w) liefert für die gleichen Grenzen dieselbe Klassen-Position wie ScreenSize', () {
      // Wir prüfen, dass der ordinale Index (0=compact…3=large) für
      // beide Enums bei gleicher Eingabe übereinstimmt.
      for (final (w, expectedScreen, expectedWidth) in testCases) {
        final wc = widthClassOf(w);
        expect(
          wc,
          expectedWidth,
          reason: 'widthClassOf($w) sollte ${expectedWidth.name} sein',
        );
        // ordinal-Vergleich: die Klassen-Stufe ist identisch
        expect(
          wc.index,
          expectedScreen.index,
          reason:
              'WidthClass.${wc.name}.index (${wc.index}) soll gleich '
              'ScreenSize.${expectedScreen.name}.index (${expectedScreen.index}) '
              'bei width=$w sein — gleiche Schwellen, semantisch getrennte Enums',
        );
      }
    });
  });

  // =========================================================================
  // (b) Viewport-Achse — Widget-Tests
  // =========================================================================

  group('Viewport-Achse — screenSizeOf / isPhoneViewport / isDesktopViewport', () {
    // Hilfsfunktion: setzt Viewport, rendert den Probe-Widget, gibt den
    // BuildContext zurück.
    Future<BuildContext> setViewport(
      WidgetTester tester,
      double width,
      double height,
    ) async {
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late BuildContext capturedContext;
      await tester.pumpWidget(
        _viewportProbe(onContext: (ctx) => capturedContext = ctx),
      );
      await tester.pumpAndSettle();
      return capturedContext;
    }

    // ── 4 Referenz-Viewports (CLAUDE.md) ─────────────────────────────────

    testWidgets('360×640 (kleinstes Phone) → compact / isPhoneViewport=true / isDesktopViewport=false',
        (tester) async {
      final ctx = await setViewport(tester, 360, 640);
      expect(screenSizeOf(ctx), ScreenSize.compact);
      expect(isPhoneViewport(ctx), isTrue);
      expect(isDesktopViewport(ctx), isFalse);
    });

    testWidgets('390×844 (iPhone-Default) → compact / isPhoneViewport=true / isDesktopViewport=false',
        (tester) async {
      final ctx = await setViewport(tester, 390, 844);
      expect(screenSizeOf(ctx), ScreenSize.compact);
      expect(isPhoneViewport(ctx), isTrue);
      expect(isDesktopViewport(ctx), isFalse);
    });

    testWidgets('768×1024 (Tablet) → medium / isPhoneViewport=false / isDesktopViewport=false',
        (tester) async {
      final ctx = await setViewport(tester, 768, 1024);
      expect(screenSizeOf(ctx), ScreenSize.medium);
      expect(isPhoneViewport(ctx), isFalse);
      expect(isDesktopViewport(ctx), isFalse);
    });

    testWidgets('1440×900 (Desktop) → large / isPhoneViewport=false / isDesktopViewport=true',
        (tester) async {
      final ctx = await setViewport(tester, 1440, 900);
      expect(screenSizeOf(ctx), ScreenSize.large);
      expect(isPhoneViewport(ctx), isFalse);
      expect(isDesktopViewport(ctx), isTrue);
    });

    // ── Grenzwerte 599/600 ────────────────────────────────────────────────

    testWidgets('599px → compact / isPhoneViewport=true', (tester) async {
      final ctx = await setViewport(tester, 599, 900);
      expect(screenSizeOf(ctx), ScreenSize.compact);
      expect(isPhoneViewport(ctx), isTrue);
    });

    testWidgets('600px → medium / isPhoneViewport=false', (tester) async {
      final ctx = await setViewport(tester, 600, 900);
      expect(screenSizeOf(ctx), ScreenSize.medium);
      expect(isPhoneViewport(ctx), isFalse);
    });

    // ── Grenzwerte 899/900 ────────────────────────────────────────────────

    testWidgets('899px → medium / isDesktopViewport=false', (tester) async {
      final ctx = await setViewport(tester, 899, 900);
      expect(screenSizeOf(ctx), ScreenSize.medium);
      expect(isDesktopViewport(ctx), isFalse);
    });

    testWidgets('900px → expanded / isDesktopViewport=true', (tester) async {
      final ctx = await setViewport(tester, 900, 900);
      expect(screenSizeOf(ctx), ScreenSize.expanded);
      expect(isDesktopViewport(ctx), isTrue);
    });

    // ── Grenzwerte 1199/1200 ──────────────────────────────────────────────

    testWidgets('1199px → expanded', (tester) async {
      final ctx = await setViewport(tester, 1199, 900);
      expect(screenSizeOf(ctx), ScreenSize.expanded);
    });

    testWidgets('1200px → large', (tester) async {
      final ctx = await setViewport(tester, 1200, 900);
      expect(screenSizeOf(ctx), ScreenSize.large);
    });
  });

  // =========================================================================
  // (c) PFLICHT-TEST — Constraint-vs-Viewport-Bug
  //
  // Dies ist der wichtigste Regressionstest des gesamten Overhauls.
  //
  // Problem (§0.2 des Plans): Screens verwenden MediaQuery.of(context).size.width
  // statt constraints.maxWidth aus einem LayoutBuilder. Auf Desktop-Viewport
  // (1440px) läuft der Screen neben einer 220px-Sidebar — der tatsächlich
  // verfügbare Container ist nur ~1220px breit. Wenn der Code 1440 als Basis
  // nimmt, erscheint das Detail-Panel fälschlich, weil die Schwelle von
  // 1200px scheinbar überschritten ist, obwohl der Container faktisch zu eng
  // ist.
  //
  // Dieser Test demonstriert und sichert ab:
  //   1. Container-Achse (widthClassOf auf constraints.maxWidth) liefert
  //      die korrekte schmale Klasse des Containers.
  //   2. Viewport-Achse (isDesktopViewport auf BuildContext) liefert true
  //      für denselben Viewport.
  //   3. Beide Aussagen sind gleichzeitig wahr — sie sind NICHT widersprüchlich,
  //      sondern beschreiben zwei verschiedene Dimensionen. Ein Screen, der die
  //      falsche Achse wählt, würde hier fehlerhaft expandieren.
  // =========================================================================

  group('CONSTRAINT-VS-VIEWPORT-BUG — Pflicht-Regressionsschutz', () {
    // ── Setup: Viewport 1440px breit, Container aber nur 696px ──────────
    //
    // Szenario: Der User hat einen 1440px-Browser. Die App zeigt links eine
    // 220px-Sidebar. Der Body-Container hat rechts davon effektiv ~1220px.
    // Wir simulieren einen noch engeren Fall (696px) um sicherzustellen,
    // dass die Container-Klasse (medium/compact) sich NICHT mit der
    // Viewport-Klasse (large) vermischt.
    //
    // 696px entspricht einem typischen Screen-Inhalt neben einer
    // Sidebar (z.B. 220px) PLUS einem weiteren Panel (z.B. 524px Restbreite)
    // — praxisnaher Wert.

    testWidgets(
      'Container 696px bei Viewport 1440px: '
      'Container-Achse → medium, Viewport-Achse → large (isDesktopViewport=true)',
      (tester) async {
        // Viewport auf 1440×900 setzen (Desktop)
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        WidthClass? capturedContainerClass;
        bool? capturedIsDesktop;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  // Sidebar-Simulation: 744px → Body hat 696px (1440-744)
                  const SizedBox(width: 744),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Container-Achse: constraints.maxWidth
                        capturedContainerClass =
                            widthClassOf(constraints.maxWidth);

                        // Viewport-Achse: MediaQuery (BuildContext)
                        // Demonstriert, dass die Viewport-Achse ANDERS liegt.
                        capturedIsDesktop = isDesktopViewport(context);

                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Container ist 696px → medium (600–899px)
        expect(
          capturedContainerClass,
          WidthClass.medium,
          reason:
              'Container-Achse: constraints.maxWidth=696px liegt im medium-Bereich '
              '(600–899px). Ein Screen, der widthClassOf(constraints.maxWidth) '
              'nutzt, wird kein Detail-Panel zeigen (Schwelle wäre large=1200px).',
        );

        // Viewport ist 1440px → isDesktopViewport=true
        expect(
          capturedIsDesktop,
          isTrue,
          reason:
              'Viewport-Achse: Der Viewport ist 1440px und damit large/desktop. '
              'isDesktopViewport(context) gibt true zurück — korrekt für die '
              'Shell-Entscheidung (Bottom-Nav vs. Rail), FALSCH für Screen-interne '
              'Splits.',
        );

        // KERN-ASSERTION: Die zwei Achsen sind verschiedene Antworten auf
        // verschiedene Fragen. Beide stimmen — aber ein Screen, der die
        // Viewport-Achse für ein Screen-internes Detail-Panel benutzt,
        // würde fälschlich expandieren (large statt medium).
        expect(
          capturedContainerClass,
          isNot(WidthClass.large),
          reason:
              'Container-Klasse darf nicht large sein (Container ist 696px, '
              'nicht 1440px). Das wäre der Viewport-vs-Container-Bug.',
        );
      },
    );

    testWidgets(
      'Container 1300px bei Viewport 1440px: '
      'Container-Achse → large (Detail-Panel korrekt), Viewport-Achse → large',
      (tester) async {
        // Wenn der Container breit genug ist (1300px > 1200px Schwelle),
        // sollen BEIDE Achsen large liefern — das ist der Normalfall auf
        // einer App ohne Sidebar oder mit sehr schmaler Rail.
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        WidthClass? containerClass;
        ScreenSize? viewportClass;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  // Schmale Sidebar: nur 140px → Body hat 1300px
                  const SizedBox(width: 140),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        containerClass = widthClassOf(constraints.maxWidth);
                        viewportClass = screenSizeOf(context);
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Hier stimmen beide Achsen überein: Container ≥ 1200px → large
        expect(containerClass, WidthClass.large,
            reason: 'Container 1300px → large; Detail-Panel ist korrekt.');
        expect(viewportClass, ScreenSize.large,
            reason: 'Viewport 1440px → large.');
      },
    );

    testWidgets(
      'Container 1150px (expanded) bei Viewport 1440px: '
      'Container-Achse → expanded, kein Detail-Panel; '
      'Negativ-Test: isDesktopViewport=true demonstriert den Bug-Fall',
      (tester) async {
        // Dieser Test simuliert den konkreten Bug aus §0.2:
        // deals_screen.dart nutzte MediaQuery.of(context).size.width >= 1100.
        // Auf einem 1440px-Viewport war das true → Detail-Panel erschien.
        // Der Container neben der 220px-Sidebar war aber nur 1220px — knapp
        // über der neuen 1200px-Schwelle. Unser Beispiel: Sidebar 290px →
        // Container 1150px. Mit der alten deals_screen-Logik (Viewport 1440)
        // wäre das Summary-Panel sichtbar gewesen (Bug). Mit der neuen
        // Container-Achse (1150px < 1200px) bleibt es korrekt verborgen.
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        WidthClass? containerClass;
        bool? isDesktop;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  const SizedBox(width: 290), // Sidebar
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        containerClass = widthClassOf(constraints.maxWidth);
                        isDesktop = isDesktopViewport(context);
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Container 1150px → expanded (900–1199px), NICHT large
        expect(
          containerClass,
          WidthClass.expanded,
          reason:
              'Container-Achse: 1150px liegt im expanded-Bereich (900–1199px). '
              'Das Detail-Panel (Schwelle: large = ≥1200px) darf nicht erscheinen.',
        );

        // Viewport ist 1440px → isDesktopViewport = true
        // Dies ist der "Bug-Fall": würde ein Screen isDesktopViewport (statt
        // widthClassOf) für den Master-Detail-Split verwenden, würde er
        // fälschlich das Detail-Panel einblenden.
        expect(
          isDesktop,
          isTrue,
          reason:
              'Negativ-Test: isDesktopViewport(context)=true auf dem 1440px-Viewport. '
              'Ein Screen, der diese Funktion für ein Screen-internes Layout nutzt '
              '(statt widthClassOf(constraints.maxWidth)), würde fälschlich das '
              'Detail-Panel zeigen — obwohl der Container nur 1150px breit ist.',
        );

        // Kern: Container expanded ≠ large
        expect(containerClass, isNot(WidthClass.large),
            reason:
                'Wäre containerClass=large, hätte die Container-Achse denselben '
                'Bug wie die Viewport-Achse.');
      },
    );
  });
}
