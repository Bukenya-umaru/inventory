import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inventory_app/screens/admin/store_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Raw JSON returned by the mocked API, mimicking the backend response shape.
const List<Map<String, dynamic>> _testProducts = [
  {
    '_id': 'p1',
    'name': 'Soda Coke 500ml Crate with a Very Long Product Name',
    'categoryId': {'_id': 'c1', 'name': 'Beverages'},
    'costPrice': 20000,
    'sellingPrice': 25000,
    'currentStock': 5,
    'minimumStock': 10,
    'unit': 'piece',
    'sellingUnit': 'box',
    'unitsPerBox': 24,
    'stockBoxes': 12,
    'boxSellingPrice': 550000,
    'boxCostPrice': 480000,
  },
  {
    '_id': 'p2',
    'name': 'USB-C Cable',
    'categoryId': {'_id': 'c2', 'name': 'Electronics'},
    'costPrice': 1000,
    'sellingPrice': 1500,
    'currentStock': 50,
    'minimumStock': 10,
    'unit': 'piece',
    'sellingUnit': 'piece',
    'unitsPerBox': 1,
    'stockBoxes': 0,
  },
  {
    '_id': 'p3',
    'name': 'Biscuits Carton',
    'categoryId': {'_id': 'c1', 'name': 'Beverages'},
    'costPrice': 30000,
    'sellingPrice': 40000,
    'currentStock': 0,
    'minimumStock': 5,
    'unit': 'piece',
    'sellingUnit': 'box',
    'unitsPerBox': 12,
    'stockBoxes': 0,
    'boxSellingPrice': 480000,
    'boxCostPrice': 360000,
  },
];

const List<Map<String, dynamic>> _testCategories = [
  {'_id': 'c1', 'name': 'Beverages'},
  {'_id': 'c2', 'name': 'Electronics & Gadgets Long Category Name'},
];

Future<http.Response> _mockHandler(http.Request request) async {
  if (request.url.path.endsWith('/products')) {
    return http.Response(json.encode({'products': _testProducts}), 200);
  }
  if (request.url.path.endsWith('/categories')) {
    return http.Response(json.encode({'categories': _testCategories}), 200);
  }
  return http.Response(json.encode({'message': 'not found'}), 404);
}

Future<void> _pumpStoreAt(
  WidgetTester tester, {
  required Size size,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  if (textScale != 1.0) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
  }

  await http.runWithClient(() async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StoreScreen()),
      ),
    );
    // First pump builds loading state, second lets the mocked API resolve.
    await tester.pump();
    await tester.pumpAndSettle();
  }, () => MockClient(_mockHandler));

  // Any layout overflow (RenderFlex error) or build exception fails the test.
  expect(tester.takeException(), isNull);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('header and cards fit at 320x640 (small phone)', (tester) async {
    await _pumpStoreAt(tester, size: const Size(320, 640));

    final summary = tester.widget<Text>(find.textContaining('items')).data!;
    expect(summary, contains('• 12 bx •'), reason: 'header must show box total');
    expect(find.text('12 bx, 5 pc'), findsOneWidget,
        reason: 'box-sold product card shows boxes + loose pieces');
    expect(find.text('50 pcs'), findsOneWidget,
        reason: 'piece-sold product card unchanged');
  });

  testWidgets('header and cards fit at 360x800 (common phone)', (tester) async {
    await _pumpStoreAt(tester, size: const Size(360, 800));

    final summary = tester.widget<Text>(find.textContaining('items')).data!;
    expect(summary, contains('• 12 bx •'));
    expect(find.text('12 bx, 5 pc'), findsOneWidget);
  });

  testWidgets('header and cards fit at 412x915 (large phone)', (tester) async {
    await _pumpStoreAt(tester, size: const Size(412, 915));

    final summary = tester.widget<Text>(find.textContaining('items')).data!;
    expect(summary, contains('• 12 bx •'));
  });

  testWidgets('header fits at 280x600 (very narrow)', (tester) async {
    await _pumpStoreAt(tester, size: const Size(280, 600));

    final summary = tester.widget<Text>(find.textContaining('items')).data!;
    expect(summary, contains('• 12 bx •'));
  });

  testWidgets('header fits at 320x640 with large text scale 1.3',
      (tester) async {
    await _pumpStoreAt(tester, size: const Size(320, 640), textScale: 1.3);

    final summary = tester.widget<Text>(find.textContaining('items')).data!;
    expect(summary, contains('• 12 bx •'));
  });
}
