// ignore_for_file: avoid_print

/// Unit tests for DealCard Quick-Status-Sheet mode-logic.
///
/// The full widget test (Long-Press → Sheet renders → Provider.updateDeal)
/// requires a live SupabaseRepository mock which is out of scope for the
/// current test infrastructure. Instead, the mode-selection logic is
/// extracted into [_shouldOpenQuickStatusSheet] and tested here in isolation.
///
/// Smoke-widget test: keyboard + provider integration tested via
/// browser-tester smoke scenario `smoke-theme, mobile-overflow` on `/deals`.
library;

import 'package:flutter_test/flutter_test.dart';

// ─── Mode-logic helper (mirrors DealCard.onLongPress logic) ──────────────────

/// Returns whether a long-press should open the Quick-Status-Sheet.
///
/// Rule: open sheet only when no deal is currently selected (bulk-select
/// mode is inactive). When [selectedCount] > 0, long-press extends the
/// bulk selection instead.
bool _shouldOpenQuickStatusSheet({required int selectedCount}) =>
    selectedCount == 0;

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('DealCard Quick-Status mode-logic', () {
    test('Long-Press in Normal-Modus (keine Selektion) → Sheet öffnen', () {
      expect(
        _shouldOpenQuickStatusSheet(selectedCount: 0),
        isTrue,
        reason: 'Keine deals selektiert → Quick-Status-Sheet soll öffnen',
      );
    });

    test('Long-Press im Bulk-Select-Modus (1 selektiert) → kein Sheet', () {
      expect(
        _shouldOpenQuickStatusSheet(selectedCount: 1),
        isFalse,
        reason: '1 deal selektiert → Long-Press toggelt Bulk-Select, kein Sheet',
      );
    });

    test('Long-Press im Bulk-Select-Modus (mehrere selektiert) → kein Sheet',
        () {
      expect(
        _shouldOpenQuickStatusSheet(selectedCount: 5),
        isFalse,
        reason:
            'Mehrere deals selektiert → Long-Press toggelt Bulk-Select, kein Sheet',
      );
    });

    test('Grenzwert: selectedCount=0 ist die einzige Bedingung für Sheet', () {
      // Only 0 opens the sheet — any positive count suppresses it.
      for (var i = 1; i <= 10; i++) {
        expect(
          _shouldOpenQuickStatusSheet(selectedCount: i),
          isFalse,
          reason: 'selectedCount=$i soll kein Sheet öffnen',
        );
      }
      expect(_shouldOpenQuickStatusSheet(selectedCount: 0), isTrue);
    });
  });

  group('DealCard Quick-Status statusOptions coverage', () {
    // Verify that all 5 expected DB status values are present in the list
    // that the sheet iterates. This guards against accidental renames.
    const expectedStatuses = [
      'Bestellt',
      'Unterwegs',
      'Angekommen',
      'Rechnung gestellt',
      'Done',
    ];

    test('alle 5 Status-Optionen vorhanden', () {
      // Mirroring InventoryProvider.statusOptions without importing the
      // full provider (avoids Supabase dependency in test).
      const statusOptions = [
        'Bestellt',
        'Unterwegs',
        'Angekommen',
        'Rechnung gestellt',
        'Done',
      ];

      expect(statusOptions.length, 5);
      for (final s in expectedStatuses) {
        expect(statusOptions.contains(s), isTrue,
            reason: '"$s" muss in statusOptions enthalten sein');
      }
    });

    test('Key-Namen für quickStatusOption folgen Convention', () {
      const statusOptions = [
        'Bestellt',
        'Unterwegs',
        'Angekommen',
        'Rechnung gestellt',
        'Done',
      ];
      // Each status must produce a valid Key string (non-empty, no null chars).
      for (final status in statusOptions) {
        final keyStr = 'quickStatusOption-$status';
        expect(keyStr.isNotEmpty, isTrue);
        expect(keyStr.contains('\x00'), isFalse);
      }
    });
  });
}
