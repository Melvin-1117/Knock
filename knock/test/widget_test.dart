// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:knock/main.dart';

void main() {
  testWidgets('Knock app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KnockApp());

    // Verify the KNOCK title and button text are present
    expect(find.text('KNOCK'), findsOneWidget);
    expect(find.text('TAP TO WAKE HIM UP'), findsOneWidget);

    // Tap the knock button
    await tester.tap(find.byIcon(Icons.touch_app));
    await tester.pump();

    // Verify status changes to SENDING
    expect(find.text('SENDING...'), findsOneWidget);
  });
}
