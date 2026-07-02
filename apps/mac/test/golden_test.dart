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

  testWidgets('dashboard golden', (tester) async {
    // Exact design canvas (1000:640) so BoxFit.contain fills gap-free.
    tester.view.physicalSize = const Size(1000, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A2E38), Color(0xFF070810), Color(0xFF1A0F2E)],
            ),
          ),
          child: const DashboardScreen(),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 500));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/dashboard.png'),
    );
  });

  testWidgets('auto-refresh dropdown golden', (tester) async {
    tester.view.physicalSize = const Size(1000, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A2E38), Color(0xFF070810), Color(0xFF1A0F2E)],
            ),
          ),
          child: DashboardScreen(),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.tap(find.text('AUTO-REFRESH'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/dashboard_dropdown.png'),
    );
  });
}
