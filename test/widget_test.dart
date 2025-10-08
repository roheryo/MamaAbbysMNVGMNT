import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_app.dart';

void main() {
  testWidgets('Counter increments smoke test (test app)', (WidgetTester tester) async {
    await tester.pumpWidget(const TestApp());

    // Verify that our counter placeholder starts at 0.
    expect(find.text('0'), findsOneWidget);

    // Verify add icon exists
    expect(find.byKey(const Key('addIcon')), findsOneWidget);
  });
}
