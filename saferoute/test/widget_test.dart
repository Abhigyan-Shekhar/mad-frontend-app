import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saferoute/main.dart';

void main() {
  testWidgets('renders configuration error app', (WidgetTester tester) async {
    await tester.pumpWidget(const ConfigErrorApp(message: 'Missing test env'));

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('Configuration Error'), findsOneWidget);
  });
}
