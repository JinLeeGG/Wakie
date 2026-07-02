import 'package:test/test.dart';
import 'package:wakieai_core/wakieai_core.dart';

Account _account(String? home) => Account(
      id: 'a1',
      provider: Provider.claude,
      label: 'Personal',
      configHome: home,
      deviceId: 'd1',
      addedAt: DateTime(2026, 7, 1),
    );

void main() {
  test('envFor isolates added accounts by CLAUDE_CONFIG_DIR', () {
    final adapter = ClaudeAdapter(capture: (_) async => '');
    expect(adapter.envFor(_account('/home/a')),
        {'CLAUDE_CONFIG_DIR': '/home/a'});
    expect(adapter.envFor(_account('/home/b')),
        {'CLAUDE_CONFIG_DIR': '/home/b'});
  });

  test('envFor leaves the ambient default account untouched', () {
    final adapter = ClaudeAdapter(capture: (_) async => '');
    // null configHome → no override, so the Keychain default stays visible.
    expect(adapter.envFor(_account(null)), isEmpty);
  });

  test('readStatus parses whatever the injected capture returns', () async {
    const panel = 'Current session\n30% used Resets 5:00pm (America/New_York)\n'
        'Current week (all models)\n70% used Resets Jul 9 at 7am (America/New_York)';
    final adapter = ClaudeAdapter(capture: (_) async => panel);

    final status = await adapter.readStatus(_account('/home/a'));
    expect(status.session.usedPct, 30);
    expect(status.weekly.usedPct, 70);
  });
}
