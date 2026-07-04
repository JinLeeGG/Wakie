// Basic smoke test for the WakieAI dashboard.

import 'dart:async';

import 'package:flutter/gestures.dart';
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

    expect(claudeSide, lessThan(codexWork));
    expect(codexWork, lessThan(codexMain)); // Pro sorts above Plus
    expect(codexMain, lessThan(antiMain));
  });

  testWidgets('Within a provider the highest plan sorts first', (tester) async {
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

    // Claude: Work is Max, Personal/side are Pro → Max on top, Pros keep
    // their original relative order (stable sort).
    final claudeWork = tester.getTopLeft(find.text('Claude · Work')).dy;
    final claudePersonal = tester.getTopLeft(find.text('Claude · Personal')).dy;
    final claudeSide = tester.getTopLeft(find.text('Claude · side')).dy;

    expect(claudeWork, lessThan(claudePersonal));
    expect(claudePersonal, lessThan(claudeSide));
  });

  testWidgets('Remove still lands when a status update swapped the row object',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Account row(int pct) => Account(
          id: 'claude-1',
          provider: Provider.claude,
          name: 'Claude · Personal',
          plan: 'a@b.com · Pro',
          session: Meter(pct, Tone.ok, '4:30am'),
          weekly: Meter(pct, Tone.ok, 'Jul 7 (5:00pm)'),
          status: RunStatus.ok,
        );

    final updates = StreamController<List<Account>>();
    addTearDown(updates.close);
    Account? removed;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFF070810)),
          child: DashboardScreen(
            source: () => updates.stream,
            onRemoveAccount: (a) => removed = a,
          ),
        ),
      ),
    );
    updates.add([row(10)]);
    await tester.pump(const Duration(milliseconds: 400));

    // Hover the row to reveal Remove, open the confirm modal.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('Claude · Personal')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Remove').first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 250));

    // While the modal is open, a status update replaces the row with a fresh
    // object (same id) — this used to make the identity remove() a no-op.
    updates.add([row(55)]);
    await tester.pump(const Duration(milliseconds: 100));

    // The modal's confirm button (the overlay is last in the stack).
    await tester.tap(find.text('Remove').last, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));

    expect(removed?.id, 'claude-1');
    expect(find.text('Claude · Personal'), findsNothing);
  });

  testWidgets('Regaining focus polls pending sign-ins immediately',
      (tester) async {
    var polls = 0;
    final updates = StreamController<List<Account>>();
    addTearDown(updates.close);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: DashboardScreen(
          source: () => updates.stream,
          onPollSignins: () async {
            polls++;
            return const [];
          },
        ),
      ),
    );
    final before = polls;

    // The user comes back from the browser after finishing a login — the
    // poll must fire right away, not wait out the periodic timer.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(polls, before + 1);
  });

  testWidgets('Adding a provider whose CLI is missing shows the install guide',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var created = 0;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFF070810)),
          child: DashboardScreen(
            onCheckInstalled: (_) async => false,
            onCreateAccount: (p, l) async {
              created++;
              return null;
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    // Open the Add Account modal (⌘N, as the footer advertises) and submit
    // with the default provider (Claude).
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.textContaining('Sign in with'));
    await tester.pump(const Duration(milliseconds: 400));

    // The install guide appears instead of a sign-in that can never land.
    expect(find.text("Claude Code isn't installed"), findsOneWidget);
    expect(find.text('npm install -g @anthropic-ai/claude-code'),
        findsOneWidget);
    expect(created, 0); // the login was never launched

    await tester.tap(find.text('Close'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text("Claude Code isn't installed"), findsNothing);

    // Let the footer's fail-state timers run out before teardown.
    await tester.pump(const Duration(seconds: 6));
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
