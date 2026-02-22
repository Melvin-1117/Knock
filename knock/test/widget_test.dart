// Basic Flutter widget test for the Knock app.

import 'package:flutter_test/flutter_test.dart';

import 'package:knock/main.dart';

void main() {
  testWidgets('Knock app splash screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KnockApp());

    // Verify the KNOCK title is displayed on the splash screen
    expect(find.text('KNOCK'), findsOneWidget);

    // Verify the tagline is displayed
    expect(find.text('Tap into your circle'), findsOneWidget);
  });
}
