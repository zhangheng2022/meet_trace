import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetily_ai/main.dart';

void main() {
  testWidgets('renders the application shell', (WidgetTester tester) async {
    await tester.pumpWidget(const Application());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Meetily AI'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
