import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/screens/dashboard_screen.dart';

void main() {
  group('DashboardScreen.shouldShowSkeleton', () {
    // ── initial load: no data yet, spinner active → Skeleton ON ──────────
    test('returns true when isLoading=true and hasData=false', () {
      expect(
        DashboardScreen.shouldShowSkeleton(isLoading: true, hasData: false),
        isTrue,
      );
    });

    // ── race-condition: re-load with existing data → Skeleton OFF ─────────
    test('returns false when isLoading=true but hasData=true (re-load)', () {
      expect(
        DashboardScreen.shouldShowSkeleton(isLoading: true, hasData: true),
        isFalse,
      );
    });

    // ── idle with data: normal render → Skeleton OFF ─────────────────────
    test('returns false when isLoading=false and hasData=true', () {
      expect(
        DashboardScreen.shouldShowSkeleton(isLoading: false, hasData: true),
        isFalse,
      );
    });

    // ── idle without data: empty-state card → Skeleton OFF ───────────────
    test('returns false when isLoading=false and hasData=false', () {
      expect(
        DashboardScreen.shouldShowSkeleton(isLoading: false, hasData: false),
        isFalse,
      );
    });
  });
}
