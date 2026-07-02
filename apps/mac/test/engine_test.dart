import 'package:flutter_test/flutter_test.dart';
import 'package:wakieai/engine.dart';
import 'package:wakieai/models.dart';
import 'package:wakieai_core/wakieai_core.dart' as core;

/// Adapter that reports a fixed login + usage, so we can assert the mapping
/// from core status to the dashboard's view model.
class _FakeClaude implements core.ProviderAdapter {
  final core.ProviderStatus status;
  _FakeClaude(this.status);

  @override
  String get id => 'claude';
  @override
  Map<String, String> envFor(core.Account a) => const {};
  @override
  Future<core.Preflight> detect(core.Account a) async =>
      const core.Preflight(core.PreflightState.ok, detail: 'pro');
  @override
  Future<core.ProviderStatus> readStatus(core.Account a) async => status;
  @override
  Future<core.RunOutcome> startSession(core.Account a, {String? model}) async =>
      core.RunOutcome(ok: true, startedAt: DateTime(2026));
}

void main() {
  test('maps core usage (used%) to UI meters (remaining% + tone)', () async {
    final engine = Engine.withAdapters({
      core.Provider.claude: _FakeClaude(const core.ProviderStatus(
        // 88% used → 12% left → crit; reset label trimmed of timezone.
        session: core.UsageWindow(
            usedPct: 88, resetLabel: '2:30am (America/New_York)'),
        // 30% used → 70% left → ok.
        weekly: core.UsageWindow(
            usedPct: 30, resetLabel: 'Jul 7 at 7am (America/New_York)'),
      )),
    });

    final rows = await engine.load();
    expect(rows, hasLength(1));
    final a = rows.single;

    expect(a.provider, Provider.claude);
    expect(a.plan, 'claude · pro');
    expect(a.session.pct, 12);
    expect(a.session.tone, Tone.crit);
    expect(a.session.reset, '2:30am');
    expect(a.weekly.pct, 70);
    expect(a.weekly.tone, Tone.ok);
    expect(a.status, RunStatus.low); // session nearly exhausted
  });

  test('unknown usage falls back gracefully', () async {
    final engine = Engine.withAdapters({
      core.Provider.claude: _FakeClaude(core.ProviderStatus.unknown),
    });
    final a = (await engine.load()).single;
    expect(a.session.reset, '…');
  });
}
