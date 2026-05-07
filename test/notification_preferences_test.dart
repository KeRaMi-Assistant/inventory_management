import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/services/push_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Default constructor
  group('NotificationPreferences defaults', () {
    test('all default values are correct', () {
      const prefs = NotificationPreferences();
      expect(prefs.mhdWarningEnabled, isTrue);
      expect(prefs.mhdWarningDays, 14);
      expect(prefs.deliveryEnabled, isTrue);
      expect(prefs.paymentEnabled, isTrue);
      expect(prefs.paymentOverdueDays, 7);
    });
  });

  // fromRow happy path
  group('NotificationPreferences.fromRow', () {
    test('happy path with all fields set', () {
      final row = {
        'mhd_warning_enabled': false,
        'mhd_warning_days': 30,
        'delivery_enabled': false,
        'payment_enabled': false,
        'payment_overdue_days': 14,
      };
      final prefs = NotificationPreferences.fromRow(row);
      expect(prefs.mhdWarningEnabled, isFalse);
      expect(prefs.mhdWarningDays, 30);
      expect(prefs.deliveryEnabled, isFalse);
      expect(prefs.paymentEnabled, isFalse);
      expect(prefs.paymentOverdueDays, 14);
    });

    test('missing fields fall back to defaults', () {
      final prefs = NotificationPreferences.fromRow({});
      expect(prefs.mhdWarningEnabled, isTrue);
      expect(prefs.mhdWarningDays, 14);
      expect(prefs.deliveryEnabled, isTrue);
      expect(prefs.paymentEnabled, isTrue);
      expect(prefs.paymentOverdueDays, 7);
    });

    test('null fields fall back to defaults', () {
      final row = {
        'mhd_warning_enabled': null,
        'mhd_warning_days': null,
        'delivery_enabled': null,
        'payment_enabled': null,
        'payment_overdue_days': null,
      };
      final prefs = NotificationPreferences.fromRow(row);
      expect(prefs.mhdWarningEnabled, isTrue);
      expect(prefs.mhdWarningDays, 14);
      expect(prefs.deliveryEnabled, isTrue);
      expect(prefs.paymentEnabled, isTrue);
      expect(prefs.paymentOverdueDays, 7);
    });
  });

  // toUpsert
  group('NotificationPreferences.toUpsert', () {
    test('includes user_id, all fields, and updated_at', () {
      const prefs = NotificationPreferences(
        mhdWarningEnabled: true,
        mhdWarningDays: 21,
        deliveryEnabled: false,
        paymentEnabled: true,
        paymentOverdueDays: 10,
      );
      final map = prefs.toUpsert('user-123');
      expect(map['user_id'], 'user-123');
      expect(map['mhd_warning_enabled'], isTrue);
      expect(map['mhd_warning_days'], 21);
      expect(map['delivery_enabled'], isFalse);
      expect(map['payment_enabled'], isTrue);
      expect(map['payment_overdue_days'], 10);
      expect(map.containsKey('updated_at'), isTrue);
    });
  });

  // copyWith
  group('NotificationPreferences.copyWith', () {
    test('changes only specified fields, leaves others unchanged', () {
      const original = NotificationPreferences(
        mhdWarningEnabled: true,
        mhdWarningDays: 14,
        deliveryEnabled: true,
        paymentEnabled: true,
        paymentOverdueDays: 7,
      );
      final updated = original.copyWith(mhdWarningDays: 30, deliveryEnabled: false);
      expect(updated.mhdWarningEnabled, isTrue);
      expect(updated.mhdWarningDays, 30);
      expect(updated.deliveryEnabled, isFalse);
      expect(updated.paymentEnabled, isTrue);
      expect(updated.paymentOverdueDays, 7);
    });

    test('copyWith with no args returns equivalent object', () {
      const original = NotificationPreferences(
        mhdWarningEnabled: false,
        mhdWarningDays: 21,
        deliveryEnabled: false,
        paymentEnabled: false,
        paymentOverdueDays: 3,
      );
      final copy = original.copyWith();
      expect(copy.mhdWarningEnabled, original.mhdWarningEnabled);
      expect(copy.mhdWarningDays, original.mhdWarningDays);
      expect(copy.deliveryEnabled, original.deliveryEnabled);
      expect(copy.paymentEnabled, original.paymentEnabled);
      expect(copy.paymentOverdueDays, original.paymentOverdueDays);
    });
  });
}
