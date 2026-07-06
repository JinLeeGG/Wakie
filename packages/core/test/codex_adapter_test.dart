import 'package:test/test.dart';
import 'package:wakie_core/wakie_core.dart';

Account _account(String? home) => Account(
      id: 'c1',
      provider: Provider.codex,
      label: 'work',
      configHome: home,
      deviceId: 'd1',
      addedAt: DateTime(2026, 7, 2),
    );

void main() {
  test('envFor isolates added accounts by CODEX_HOME', () {
    final adapter = CodexAdapter(read: (_) async => null);
    expect(adapter.envFor(_account('/home/a')), {'CODEX_HOME': '/home/a'});
    expect(adapter.envFor(_account('/home/b')), {'CODEX_HOME': '/home/b'});
  });

  test('envFor leaves the ambient default account untouched', () {
    final adapter = CodexAdapter(read: (_) async => null);
    expect(adapter.envFor(_account(null)), isEmpty);
  });

  test('readStatus parses whatever the injected read returns', () async {
    final adapter = CodexAdapter(read: (_) async => {
          'rateLimits': {
            'primary': {'usedPercent': 10, 'resetsAt': 1782984529},
            'secondary': {'usedPercent': 60, 'resetsAt': 1783392259},
          },
        });
    final status = await adapter.readStatus(_account(null));
    expect(status.session.usedPct, 10);
    expect(status.weekly.usedPct, 60);
  });

  test('readStatus degrades to unknown when the read fails', () async {
    final adapter = CodexAdapter(read: (_) async => null);
    final status = await adapter.readStatus(_account(null));
    expect(status.session.isKnown, isFalse);
    expect(status.weekly.isKnown, isFalse);
  });
}
