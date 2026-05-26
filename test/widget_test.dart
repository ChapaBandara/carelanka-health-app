import 'package:carelanka_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(const CareLankaApp());
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
