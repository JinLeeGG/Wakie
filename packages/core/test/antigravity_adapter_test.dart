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

  test('readStatus surfaces the account email from the panel header', () async {
    final adapter = AntigravityAdapter(capture: (_) async => '''
korus.exe@gmail.com (Antigravity Starter Quota)
GEMINI MODELS
  Weekly Limit
    [██████████] 97.00%
    97% remaining · Refreshes in 166h 0m
''');
    final status = await adapter.readStatus(_account(null));
    expect(status.accountEmail, 'korus.exe@gmail.com');
    expect(status.weekly.usedPct, 3);
    // "(Antigravity Starter Quota)" → bare tier, like other providers' plans.
    expect(status.accountPlan, 'Starter');
  });

  test('plan header variants normalize to the bare tier', () async {
    Future<String?> plan(String header) async {
      final adapter = AntigravityAdapter(capture: (_) async => header);
      return (await adapter.readStatus(_account(null))).accountPlan;
    }

    expect(await plan('a@b.com (Google AI Pro)'), 'Pro');
    expect(await plan('a@b.com (Antigravity Starter Quota)'), 'Starter');
    expect(await plan('a@b.com (Ultra)'), 'Ultra'); // unknown shape kept as-is
    expect(await plan('a@b.com'), isNull); // no parenthesized tier
  });

  test('readStatus never launches agy for an isolated account with no keychain',
      () async {
    var captured = false;
    final adapter = AntigravityAdapter(capture: (_) async {
      captured = true;
      return 'GEMINI MODELS\n  Weekly Limit\n    99% remaining';
    });
    // configHome with no login keychain → must NOT capture (no OAuth browser).
    final status =
        await adapter.readStatus(_account('/tmp/wakieai-agy-no-keychain'));
    expect(captured, isFalse);
    expect(status.weekly.isKnown, isFalse);
  });

  test('an isolated account with no login keychain detects as not logged in',
      () async {
    // An extra account's token lives in its own login keychain; with no such
    // keychain present, detect must report notLoggedIn (never a false "ok").
    final adapter = AntigravityAdapter(capture: (_) async => '');
    final pf = await adapter.detect(_account('/tmp/wakieai-agy-no-keychain'));
    expect(pf.state, PreflightState.notLoggedIn);
  });
}
