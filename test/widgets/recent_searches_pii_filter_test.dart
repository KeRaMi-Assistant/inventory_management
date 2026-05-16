import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inventory_management/providers/app_preferences_provider.dart';

// ─── Helper ──────────────────────────────────────────────────────────────────

/// Creates a fresh provider with empty SharedPreferences.
Future<AppPreferencesProvider> _freshProvider() async {
  SharedPreferences.setMockInitialValues({});
  final p = AppPreferencesProvider();
  await p.load();
  return p;
}

// ─────────────────────────────────────────────────────────────────────────────
void main() {
  group('AppPreferencesProvider — Recent Searches PII filter', () {
    // 1. E-mail is filtered
    test('e-mail input is NOT persisted', () async {
      final p = await _freshProvider();
      await p.addRecentSearch('foo@bar.com');
      expect(p.recentSearches, isEmpty);
    });

    // 2. 8+-digit string (tracking/phone) is filtered
    test('tracking/phone with 8+ digits is NOT persisted', () async {
      final p = await _freshProvider();
      await p.addRecentSearch('DE12345678');
      expect(p.recentSearches, isEmpty);
    });

    // 3. Alphanumeric tracking code (10+ uppercase chars) is filtered
    test('alphanumeric tracking code (10+ UPPER) is NOT persisted', () async {
      final p = await _freshProvider();
      await p.addRecentSearch('JJD012345678901');
      expect(p.recentSearches, isEmpty);
    });

    // 4. Normal query is persisted
    test('normal query "laptop" IS persisted', () async {
      final p = await _freshProvider();
      await p.addRecentSearch('laptop');
      expect(p.recentSearches, ['laptop']);
    });

    // 5. Max-5 FIFO: 6th entry evicts the oldest
    test('max-5 FIFO — 6th entry evicts oldest', () async {
      final p = await _freshProvider();
      for (final q in ['a', 'b', 'c', 'd', 'e']) {
        await p.addRecentSearch(q);
      }
      // At this point: ['e', 'd', 'c', 'b', 'a']
      await p.addRecentSearch('f');
      // 'a' (oldest) must be gone; 'f' must be first
      expect(p.recentSearches.length, 5);
      expect(p.recentSearches.first, 'f');
      expect(p.recentSearches, isNot(contains('a')));
    });

    // 6. clearRecentSearches empties the list (simulates signOut hook)
    test('clearRecentSearches empties the list', () async {
      final p = await _freshProvider();
      await p.addRecentSearch('laptop');
      await p.addRecentSearch('monitor');
      await p.clearRecentSearches();
      expect(p.recentSearches, isEmpty);
    });

    // 7. In-memory cache: recentSearches returns immediately from _recentSearches
    //    — no second SharedPreferences read needed.
    //    We verify by checking the in-memory list is consistent without
    //    creating a second provider instance (which would read from prefs).
    test('in-memory cache is consistent across multiple reads', () async {
      final p = await _freshProvider();
      await p.addRecentSearch('keyboard');
      // Read twice — should return the same unmodifiable list content.
      final first = p.recentSearches;
      final second = p.recentSearches;
      expect(first, equals(second));
      expect(second, ['keyboard']);
    });
  });

  group('AppPreferencesProvider — isPII static helper', () {
    test('returns true for e-mail', () {
      expect(AppPreferencesProvider.isPII('user@example.com'), isTrue);
    });

    test('returns true for 8-digit number', () {
      expect(AppPreferencesProvider.isPII('12345678'), isTrue);
    });

    test('returns true for alphanumeric tracking (10+ uppercase)', () {
      expect(AppPreferencesProvider.isPII('JJD0123456789'), isTrue);
    });

    test('returns false for short product query', () {
      expect(AppPreferencesProvider.isPII('laptop'), isFalse);
    });

    test('returns false for mixed-case query under 10 chars', () {
      expect(AppPreferencesProvider.isPII('Monitor'), isFalse);
    });
  });
}
