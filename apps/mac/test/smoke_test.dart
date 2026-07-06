import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wakie/dashboard.dart';

/// UI smoke: hammer the dashboard — spam buttons, open/close modals, spin the
/// wheel, fling the list, toggle switches, hover, fire shortcuts — and assert
/// nothing throws (overflows, disposed-controller/setState errors, and layout
/// asserts all fail a widget test). Mock mode (no `source`) so it's
/// deterministic and never touches a real CLI.
Future<void> _loadFont(String family, String path) async {
  final loader = FontLoader(family)..addFont(rootBundle.load(path));
  await loader.load();
}

void main() {
  setUpAll(() async {
    await _loadFont('InstrumentSans', 'assets/fonts/InstrumentSans.ttf');
    await _loadFont('JetBrainsMono', 'assets/fonts/JetBrainsMono.ttf');
  });

  testWidgets('UI survives a stress pass', (tester) async {
    tester.view.physicalSize = const Size(1100, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final rng = Random(7);

    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: DashboardScreen(), // mock data, no live source
      ),
    );
    await tester.pump(const Duration(milliseconds: 900)); // entrance settles

    Finder t(String s) => find.text(s);
    Future<void> tapText(String s) async {
      final f = t(s);
      if (f.evaluate().isNotEmpty) {
        await tester.tap(f.first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 30));
      }
    }

    // 1) Spam Refresh all.
    for (var i = 0; i < 10; i++) {
      await tapText('Refresh all');
    }

    // 2) Open/close the Add account modal a bunch, poking inside it.
    for (var i = 0; i < 4; i++) {
      await tapText('Add account');
      await tester.pump(const Duration(milliseconds: 220));
      for (final p in ['Codex', 'Antigravity', 'Claude']) {
        await tapText(p);
      }
      final field = find.byType(TextField);
      if (field.evaluate().isNotEmpty) {
        await tester.enterText(field.first, 'stress-$i');
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.tapAt(const Offset(6, 6)); // backdrop → close
      await tester.pump(const Duration(milliseconds: 220));
    }

    // 3) DAILY WAKE dropdown: open, fling the wheels, Set / dismiss.
    for (var i = 0; i < 4; i++) {
      await tapText('DAILY WAKE');
      await tester.pump(const Duration(milliseconds: 220));
      for (final w in find.byType(ListWheelScrollView).evaluate().toList()) {
        await tester.fling(find.byWidget(w.widget),
            Offset(0, (rng.nextBool() ? -1 : 1) * 140.0), 900);
        await tester.pump(const Duration(milliseconds: 80));
      }
      final set = find.textContaining('Set ');
      if (set.evaluate().isNotEmpty) {
        await tester.tap(set.first, warnIfMissed: false);
      } else {
        await tester.tapAt(const Offset(6, 6));
      }
      await tester.pump(const Duration(milliseconds: 220));
    }

    // 4) Fling the account list hard, both ways.
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isNotEmpty) {
      final list = scrollable.first;
      for (var i = 0; i < 8; i++) {
        await tester.fling(list, Offset(0, i.isEven ? -900 : 900), 2000);
        await tester.pump(const Duration(milliseconds: 90));
      }
    }

    // 5) Toggle footer switches repeatedly.
    for (var i = 0; i < 3; i++) {
      await tapText('Wake from sleep');
      await tapText('Launch at login');
    }

    // 6) Hover headers (tooltips) + a row (reveals Remove/Update), then open and
    //    cancel the Remove confirm.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    for (final h in ['AUTO', 'CURRENT', 'WEEKLY', 'STATUS']) {
      final f = t(h);
      if (f.evaluate().isNotEmpty) {
        await mouse.moveTo(tester.getCenter(f.first));
        await tester.pump(const Duration(milliseconds: 60));
      }
    }
    final row = t('Claude · Personal');
    if (row.evaluate().isNotEmpty) {
      await mouse.moveTo(tester.getCenter(row.first));
      await tester.pump(const Duration(milliseconds: 200));
      final remove = t('Remove');
      if (remove.evaluate().isNotEmpty) {
        await tester.tap(remove.first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 220));
        await tapText('Cancel'); // dismiss the confirm without removing
        await tester.pump(const Duration(milliseconds: 220));
      }
    }

    // 7) Fire the keyboard shortcuts a few times.
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(const Offset(6, 6)); // close any modal ⌘N opened
      await tester.pump(const Duration(milliseconds: 60));
    }

    // Let the periodic timers (tagline, polls) tick through a couple cycles.
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 7));
    }

    // Still standing.
    expect(find.byType(DashboardScreen), findsOneWidget);

    // Unmount so the dashboard's timers are cancelled (no pending-timer error).
    await tester.pumpWidget(const SizedBox());
  });
}
