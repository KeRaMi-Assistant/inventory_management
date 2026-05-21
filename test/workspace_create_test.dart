import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_management/services/workspace_service.dart';

void main() {
  group('WorkspaceLimitException', () {
    test('toString formats hint', () {
      const e = WorkspaceLimitException(hint: 'plan=free limit=1 count=1');
      expect(e.toString(), contains('plan=free'));
    });

    test('toString without hint has fallback', () {
      const e = WorkspaceLimitException();
      expect(e.toString(), contains('limit reached'));
    });
  });
}
