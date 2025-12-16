import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:client/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(child: const SynceApp()));

    expect(find.text('Synce'), findsOneWidget);
    expect(find.text('No PDF files yet'), findsOneWidget);
  });
}
