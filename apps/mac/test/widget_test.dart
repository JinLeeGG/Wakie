// Basic smoke test for the WakieAI dashboard.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wakieai/dashboard.dart';

Future<void> _loadFont(String family, String path) async {
  final loader = FontLoader(family)..addFont(rootBundle.load(path));
  await loader.load();
}

void main() {
  setUpAll(() async {
    await _loadFont('InstrumentSans', 'assets/fonts/InstrumentSans.ttf');
    await _loadFont('JetBrainsMono', 'assets/fonts/JetBrainsMono.ttf');
  });

  testWidgets('Dashboard renders account rows', (tester) async {
    // The dashboard is laid out on a fixed 900x640 canvas; give the test view
    // a matching aspect so the FittedBox scales cleanly (as golden_test does).
    tester.view.physicalSize = const Size(912, 648);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DecoratedBox(
        decoration: BoxDecoration(color: Color(0xFF070810)),
        child: DashboardScreen(),
      ),
    ));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Claude · Personal'), findsOneWidget);
    expect(find.text('Codex · main'), findsOneWidget);
  });
}
