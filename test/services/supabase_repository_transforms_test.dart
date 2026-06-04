// Tests für reine Transform-Helfer in supabase_repository.dart und
// zugehörige Model-Factories (Deal.fromSupabase, Deal.fromJson,
// LiveTrackingStatus.fromString, TrackingConfidence.fromString,
// Deal._readDropship, Deal._readReceipt).
//
// Kein Live-Supabase, kein HTTP — reine Daten-Logik.

import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/deal.dart';
import 'package:inventory_management/models/live_tracking_status.dart';
import 'package:inventory_management/models/tracking_confidence.dart';

// ── Hilfsfunktion: minimaler gültiger Supabase-Row für einen Deal ────────────

Map<String, dynamic> _baseRow({
  int id = 1,
  String product = 'Testprodukt',
  int quantity = 2,
  dynamic isDropship = false,
  dynamic shippingType,
  String shop = 'Amazon',
  String orderDate = '2026-01-15T10:00:00.000Z',
  dynamic hasReceipt = false,
  dynamic beleg,
  String? tracking,
  String? arrivalDate,
  String? shippedAt,
  String status = 'Bestellt',
  String currency = 'EUR',
  dynamic attachmentPaths,
  String? trackingConfidence,
  bool? trackingNeedsReview,
  String? carrier,
  String? liveStatus,
  String? liveStatusLastEvent,
  String? liveStatusUpdatedAt,
}) =>
    {
      'id': id,
      'product': product,
      'quantity': quantity,
      'is_dropship': isDropship,
      'shipping_type': shippingType,
      'shop': shop,
      'order_date': orderDate,
      'has_receipt': hasReceipt,
      'beleg': beleg,
      'tracking': tracking,
      'arrival_date': arrivalDate,
      'shipped_at': shippedAt,
      'status': status,
      'currency': currency,
      'attachment_paths': attachmentPaths,
      'tracking_confidence': trackingConfidence,
      'tracking_needs_review': trackingNeedsReview,
      'carrier': carrier,
      'live_status': liveStatus,
      'live_status_last_event': liveStatusLastEvent,
      'live_status_updated_at': liveStatusUpdatedAt,
    };

void main() {
  // ── Deal.fromSupabase: Basis-Mapping ─────────────────────────────────────

  group('Deal.fromSupabase — Basis-Mapping', () {
    test('parst Pflichtfelder korrekt', () {
      final row = _baseRow(id: 42, product: 'Laptop', quantity: 3);
      final deal = Deal.fromSupabase(row);

      expect(deal.id, equals(42));
      expect(deal.product, equals('Laptop'));
      expect(deal.quantity, equals(3));
      expect(deal.shop, equals('Amazon'));
    });

    test('parst orderDate als UTC-DateTime', () {
      final row = _baseRow(orderDate: '2026-03-20T08:30:00.000Z');
      final deal = Deal.fromSupabase(row);

      expect(deal.orderDate, equals(DateTime.utc(2026, 3, 20, 8, 30, 0)));
    });

    test('null-Felder ergeben null im Modell', () {
      final row = _baseRow(
        tracking: null,
        arrivalDate: null,
        shippedAt: null,
        carrier: null,
        liveStatus: null,
        liveStatusLastEvent: null,
        liveStatusUpdatedAt: null,
      );
      final deal = Deal.fromSupabase(row);

      expect(deal.tracking, isNull);
      expect(deal.arrivalDate, isNull);
      expect(deal.shippedAt, isNull);
      expect(deal.carrier, isNull);
      expect(deal.liveStatus, isNull);
      expect(deal.liveStatusLastEvent, isNull);
      expect(deal.liveStatusUpdatedAt, isNull);
    });

    test('fehlendes currency-Feld fällt auf EUR zurück', () {
      final row = _baseRow();
      row.remove('currency');
      final deal = Deal.fromSupabase(row);
      expect(deal.currency, equals('EUR'));
    });

    test('fehlendes status-Feld fällt auf Bestellt zurück', () {
      final row = _baseRow();
      row.remove('status');
      final deal = Deal.fromSupabase(row);
      expect(deal.status, equals('Bestellt'));
    });
  });

  // ── Deal.fromSupabase: _readDropship (Bool + Legacy-String) ─────────────

  group('Deal.fromSupabase — _readDropship', () {
    test('is_dropship=true → isDropship=true', () {
      final deal = Deal.fromSupabase(_baseRow(isDropship: true));
      expect(deal.isDropship, isTrue);
    });

    test('is_dropship=false → isDropship=false', () {
      final deal = Deal.fromSupabase(_baseRow(isDropship: false));
      expect(deal.isDropship, isFalse);
    });

    test('legacy shipping_type="Dropship" → isDropship=true', () {
      final deal = Deal.fromSupabase(
        _baseRow(isDropship: null, shippingType: 'Dropship'),
      );
      expect(deal.isDropship, isTrue);
    });

    test('legacy shipping_type="Reship" → isDropship=false', () {
      final deal = Deal.fromSupabase(
        _baseRow(isDropship: null, shippingType: 'Reship'),
      );
      expect(deal.isDropship, isFalse);
    });

    test('legacy shipping_type case-insensitive', () {
      expect(
        Deal.fromSupabase(_baseRow(isDropship: null, shippingType: 'dropship'))
            .isDropship,
        isTrue,
      );
    });

    test('beide Felder null → isDropship=false (defensiver Default)', () {
      final deal = Deal.fromSupabase(_baseRow(isDropship: null));
      expect(deal.isDropship, isFalse);
    });
  });

  // ── Deal.fromSupabase: _readReceipt (Bool + Legacy-String) ──────────────

  group('Deal.fromSupabase — _readReceipt', () {
    test('has_receipt=true → hasReceipt=true', () {
      final deal = Deal.fromSupabase(_baseRow(hasReceipt: true));
      expect(deal.hasReceipt, isTrue);
    });

    test('has_receipt=false → hasReceipt=false', () {
      final deal = Deal.fromSupabase(_baseRow(hasReceipt: false));
      expect(deal.hasReceipt, isFalse);
    });

    test('legacy beleg="Ja" → hasReceipt=true', () {
      final deal = Deal.fromSupabase(_baseRow(hasReceipt: null, beleg: 'Ja'));
      expect(deal.hasReceipt, isTrue);
    });

    test('legacy beleg="Nein" → hasReceipt=false', () {
      final deal = Deal.fromSupabase(_baseRow(hasReceipt: null, beleg: 'Nein'));
      expect(deal.hasReceipt, isFalse);
    });

    test('legacy beleg case-insensitive', () {
      expect(
        Deal.fromSupabase(_baseRow(hasReceipt: null, beleg: 'ja')).hasReceipt,
        isTrue,
      );
    });

    test('beide Felder null → hasReceipt=false (defensiver Default)', () {
      final deal = Deal.fromSupabase(_baseRow(hasReceipt: null));
      expect(deal.hasReceipt, isFalse);
    });
  });

  // ── Deal.fromSupabase: LiveTrackingStatus-Mapping ───────────────────────

  group('Deal.fromSupabase — LiveTrackingStatus', () {
    test('live_status="in_transit" → LiveTrackingStatus.inTransit', () {
      final deal = Deal.fromSupabase(_baseRow(liveStatus: 'in_transit'));
      expect(deal.liveStatus, equals(LiveTrackingStatus.inTransit));
    });

    test('live_status="out_for_delivery" → LiveTrackingStatus.outForDelivery', () {
      final deal = Deal.fromSupabase(_baseRow(liveStatus: 'out_for_delivery'));
      expect(deal.liveStatus, equals(LiveTrackingStatus.outForDelivery));
    });

    test('live_status="delivered" → LiveTrackingStatus.delivered', () {
      final deal = Deal.fromSupabase(_baseRow(liveStatus: 'delivered'));
      expect(deal.liveStatus, equals(LiveTrackingStatus.delivered));
    });

    test('live_status="pending" → LiveTrackingStatus.pending', () {
      final deal = Deal.fromSupabase(_baseRow(liveStatus: 'pending'));
      expect(deal.liveStatus, equals(LiveTrackingStatus.pending));
    });

    test('live_status="exception" → LiveTrackingStatus.exception', () {
      final deal = Deal.fromSupabase(_baseRow(liveStatus: 'exception'));
      expect(deal.liveStatus, equals(LiveTrackingStatus.exception));
    });

    test('live_status="expired" → LiveTrackingStatus.expired', () {
      final deal = Deal.fromSupabase(_baseRow(liveStatus: 'expired'));
      expect(deal.liveStatus, equals(LiveTrackingStatus.expired));
    });

    test('live_status=null → liveStatus=null', () {
      final deal = Deal.fromSupabase(_baseRow(liveStatus: null));
      expect(deal.liveStatus, isNull);
    });

    test('unknown live_status string → liveStatus=null (defensiv)', () {
      final deal = Deal.fromSupabase(_baseRow(liveStatus: 'totally_unknown'));
      expect(deal.liveStatus, isNull);
    });
  });

  // ── Deal.fromSupabase: TrackingConfidence-Mapping ───────────────────────

  group('Deal.fromSupabase — TrackingConfidence', () {
    test('tracking_confidence="strong" → TrackingConfidence.strong', () {
      final deal = Deal.fromSupabase(_baseRow(trackingConfidence: 'strong'));
      expect(deal.trackingConfidence, equals(TrackingConfidence.strong));
    });

    test('tracking_confidence="manual" → TrackingConfidence.manual', () {
      final deal = Deal.fromSupabase(_baseRow(trackingConfidence: 'manual'));
      expect(deal.trackingConfidence, equals(TrackingConfidence.manual));
    });

    test('tracking_confidence="none" → TrackingConfidence.none', () {
      final deal = Deal.fromSupabase(_baseRow(trackingConfidence: 'none'));
      expect(deal.trackingConfidence, equals(TrackingConfidence.none));
    });

    test('tracking_confidence=null → null (Legacy-Deal)', () {
      final deal = Deal.fromSupabase(_baseRow(trackingConfidence: null));
      expect(deal.trackingConfidence, isNull);
    });

    test('tracking_confidence unbekannter Wert → null', () {
      final deal = Deal.fromSupabase(_baseRow(trackingConfidence: 'weak'));
      expect(deal.trackingConfidence, isNull);
    });
  });

  // ── Deal.fromSupabase: attachment_paths ─────────────────────────────────

  group('Deal.fromSupabase — attachmentPaths', () {
    test('attachment_paths=null → leere Liste', () {
      final deal = Deal.fromSupabase(_baseRow(attachmentPaths: null));
      expect(deal.attachmentPaths, isEmpty);
    });

    test('attachment_paths=[] → leere Liste', () {
      final deal = Deal.fromSupabase(_baseRow(attachmentPaths: <String>[]));
      expect(deal.attachmentPaths, isEmpty);
    });

    test('attachment_paths=[pfad1, pfad2] → korrekte Liste', () {
      final deal = Deal.fromSupabase(
        _baseRow(attachmentPaths: ['a/b.png', 'c/d.pdf']),
      );
      expect(deal.attachmentPaths, equals(['a/b.png', 'c/d.pdf']));
    });
  });

  // ── Deal.fromSupabase: liveStatusUpdatedAt ─────────────────────────────

  group('Deal.fromSupabase — liveStatusUpdatedAt', () {
    test('liveStatusUpdatedAt-ISO → korrekter DateTime', () {
      final deal = Deal.fromSupabase(
        _baseRow(liveStatusUpdatedAt: '2026-05-15T10:00:00.000Z'),
      );
      expect(
        deal.liveStatusUpdatedAt,
        equals(DateTime.utc(2026, 5, 15, 10, 0, 0)),
      );
    });

    test('liveStatusUpdatedAt=null → null', () {
      final deal = Deal.fromSupabase(_baseRow(liveStatusUpdatedAt: null));
      expect(deal.liveStatusUpdatedAt, isNull);
    });
  });

  // ── Deal JSON round-trip (fromJson/toJson) ───────────────────────────────

  group('Deal JSON round-trip', () {
    test('Deal.fromJson → .toJson ist idempotent für Basis-Felder', () {
      final original = Deal(
        id: 7,
        product: 'Notebook',
        quantity: 1,
        isDropship: false,
        shop: 'Dell',
        orderDate: DateTime.utc(2026, 2, 10),
        ekNetto: 800.0,
        vk: 1200.0,
        status: 'Unterwegs',
        tracking: '123456789012',
        carrier: 'dhl',
        liveStatus: LiveTrackingStatus.inTransit,
        liveStatusLastEvent: 'In Zustellung',
        liveStatusUpdatedAt: DateTime.utc(2026, 2, 11, 9, 0),
        trackingConfidence: TrackingConfidence.strong,
        trackingNeedsReview: false,
      );

      final json = original.toJson();
      final restored = Deal.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.product, equals(original.product));
      expect(restored.tracking, equals(original.tracking));
      expect(restored.liveStatus, equals(original.liveStatus));
      expect(restored.liveStatusLastEvent, equals(original.liveStatusLastEvent));
      expect(restored.carrier, equals(original.carrier));
      expect(restored.trackingConfidence, equals(original.trackingConfidence));
      expect(restored.trackingNeedsReview, equals(original.trackingNeedsReview));
    });

    test('Deal.fromJson: isDropship kompatibel mit Legacy-shippingType', () {
      // Altes Backup-JSON mit shippingType statt isDropship.
      final legacyJson = {
        'id': 5,
        'product': 'Router',
        'quantity': 1,
        'shippingType': 'Dropship',
        'shop': 'Amazon',
        'orderDate': '2025-06-01T00:00:00.000Z',
        'status': 'Bestellt',
        'hasReceipt': false,
        'currency': 'EUR',
        'inventoryItemIds': <String>[],
        'attachmentPaths': <String>[],
      };

      final deal = Deal.fromJson(legacyJson);
      expect(deal.isDropship, isTrue);
    });
  });

  // ── LiveTrackingStatus standalone ────────────────────────────────────────

  group('LiveTrackingStatus.fromString', () {
    final cases = {
      'pending': LiveTrackingStatus.pending,
      'in_transit': LiveTrackingStatus.inTransit,
      'out_for_delivery': LiveTrackingStatus.outForDelivery,
      'delivered': LiveTrackingStatus.delivered,
      'exception': LiveTrackingStatus.exception,
      'expired': LiveTrackingStatus.expired,
    };

    for (final entry in cases.entries) {
      test('fromString("${entry.key}") → ${entry.value.name}', () {
        expect(LiveTrackingStatus.fromString(entry.key), equals(entry.value));
      });
    }

    test('fromString(null) → null', () {
      expect(LiveTrackingStatus.fromString(null), isNull);
    });

    test('fromString("unknown_value") → null', () {
      expect(LiveTrackingStatus.fromString('unknown_value'), isNull);
    });

    test('toJson() liefert korrekten snake_case-String', () {
      expect(LiveTrackingStatus.inTransit.toJson(), equals('in_transit'));
      expect(LiveTrackingStatus.outForDelivery.toJson(), equals('out_for_delivery'));
      expect(LiveTrackingStatus.delivered.toJson(), equals('delivered'));
    });

    test('fromString → toJson Round-trip ist idempotent', () {
      for (final key in cases.keys) {
        final status = LiveTrackingStatus.fromString(key)!;
        expect(status.toJson(), equals(key));
      }
    });
  });

  // ── TrackingConfidence standalone ─────────────────────────────────────────

  group('TrackingConfidence.fromString', () {
    test('"strong" → TrackingConfidence.strong', () {
      expect(TrackingConfidence.fromString('strong'), equals(TrackingConfidence.strong));
    });

    test('"manual" → TrackingConfidence.manual', () {
      expect(TrackingConfidence.fromString('manual'), equals(TrackingConfidence.manual));
    });

    test('"none" → TrackingConfidence.none', () {
      expect(TrackingConfidence.fromString('none'), equals(TrackingConfidence.none));
    });

    test('null → null', () {
      expect(TrackingConfidence.fromString(null), isNull);
    });

    test('unknown string → null', () {
      expect(TrackingConfidence.fromString('weak'), isNull);
      expect(TrackingConfidence.fromString(''), isNull);
    });

    test('toJson() liefert name-String', () {
      expect(TrackingConfidence.strong.toJson(), equals('strong'));
      expect(TrackingConfidence.manual.toJson(), equals('manual'));
      expect(TrackingConfidence.none.toJson(), equals('none'));
    });
  });
}
