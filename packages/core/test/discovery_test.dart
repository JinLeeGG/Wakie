import 'package:test/test.dart';
import 'package:wakieai_core/wakieai_core.dart';

/// Adapter stub whose detect() outcome is fixed per test.
class _StubAdapter implements ProviderAdapter {
  final Preflight preflight;
  Account? sawAccount;
  _StubAdapter(this.preflight);

  @override
  String get id => 'stub';
  @override
  Map<String, String> envFor(Account a) => const {};
  @override
  Future<Preflight> detect(Account a) async {
    sawAccount = a;
    return preflight;
  }

  @override
  Future<ProviderStatus> readStatus(Account a) async => ProviderStatus.unknown;
  @override
  Future<RunOutcome> startSession(Account a, {String? model}) async =>
      RunOutcome(ok: true, startedAt: DateTime(2026));
}

void main() {
  test('discovers only logged-in providers as ambient default accounts', () async {
    final claude = _StubAdapter(const Preflight(PreflightState.ok));
    final codex = _StubAdapter(const Preflight(PreflightState.notLoggedIn));

    final accounts = await discoverDefaultAccounts(
      {Provider.claude: claude, Provider.codex: codex},
    );

    expect(accounts.map((a) => a.provider), [Provider.claude]);
    // Ambient default → no config-home override (Keychain-backed).
    expect(accounts.single.configHome, isNull);
    expect(claude.sawAccount!.configHome, isNull);
  });
}
