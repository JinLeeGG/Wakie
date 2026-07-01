// Basic smoke test for the WakieAI dashboard.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wakieai/dashboard.dart';

void main() {
  testWidgets('Dashboard renders account rows', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Claude · Personal'), findsOneWidget);
    expect(find.text('Codex · main'), findsOneWidget);
  });
}
