import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/screens/main_section.dart';
import 'package:inventory_management/screens/main_tab.dart';

void main() {
  group('MainSection (Tier-2b Sektions-Ebene)', () {
    test('hat exakt 5 Sektionen', () {
      expect(MainSection.values.length, 5);
      expect(MainSection.values, const [
        MainSection.dashboard,
        MainSection.verkauf,
        MainSection.lager,
        MainSection.auswertung,
        MainSection.konto,
      ]);
    });

    test('sectionOf ist total über alle 11 MainTab-Werte (kein Crash)', () {
      for (final tab in MainTab.values) {
        // Darf für JEDEN Tab eine Sektion liefern — Compiler erzwingt das
        // bereits, hier als Runtime-Sicherheitsnetz.
        expect(sectionOf(tab), isA<MainSection>());
      }
    });

    test('sectionOf mappt die Tabs in die richtigen Sektionen', () {
      expect(sectionOf(MainTab.dashboard), MainSection.dashboard);

      expect(sectionOf(MainTab.deals), MainSection.verkauf);
      expect(sectionOf(MainTab.tickets), MainSection.verkauf);
      expect(sectionOf(MainTab.inbox), MainSection.verkauf);

      expect(sectionOf(MainTab.inventory), MainSection.lager);
      expect(sectionOf(MainTab.suppliers), MainSection.lager);
      expect(sectionOf(MainTab.warehouse), MainSection.lager);

      expect(sectionOf(MainTab.stats), MainSection.auswertung);
      expect(sectionOf(MainTab.activity), MainSection.auswertung);

      expect(sectionOf(MainTab.settings), MainSection.konto);
      expect(sectionOf(MainTab.help), MainSection.konto);
    });

    test('defaultTabOf liefert für jede Sektion ein gültiges Default-Tab', () {
      expect(defaultTabOf(MainSection.dashboard), MainTab.dashboard);
      expect(defaultTabOf(MainSection.verkauf), MainTab.deals);
      // Lager-Sektion = der konsolidierte Warehouse-Hub (Tier-2a).
      expect(defaultTabOf(MainSection.lager), MainTab.warehouse);
      expect(defaultTabOf(MainSection.auswertung), MainTab.stats);
      expect(defaultTabOf(MainSection.konto), MainTab.settings);
    });

    test('Round-Trip: defaultTabOf(section) liegt wieder in derselben Sektion',
        () {
      for (final section in MainSection.values) {
        final tab = defaultTabOf(section);
        expect(
          sectionOf(tab),
          section,
          reason:
              'defaultTabOf(${section.name}) → ${tab.name} muss zurück in ${section.name} mappen',
        );
      }
    });

    test('section.name ist als A11y-Key tauglich (snake/lowercase)', () {
      for (final section in MainSection.values) {
        expect(section.name, isNotEmpty);
        expect(section.name, matches(RegExp(r'^[a-z]+$')));
      }
    });
  });
}
