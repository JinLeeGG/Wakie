import 'package:test/test.dart';
import 'package:wakieai_core/wakieai_core.dart';

Account _account(String? home) => Account(
      id: 'a1',
      provider: Provider.antigravity,
      label: 'work',
      configHome: home,
      deviceId: 'd1',
      addedAt: DateTime(2026, 7, 2),
    );

void main() {
  test('envFor isolates added accounts by HOME', () {
    final adapter = AntigravityAdapter(capture: (_) async => '');
    expect(adapter.envFor(_account('/home/a')), {'HOME': '/home/a'});
  });

  test('envFor leaves the ambient default account untouched', () {
    final adapter = AntigravityAdapter(capture: (_) async => '');
    expect(adapter.envFor(_account(null)), isEmpty);
  });

  test('readStatus parses whatever the injected capture returns', () async {
    final adapter = AntigravityAdapter(capture: (_) async => '''
GEMINI MODELS
  Weekly Limit
    [██████████] 95.00%
    95% remaining · Refreshes in 100h 0m
  Five Hour Limit
    [████████░░] 80.00%
    80% remaining · Refreshes in 2h 10m
''');
    final status = await adapter.readStatus(_account(null));
    expect(status.weekly.usedPct, 5);
    expect(status.session.usedPct, 20);
    expect(status.session.resetLabel, '2h 10m');
  });

  test('readStatus degrades to unknown when the capture is empty', () async {
    final adapter = AntigravityAdapter(capture: (_) async => '');
    final status = await adapter.readStatus(_account(null));
    expect(status.session.isKnown, isFalse);
    expect(status.weekly.isKnown, isFalse);
  });
}
