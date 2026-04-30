import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:inventory_management/main.dart';
import 'package:inventory_management/providers/filter_provider.dart';
import 'package:inventory_management/providers/inventory_provider.dart';

void main() {
  testWidgets('shows dashboard shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => InventoryProvider()),
          ChangeNotifierProvider(create: (_) => FilterProvider()),
        ],
        child: const MyApp(),
      ),
    );

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Lagerverwaltung'), findsNothing);
  });
}
