import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_app/widgets/compact_data_table.dart';

Future<void> _pumpTableAt(
  WidgetTester tester, {
  required Size size,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            const SizedBox(height: 120, child: Center(child: Text('Section'))),
            Expanded(
              child: CompactDataTable(
                columns: const [CompactTableColumn('Record')],
                rows: List.generate(
                  10,
                  (index) => CompactDataRow([Text('Record ${index + 1}')]),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('table scrolls vertically on a phone', (tester) async {
    await _pumpTableAt(tester, size: const Size(360, 640));

    expect(find.text('RECORD'), findsOneWidget);
    final verticalScrollable = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .first;
    final before = tester
        .state<ScrollableState>(verticalScrollable)
        .position
        .pixels;
    await tester.drag(find.byType(CompactDataTable), const Offset(0, -500));
    await tester.pumpAndSettle();
    final after = tester
        .state<ScrollableState>(verticalScrollable)
        .position
        .pixels;
    expect(after, greaterThan(before));
    expect(tester.takeException(), isNull);
  });

  testWidgets('table scrolls vertically on desktop', (tester) async {
    await _pumpTableAt(tester, size: const Size(1280, 600));

    expect(find.text('RECORD'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('table avoids overflow with large text', (tester) async {
    await _pumpTableAt(
      tester,
      size: const Size(360, 640),
      textScale: 1.5,
    );

    expect(find.text('RECORD'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
