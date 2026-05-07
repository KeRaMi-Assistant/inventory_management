import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/inbox_message.dart';
import 'package:inventory_management/services/inbox_match_service.dart';

void main() {
  group('InboxMatchService.mapShipStatusToDeal', () {
    test('shipped → Unterwegs', () {
      expect(
        InboxMatchService.mapShipStatusToDeal(SuggestionShipStatus.shipped),
        'Unterwegs',
      );
    });

    test('delivered → Angekommen', () {
      expect(
        InboxMatchService.mapShipStatusToDeal(SuggestionShipStatus.delivered),
        'Angekommen',
      );
    });

    test('cancelled / refunded → Done', () {
      expect(
        InboxMatchService.mapShipStatusToDeal(SuggestionShipStatus.cancelled),
        'Done',
      );
      expect(
        InboxMatchService.mapShipStatusToDeal(SuggestionShipStatus.refunded),
        'Done',
      );
    });

    test('ordered und null → kein Mapping', () {
      expect(
        InboxMatchService.mapShipStatusToDeal(SuggestionShipStatus.ordered),
        isNull,
      );
      expect(InboxMatchService.mapShipStatusToDeal(null), isNull);
    });

    test('alle gemappten Werte landen im DB-CHECK-Constraint', () {
      const allowed = {
        'Bestellt',
        'Unterwegs',
        'Angekommen',
        'Rechnung gestellt',
        'Done',
      };
      for (final s in SuggestionShipStatus.values) {
        final mapped = InboxMatchService.mapShipStatusToDeal(s);
        if (mapped != null) {
          expect(allowed, contains(mapped),
              reason: 'Mapping für $s liefert ungültigen Status "$mapped"');
        }
      }
    });
  });

  group('InboxMatchService.computeDealUpdate — Versand-Update auf Bestellt-Deal', () {
    final received = DateTime.utc(2026, 5, 7, 12, 0);

    test('Versandbestätigung mit Tracking auf "Bestellt" → Status + Tracking', () {
      final diff = InboxMatchService.computeDealUpdate(
        currentStatus: 'Bestellt',
        currentTracking: null,
        currentArrivalDate: null,
        parsedTracking: '1Z999AA10123456784',
        parsedShipStatus: SuggestionShipStatus.shipped,
        mailReceivedAt: received,
      );
      expect(diff.updates['status'], 'Unterwegs');
      expect(diff.updates['tracking'], '1Z999AA10123456784');
      expect(diff.updates.containsKey('arrival_date'), isFalse);
      expect(diff.changes, hasLength(2));
    });

    test('Versand-Mail OHNE Tracking trotzdem Status-Upgrade', () {
      final diff = InboxMatchService.computeDealUpdate(
        currentStatus: 'Bestellt',
        currentTracking: null,
        currentArrivalDate: null,
        parsedShipStatus: SuggestionShipStatus.shipped,
        mailReceivedAt: received,
      );
      expect(diff.updates['status'], 'Unterwegs');
      expect(diff.updates.containsKey('tracking'), isFalse);
    });

    test('Tracking wird NICHT überschrieben wenn Deal bereits eines hat', () {
      final diff = InboxMatchService.computeDealUpdate(
        currentStatus: 'Bestellt',
        currentTracking: 'OLD123',
        currentArrivalDate: null,
        parsedTracking: 'NEW456',
        parsedShipStatus: SuggestionShipStatus.shipped,
        mailReceivedAt: received,
      );
      expect(diff.updates.containsKey('tracking'), isFalse,
          reason: 'User-gepflegtes Tracking darf nicht stillschweigend ersetzt werden');
      expect(diff.updates['status'], 'Unterwegs');
    });
  });

  group('InboxMatchService.computeDealUpdate — Forward-Only-Status', () {
    test('Versand-Mail auf "Angekommen" macht KEIN Downgrade', () {
      final diff = InboxMatchService.computeDealUpdate(
        currentStatus: 'Angekommen',
        currentTracking: 'X',
        currentArrivalDate: DateTime.utc(2026, 5, 1),
        parsedShipStatus: SuggestionShipStatus.shipped,
      );
      expect(diff.updates.containsKey('status'), isFalse);
      expect(diff.isEmpty, isTrue);
    });

    test('Bestellbestätigung (ordered) auf "Unterwegs" → kein Update', () {
      final diff = InboxMatchService.computeDealUpdate(
        currentStatus: 'Unterwegs',
        currentTracking: 'X',
        currentArrivalDate: null,
        parsedShipStatus: SuggestionShipStatus.ordered,
      );
      expect(diff.isEmpty, isTrue);
    });

    test('Lieferung-Mail upgraded "Unterwegs" → "Angekommen"', () {
      final diff = InboxMatchService.computeDealUpdate(
        currentStatus: 'Unterwegs',
        currentTracking: 'X',
        currentArrivalDate: null,
        parsedShipStatus: SuggestionShipStatus.delivered,
        mailReceivedAt: DateTime.utc(2026, 5, 7),
      );
      expect(diff.updates['status'], 'Angekommen');
      expect(diff.updates['arrival_date'], '2026-05-07T00:00:00.000Z');
    });

    test('Storno-Mail upgraded auch von "Bestellt" auf "Done"', () {
      final diff = InboxMatchService.computeDealUpdate(
        currentStatus: 'Bestellt',
        currentTracking: null,
        currentArrivalDate: null,
        parsedShipStatus: SuggestionShipStatus.cancelled,
      );
      expect(diff.updates['status'], 'Done');
    });
  });

  group('InboxMatchService.computeDealUpdate — arrival_date-Fallback', () {
    test('delivered ohne ETA → mailReceivedAt als arrival_date', () {
      final received = DateTime.utc(2026, 5, 7, 8, 30);
      final diff = InboxMatchService.computeDealUpdate(
        currentStatus: 'Unterwegs',
        currentTracking: 'X',
        currentArrivalDate: null,
        parsedShipStatus: SuggestionShipStatus.delivered,
        mailReceivedAt: received,
      );
      expect(diff.updates['arrival_date'], received.toIso8601String());
    });

    test('Adapter-ETA hat Vorrang vor mailReceivedAt', () {
      final eta = DateTime.utc(2026, 5, 8);
      final received = DateTime.utc(2026, 5, 7);
      final diff = InboxMatchService.computeDealUpdate(
        currentStatus: 'Unterwegs',
        currentTracking: 'X',
        currentArrivalDate: null,
        parsedEta: eta,
        parsedShipStatus: SuggestionShipStatus.delivered,
        mailReceivedAt: received,
      );
      expect(diff.updates['arrival_date'], eta.toIso8601String());
    });

    test('arrival_date wird NICHT überschrieben', () {
      final diff = InboxMatchService.computeDealUpdate(
        currentStatus: 'Unterwegs',
        currentTracking: 'X',
        currentArrivalDate: DateTime.utc(2026, 5, 1),
        parsedEta: DateTime.utc(2026, 5, 8),
        parsedShipStatus: SuggestionShipStatus.delivered,
      );
      expect(diff.updates.containsKey('arrival_date'), isFalse);
      expect(diff.updates['status'], 'Angekommen');
    });

    test('shipped ohne ETA → kein arrival_date geschrieben', () {
      final diff = InboxMatchService.computeDealUpdate(
        currentStatus: 'Bestellt',
        currentTracking: null,
        currentArrivalDate: null,
        parsedTracking: 'TBA123456789012',
        parsedShipStatus: SuggestionShipStatus.shipped,
        mailReceivedAt: DateTime.utc(2026, 5, 7),
      );
      expect(diff.updates.containsKey('arrival_date'), isFalse);
    });
  });

  group('InboxMatchService.computeDealUpdate — Idempotenz', () {
    test('zweite identische Mail produziert leeren Diff', () {
      // Erster Lauf: Status + Tracking werden gesetzt.
      final first = InboxMatchService.computeDealUpdate(
        currentStatus: 'Bestellt',
        currentTracking: null,
        currentArrivalDate: null,
        parsedTracking: 'JJD1234567890',
        parsedShipStatus: SuggestionShipStatus.shipped,
      );
      expect(first.updates.length, 2);

      // Zweiter Lauf: Deal hat jetzt die Werte, dieselbe Mail kommt nochmal —
      // nichts mehr zu schreiben.
      final second = InboxMatchService.computeDealUpdate(
        currentStatus: 'Unterwegs',
        currentTracking: 'JJD1234567890',
        currentArrivalDate: null,
        parsedTracking: 'JJD1234567890',
        parsedShipStatus: SuggestionShipStatus.shipped,
      );
      expect(second.isEmpty, isTrue);
    });
  });
}
