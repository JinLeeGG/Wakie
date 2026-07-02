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

/// Adapter stub whose detect() answer depends on the account probed —
/// for identity-drift tests where ambient and isolated logins differ (or
/// collide).
class _PerAccountAdapter implements ProviderAdapter {
  final Preflight Function(Account) answer;
  final Map<String, String> Function(Account)? env;
  _PerAccountAdapter(this.answer, {this.env});

  @override
  String get id => 'stub';
  @override
  Map<String, String> envFor(Account a) => env?.call(a) ?? const {};
  @override
  Future<Preflight> detect(Account a) async => answer(a);
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

  group('discoverLiveAccounts', () {
    test('pairs each account with its Preflight', () async {
      final claude = _StubAdapter(
          const Preflight(PreflightState.ok, email: 'a@b.com', plan: 'pro'));

      final live = await discoverLiveAccounts(
          {Provider.claude: claude}, Store.memory());

      expect(live, hasLength(1));
      final (account, preflight) = live.single;
      expect(account.provider, Provider.claude);
      expect(preflight.email, 'a@b.com');
    });

    test('skips accounts marked removed in the store', () async {
      final claude = _StubAdapter(const Preflight(PreflightState.ok));
      final store = Store.memory()..removeAccount('claude-default');

      final live =
          await discoverLiveAccounts({Provider.claude: claude}, store);

      expect(live, isEmpty);
    });

    test('includes user-added extra accounts alongside the ambient default',
        () async {
      final claude = _StubAdapter(const Preflight(PreflightState.ok));
      final store = Store.memory()
        ..addExtraAccount(ExtraAccount(
          id: 'claude-work',
          provider: Provider.claude,
          label: 'work',
          configHome: '/tmp/wakieai-claude-work',
          addedAt: DateTime(2026),
        ));

      final live =
          await discoverLiveAccounts({Provider.claude: claude}, store);

      expect(live.map((e) => e.$1.id),
          containsAll(['claude-default', 'claude-work']));
      final extra = live.firstWhere((e) => e.$1.id == 'claude-work').$1;
      expect(extra.configHome, '/tmp/wakieai-claude-work');
      expect(extra.label, 'work');
    });

    test('drops the ambient default when it drifts onto an extra\'s identity',
        () async {
      // The user re-logged the terminal's ambient claude into the same
      // account that already exists as an isolated extra: one identity,
      // two logins. Only the stable extra should survive.
      final claude = _PerAccountAdapter((a) => const Preflight(
          PreflightState.ok, email: 'me@gmail.com', plan: 'pro'));
      final store = Store.memory()
        ..addExtraAccount(ExtraAccount(
          id: 'claude-personal',
          provider: Provider.claude,
          label: 'personal',
          configHome: '/tmp/wakieai-claude-personal',
          addedAt: DateTime(2026),
        ));

      final live =
          await discoverLiveAccounts({Provider.claude: claude}, store);

      expect(live.map((e) => e.$1.id), ['claude-personal']);
    });

    test('keeps the ambient default when identities differ or are unknown',
        () async {
      final claude = _PerAccountAdapter((a) => Preflight(PreflightState.ok,
          email: a.configHome == null ? 'work@corp.com' : 'me@gmail.com'));
      final anti = _PerAccountAdapter(
          (a) => const Preflight(PreflightState.ok)); // email unknown
      final store = Store.memory()
        ..addExtraAccount(ExtraAccount(
          id: 'claude-personal',
          provider: Provider.claude,
          label: 'personal',
          configHome: '/tmp/wakieai-claude-personal',
          addedAt: DateTime(2026),
        ))
        ..addExtraAccount(ExtraAccount(
          id: 'antigravity-extra',
          provider: Provider.antigravity,
          label: 'extra',
          configHome: '/tmp/wakieai-agy-extra',
          addedAt: DateTime(2026),
        ));

      final live = await discoverLiveAccounts(
          {Provider.claude: claude, Provider.antigravity: anti}, store);

      // Different emails → both claude rows; null emails → never deduped.
      expect(
          live.map((e) => e.$1.id),
          containsAll([
            'claude-default',
            'claude-personal',
            'antigravity-default',
            'antigravity-extra',
          ]));
    });

    test('includePendingExtras surfaces a not-yet-signed-in extra account',
        () async {
      final claude = _StubAdapter(const Preflight(PreflightState.notLoggedIn));
      final store = Store.memory()
        ..addExtraAccount(ExtraAccount(
          id: 'claude-work',
          provider: Provider.claude,
          label: 'work',
          configHome: '/tmp/wakieai-claude-work',
          addedAt: DateTime(2026),
        ));

      // Default (runner): hidden — reading a logged-out account is wasted work.
      expect(await discoverLiveAccounts({Provider.claude: claude}, store),
          isEmpty);

      // Dashboard: shown, carrying its not-ok preflight, so it can render as
      // an actionable "sign in" row. The ambient default (also not ok here)
      // stays hidden either way.
      final live = await discoverLiveAccounts({Provider.claude: claude}, store,
          includePendingExtras: true);
      expect(live.map((e) => e.$1.id), ['claude-work']);
      expect(live.single.$2.isOk, isFalse);
    });

    test('an extra account for a provider with no adapter is silently skipped',
        () async {
      final claude = _StubAdapter(const Preflight(PreflightState.ok));
      final store = Store.memory()
        ..addExtraAccount(ExtraAccount(
          id: 'codex-work',
          provider: Provider.codex, // no adapter registered below
          label: 'work',
          configHome: '/tmp/wakieai-codex-work',
          addedAt: DateTime(2026),
        ));

      final live =
          await discoverLiveAccounts({Provider.claude: claude}, store);

      expect(live.map((e) => e.$1.id), ['claude-default']);
    });
  });

  group('terminalCommandFor', () {
    Account acct(Provider p, String? home) => Account(
          id: 'x',
          provider: p,
          label: 'x',
          configHome: home,
          deviceId: 'local',
          addedAt: DateTime(2026),
        );

    test('isolated account → adapter env prefix + provider binary', () {
      final adapter = _PerAccountAdapter(
          (_) => const Preflight(PreflightState.ok),
          env: (a) => {'CLAUDE_CONFIG_DIR': a.configHome!});

      expect(terminalCommandFor(adapter, acct(Provider.claude, '/tmp/c1')),
          'CLAUDE_CONFIG_DIR="/tmp/c1" claude');
    });

    test('ambient account → bare binary per provider', () {
      final adapter =
          _PerAccountAdapter((_) => const Preflight(PreflightState.ok));

      expect(terminalCommandFor(adapter, acct(Provider.claude, null)), 'claude');
      expect(terminalCommandFor(adapter, acct(Provider.codex, null)), 'codex');
      expect(
          terminalCommandFor(adapter, acct(Provider.antigravity, null)), 'agy');
    });
  });
}
