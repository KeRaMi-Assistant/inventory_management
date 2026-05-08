import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/main.dart';

void main() {
  group('publicProfileHandleFromUri', () {
    test('parses path-strategy URL', () {
      final uri = Uri.parse('https://app.example.com/u/mein-laden');
      expect(publicProfileHandleFromUri(uri), 'mein-laden');
    });

    test('parses hash-strategy URL', () {
      final uri = Uri.parse('https://app.example.com/#/u/mein-laden');
      expect(publicProfileHandleFromUri(uri), 'mein-laden');
    });

    test('rejects too-short handle', () {
      final uri = Uri.parse('https://app.example.com/u/ab');
      expect(publicProfileHandleFromUri(uri), isNull);
    });

    test('rejects uppercase / invalid chars', () {
      expect(
        publicProfileHandleFromUri(Uri.parse('https://x/u/MyShop')),
        isNull,
      );
      expect(
        publicProfileHandleFromUri(Uri.parse('https://x/u/foo_bar')),
        isNull,
      );
    });

    test('rejects leading/trailing dash', () {
      expect(
        publicProfileHandleFromUri(Uri.parse('https://x/u/-foo')),
        isNull,
      );
      expect(
        publicProfileHandleFromUri(Uri.parse('https://x/u/foo-')),
        isNull,
      );
    });

    test('returns null for non-public path', () {
      expect(
        publicProfileHandleFromUri(Uri.parse('https://x/inventory')),
        isNull,
      );
    });
  });
}
