import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wakie/models.dart';
import 'package:wakie/widgets/install_cli_modal.dart';

Widget _host(InstallCliModal modal) => MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Stack(children: [modal]), // Positioned.fill needs a Stack
    );

void main() {
  testWidgets('Copy writes the install command and flips to Copied',
      (tester) async {
    final clipboard = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, (call) async {
      clipboard.add(call);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(_host(InstallCliModal(
      provider: Provider.claude,
      onClose: () {},
    )));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Copy'));
    await tester.pump();

    final set = clipboard.where((c) => c.method == 'Clipboard.setData');
    expect(set.single.arguments['text'],
        'npm install -g @anthropic-ai/claude-code');
    expect(find.text('Copied'), findsOneWidget);

    // The label reverts (and its timer drains before teardown).
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('Open install page opens the provider URL and closes',
      (tester) async {
    String? opened;
    var closed = false;
    await tester.pumpWidget(_host(InstallCliModal(
      provider: Provider.codex,
      onClose: () => closed = true,
      onOpenUrl: (url) => opened = url,
    )));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Open install page'));
    await tester.pump();

    expect(opened, 'https://developers.openai.com/codex/cli');
    expect(closed, isTrue);
  });

  testWidgets('Antigravity has no npm command — app install guidance instead',
      (tester) async {
    await tester.pumpWidget(_host(InstallCliModal(
      provider: Provider.anti,
      onClose: () {},
    )));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text("Antigravity isn't installed"), findsOneWidget);
    expect(find.text('Copy'), findsNothing); // no command row
    expect(find.textContaining('ships with the Antigravity app'),
        findsOneWidget);
  });
}
