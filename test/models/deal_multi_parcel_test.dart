// Multi-Parcel (2026-06-12): Deal.trackings[] — Serialisierungs-Round-Trips
// (Supabase + Backup-JSON), secondaryTrackings-Getter und copyWith.

import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/deal.dart';

Deal _deal({String? tracking, List<String> trackings = const []}) => Deal(
      id: 1,
      product: 'Testprodukt',
      quantity: 2,
      isDropship: false,
      shop: 'Amazon-DE',
      orderDate: DateTime.utc(2026, 6, 1),
      tracking: tracking,
      trackings: trackings,
    );

void main() {
  group('Deal.trackings Serialisierung', () {
    test('fromSupabase liest trackings-Array', () {
      final deal = Deal.fromSupabase({
        'id': 7,
        'product': 'P',
        'quantity': 1,
        'is_dropship': false,
        'shop': 'S',
        'order_date': '2026-06-01T00:00:00.000Z',
        'tracking': 'A1',
        'trackings': ['A1', 'B2'],
      });
      expect(deal.tracking, 'A1');
      expect(deal.trackings, ['A1', 'B2']);
    });

    test('fromSupabase: Legacy-Row ohne trackings → leere Liste', () {
      final deal = Deal.fromSupabase({
        'id': 7,
        'product': 'P',
        'quantity': 1,
        'is_dropship': false,
        'shop': 'S',
        'order_date': '2026-06-01T00:00:00.000Z',
        'tracking': 'A1',
      });
      expect(deal.trackings, isEmpty);
      expect(deal.secondaryTrackings, isEmpty);
    });

    test('toSupabaseInsert: leere Liste wird als null geschrieben', () {
      expect(_deal(tracking: 'A1').toSupabaseInsert()['trackings'], isNull);
      expect(
        _deal(tracking: 'A1', trackings: ['A1', 'B2'])
            .toSupabaseInsert()['trackings'],
        ['A1', 'B2'],
      );
    });

    test('Backup-JSON Round-Trip erhält trackings', () {
      final deal = _deal(tracking: 'A1', trackings: ['A1', 'B2', 'C3']);
      final restored = Deal.fromJson(deal.toJson());
      expect(restored.trackings, ['A1', 'B2', 'C3']);
    });
  });

  group('secondaryTrackings', () {
    test('filtert Primary und Leereinträge heraus', () {
      final deal = _deal(tracking: 'A1', trackings: ['A1', 'B2', ' ', 'C3']);
      expect(deal.secondaryTrackings, ['B2', 'C3']);
    });

    test('Single-Parcel-Deal hat keine Sekundären', () {
      expect(
          _deal(tracking: 'A1', trackings: ['A1']).secondaryTrackings, isEmpty);
    });
  });

  group('copyWith', () {
    test('trackings ersetzbar und ohne Angabe stabil', () {
      final deal = _deal(tracking: 'A1', trackings: ['A1', 'B2']);
      expect(deal.copyWith(trackings: ['A1']).trackings, ['A1']);
      expect(deal.copyWith(status: 'Unterwegs').trackings, ['A1', 'B2']);
    });
  });
}
