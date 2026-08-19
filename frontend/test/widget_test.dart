import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const InventoryApp());
    expect(find.text('Inventory Management'), findsOneWidget);
  });
}
