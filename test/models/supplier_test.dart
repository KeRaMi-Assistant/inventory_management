import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/models/supplier.dart';

void main() {
  // ── Hilfsfunktionen ────────────────────────────────────────────────────────

  Supplier makeBase() => const Supplier(
        id: 'sup-id-1',
        name: 'Testamax GmbH',
        contactName: 'Max Mustermann',
        email: 'kontakt@testamax.de',
        phone: '+49 30 123456',
        website: 'https://testamax.de',
        note: 'Notiz',
        active: true,
        addressStreet: 'Musterstraße 1',
        addressZip: '10115',
        addressCity: 'Berlin',
        addressCountry: 'DE',
        vatId: 'DE123456789',
        customerNumber: 'KD-001',
        paymentTermsDays: 30,
        leadTimeDays: 5,
        minOrderValue: 100.0,
      );

  // ── Basis-Felder (existierende vor B1) ────────────────────────────────────

  group('Supplier Supabase Round-Trip – Basis-Felder', () {
    test('fromSupabase liest alle Basis-Felder korrekt', () {
      final row = {
        'id': 'sup-id-1',
        'name': 'Testamax GmbH',
        'contact_name': 'Max Mustermann',
        'email': 'kontakt@testamax.de',
        'phone': '+49 30 123456',
        'website': 'https://testamax.de',
        'note': 'Notiz',
        'active': true,
        // neue Felder alle null
        'address_street': null,
        'address_zip': null,
        'address_city': null,
        'address_country': null,
        'vat_id': null,
        'customer_number': null,
        'payment_terms_days': null,
        'lead_time_days': null,
        'min_order_value': null,
      };
      final supplier = Supplier.fromSupabase(row);
      expect(supplier.id, equals('sup-id-1'));
      expect(supplier.name, equals('Testamax GmbH'));
      expect(supplier.contactName, equals('Max Mustermann'));
      expect(supplier.email, equals('kontakt@testamax.de'));
      expect(supplier.active, isTrue);
      expect(supplier.addressStreet, isNull);
      expect(supplier.paymentTermsDays, isNull);
    });

    test('toSupabaseInsert enthält alle Basis-Felder', () {
      final supplier = const Supplier(id: 'sup-id-2', name: 'Minimal GmbH');
      final row = supplier.toSupabaseInsert();
      expect(row['id'], equals('sup-id-2'));
      expect(row['name'], equals('Minimal GmbH'));
      expect(row['active'], isTrue);
    });
  });

  // ── Neue Felder (B1 migration) ─────────────────────────────────────────────

  group('Supplier Supabase Round-Trip – neue Kreditoren-Felder', () {
    test('toSupabaseInsert enthält alle 9 neuen Felder (non-null)', () {
      final supplier = makeBase();
      final row = supplier.toSupabaseInsert();

      expect(row['address_street'], equals('Musterstraße 1'));
      expect(row['address_zip'], equals('10115'));
      expect(row['address_city'], equals('Berlin'));
      expect(row['address_country'], equals('DE'));
      expect(row['vat_id'], equals('DE123456789'));
      expect(row['customer_number'], equals('KD-001'));
      expect(row['payment_terms_days'], equals(30));
      expect(row['lead_time_days'], equals(5));
      expect(row['min_order_value'], equals(100.0));
    });

    test('toSupabaseInsert enthält neue Felder als null wenn nicht gesetzt', () {
      final supplier = const Supplier(id: 'sup-id-3', name: 'Kein Extended');
      final row = supplier.toSupabaseInsert();

      expect(row.containsKey('address_street'), isTrue);
      expect(row['address_street'], isNull);
      expect(row.containsKey('payment_terms_days'), isTrue);
      expect(row['payment_terms_days'], isNull);
      expect(row.containsKey('min_order_value'), isTrue);
      expect(row['min_order_value'], isNull);
    });

    test('fromSupabase liest alle 9 neuen Felder korrekt', () {
      final row = {
        'id': 'sup-id-4',
        'name': 'Full GmbH',
        'contact_name': null,
        'email': null,
        'phone': null,
        'website': null,
        'note': null,
        'active': true,
        'address_street': 'Hauptstr. 5',
        'address_zip': '20095',
        'address_city': 'Hamburg',
        'address_country': 'DE',
        'vat_id': 'DE987654321',
        'customer_number': 'KD-002',
        'payment_terms_days': 14,
        'lead_time_days': 7,
        'min_order_value': 250.50,
      };
      final supplier = Supplier.fromSupabase(row);
      expect(supplier.addressStreet, equals('Hauptstr. 5'));
      expect(supplier.addressZip, equals('20095'));
      expect(supplier.addressCity, equals('Hamburg'));
      expect(supplier.addressCountry, equals('DE'));
      expect(supplier.vatId, equals('DE987654321'));
      expect(supplier.customerNumber, equals('KD-002'));
      expect(supplier.paymentTermsDays, equals(14));
      expect(supplier.leadTimeDays, equals(7));
      expect(supplier.minOrderValue, equals(250.50));
    });

    test('fromSupabase: payment_terms_days als num aus DB korrekt zu int', () {
      final row = {
        'id': 'sup-id-5',
        'name': 'NumTest',
        'contact_name': null,
        'email': null,
        'phone': null,
        'website': null,
        'note': null,
        'active': true,
        'address_street': null,
        'address_zip': null,
        'address_city': null,
        'address_country': null,
        'vat_id': null,
        'customer_number': null,
        'payment_terms_days': 30, // int aus Postgres
        'lead_time_days': 3,
        'min_order_value': null,
      };
      final supplier = Supplier.fromSupabase(row);
      expect(supplier.paymentTermsDays, equals(30));
      expect(supplier.paymentTermsDays, isA<int>());
      expect(supplier.leadTimeDays, equals(3));
      expect(supplier.leadTimeDays, isA<int>());
    });

    test('fromSupabase: min_order_value als num aus DB korrekt zu double', () {
      final row = {
        'id': 'sup-id-6',
        'name': 'NumTest2',
        'contact_name': null,
        'email': null,
        'phone': null,
        'website': null,
        'note': null,
        'active': true,
        'address_street': null,
        'address_zip': null,
        'address_city': null,
        'address_country': null,
        'vat_id': null,
        'customer_number': null,
        'payment_terms_days': null,
        'lead_time_days': null,
        'min_order_value': 75, // int aus DB (numeric(12,2) kann als int kommen)
      };
      final supplier = Supplier.fromSupabase(row);
      expect(supplier.minOrderValue, equals(75.0));
      expect(supplier.minOrderValue, isA<double>());
    });

    test('Round-Trip: toSupabaseInsert → fromSupabase für alle neuen Felder', () {
      final original = makeBase();
      final row = original.toSupabaseInsert()
        ..['id'] = original.id
        ..['contact_name'] = original.contactName
        ..['email'] = original.email
        ..['phone'] = original.phone
        ..['website'] = original.website
        ..['note'] = original.note;
      // fromSupabase nutzt snake_case-Keys, die toSupabaseInsert setzt
      final restored = Supplier.fromSupabase(row);

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.addressStreet, equals(original.addressStreet));
      expect(restored.addressZip, equals(original.addressZip));
      expect(restored.addressCity, equals(original.addressCity));
      expect(restored.addressCountry, equals(original.addressCountry));
      expect(restored.vatId, equals(original.vatId));
      expect(restored.customerNumber, equals(original.customerNumber));
      expect(restored.paymentTermsDays, equals(original.paymentTermsDays));
      expect(restored.leadTimeDays, equals(original.leadTimeDays));
      expect(restored.minOrderValue, equals(original.minOrderValue));
    });
  });

  // ── copyWith – neue Felder ─────────────────────────────────────────────────

  group('Supplier.copyWith – neue Kreditoren-Felder', () {
    test('copyWith ohne Argumente lässt neue Felder unverändert', () {
      final original = makeBase();
      final copy = original.copyWith();
      expect(copy.addressStreet, equals(original.addressStreet));
      expect(copy.addressZip, equals(original.addressZip));
      expect(copy.addressCity, equals(original.addressCity));
      expect(copy.addressCountry, equals(original.addressCountry));
      expect(copy.vatId, equals(original.vatId));
      expect(copy.customerNumber, equals(original.customerNumber));
      expect(copy.paymentTermsDays, equals(original.paymentTermsDays));
      expect(copy.leadTimeDays, equals(original.leadTimeDays));
      expect(copy.minOrderValue, equals(original.minOrderValue));
    });

    test('copyWith ändert addressStreet', () {
      final original = makeBase();
      final copy = original.copyWith(addressStreet: 'Neue Str. 99');
      expect(copy.addressStreet, equals('Neue Str. 99'));
      expect(original.addressStreet, equals('Musterstraße 1'));
    });

    test('copyWith setzt addressStreet explizit auf null (Sentinel)', () {
      final original = makeBase();
      final copy = original.copyWith(addressStreet: null);
      expect(copy.addressStreet, isNull);
    });

    test('copyWith ändert paymentTermsDays', () {
      final original = makeBase();
      final copy = original.copyWith(paymentTermsDays: 60);
      expect(copy.paymentTermsDays, equals(60));
    });

    test('copyWith setzt paymentTermsDays explizit auf null (Sentinel)', () {
      final original = makeBase();
      final copy = original.copyWith(paymentTermsDays: null);
      expect(copy.paymentTermsDays, isNull);
    });

    test('copyWith ändert minOrderValue', () {
      final original = makeBase();
      final copy = original.copyWith(minOrderValue: 500.0);
      expect(copy.minOrderValue, equals(500.0));
    });

    test('copyWith setzt minOrderValue explizit auf null (Sentinel)', () {
      final original = makeBase();
      final copy = original.copyWith(minOrderValue: null);
      expect(copy.minOrderValue, isNull);
    });

    test('copyWith lässt neue Felder unverändert wenn nur name geändert wird',
        () {
      final original = makeBase();
      final copy = original.copyWith(name: 'Anderer Name');
      expect(copy.name, equals('Anderer Name'));
      expect(copy.vatId, equals(original.vatId));
      expect(copy.leadTimeDays, equals(original.leadTimeDays));
    });
  });

  // ── Bestehende Felder bleiben funktionsfähig ───────────────────────────────

  group('Supplier Regressions-Schutz – Basis-Felder nach B1', () {
    test('Konstruktor ohne neue Felder kompiliert und active default ist true',
        () {
      const supplier = Supplier(id: 'x', name: 'Y');
      expect(supplier.active, isTrue);
      expect(supplier.addressStreet, isNull);
      expect(supplier.minOrderValue, isNull);
    });

    test('copyWith bestehende Basis-Felder weiterhin funktionsfähig', () {
      const original = Supplier(id: 'a', name: 'Alt');
      final copy = original.copyWith(name: 'Neu', active: false);
      expect(copy.name, equals('Neu'));
      expect(copy.active, isFalse);
      expect(copy.id, equals('a'));
    });
  });
}
