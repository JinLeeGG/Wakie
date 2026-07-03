// Basic smoke test for the WakieAI dashboard.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wakieai/dashboard.dart';
import 'package:wakieai/models.dart';
import 'package:wakieai/widgets/account_row.dart';
import 'package:wakieai/widgets/tiny_toggle_switch.dart';

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

    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: DecoratedBox(
          decoration: BoxDecoration(color: Color(0xFF070810)),
          child: DashboardScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Claude · Personal'), findsOneWidget);
    expect(find.text('Codex · main'), findsOneWidget);
  });

  testWidgets('Dashboard groups rows by provider order', (tester) async {
    tester.view.physicalSize = const Size(1000, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: DecoratedBox(
          decoration: BoxDecoration(color: Color(0xFF070810)),
          child: DashboardScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    final claudeSide = tester.getTopLeft(find.text('Claude · side')).dy;
    final codexMain = tester.getTopLeft(find.text('Codex · main')).dy;
    final codexWork = tester.getTopLeft(find.text('Codex · work')).dy;
    final antiMain = tester.getTopLeft(find.text('Antigravity · main')).dy;

    expect(claudeSide, lessThan(codexMain));
    expect(codexMain, lessThan(codexWork));
    expect(codexWork, lessThan(antiMain));
  });

  testWidgets('Unknown session disables auto-start toggle', (tester) async {
    var toggled = false;

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Material(
          color: const Color(0xFF070810),
          child: SizedBox(
            width: 1000,
            child: AccountRow(
              account: const Account(
                id: 'codex-free',
                provider: Provider.codex,
                name: 'Codex · Free',
                plan: 'free@example.com · Free',
                session: Meter(0, Tone.warn, '', known: false),
                weekly: Meter(84, Tone.ok, 'Jul 7 (9:00am)'),
                status: RunStatus.ok,
                autoStart: true,
                autoStartAvailable: false,
              ),
              animDelayMs: 0,
              onRemove: () {},
              onUpdate: () {},
              onAutoStartChanged: (_) => toggled = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byType(TinyToggleSwitch));

    expect(toggled, isFalse);
  });
}
