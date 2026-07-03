import 'package:test/test.dart';
import 'package:wakieai_core/wakieai_core.dart';

class _FakeAdapter implements ProviderAdapter {
  final Provider provider;
  final bool startOk;
  final ProviderStatus afterStart;
  int startCalls = 0;

  _FakeAdapter(this.provider,
      {this.startOk = true, this.afterStart = ProviderStatus.unknown});

  @override
  String get id => provider.name;
  @override
  Map<String, String> envFor(Account a) => const {};
  @override
  Future<Preflight> detect(Account a) async => const Preflight(PreflightState.ok);
  @override
  Future<ProviderStatus> readStatus(Account a) async => afterStart;
  @override
  Future<RunOutcome> startSession(Account a, {String? model}) async {
    startCalls++;
    return RunOutcome(
      ok: startOk,
      startedAt: DateTime(2026, 6, 1, 15, 5),
      error: startOk ? null : 'boom',
    );
  }
}

Account _account(Provider p, String id) => Account(
      id: id,
      provider: p,
      label: 'default',
      configHome: null,
      deviceId: 'local',
      addedAt: DateTime(2026),
    );

void main() {
  final now = DateTime(2026, 6, 1, 15, 0);
  const preflight = Preflight(PreflightState.ok);

  test('defaultAutoStart is on for Claude, off for Codex/Antigravity', () {
    expect(defaultAutoStart(Provider.claude), isTrue);
    expect(defaultAutoStart(Provider.codex), isFalse);
    expect(defaultAutoStart(Provider.antigravity), isFalse);
  });

  test('lapsed session + auto-start on starts a new one and caches fresh status', () async {
    final claude = _FakeAdapter(Provider.claude,
        afterStart: const ProviderStatus(
            session: UsageWindow(usedPct: 0, resetLabel: '8:00pm')));
    final store = Store.memory();
    final account = _account(Provider.claude, 'claude-default');
    final lapsedStatus = ProviderStatus(
        session: UsageWindow(usedPct: 100, resetAt: DateTime(2026, 6, 1, 14, 0)));

    await chainExpiredSessions(
      {Provider.claude: claude},
      store,
      [(account, preflight, lapsedStatus)],
      now: now,
    );

    expect(claude.startCalls, 1);
    final cached = store.statusFor('claude-default')!;
    expect(cached.session.usedPct, 0); // re-read after start, not the stale 100%
    expect(cached.lastOutcome, Outcome.ok);
    expect(cached.lastStartedAt, DateTime(2026, 6, 1, 15, 5));
  });

  test('still mid-window (resetAt in the future) is left alone', () async {
    final claude = _FakeAdapter(Provider.claude);
    final store = Store.memory();
    final account = _account(Provider.claude, 'claude-default');
    final active = ProviderStatus(
        session: UsageWindow(usedPct: 40, resetAt: DateTime(2026, 6, 1, 20, 0)));

    await chainExpiredSessions(
        {Provider.claude: claude}, store, [(account, preflight, active)], now: now);

    expect(claude.startCalls, 0);
    expect(store.statusFor('claude-default'), isNull);
  });

  test('just-passed reset is held back by the grace period (not fired early)', () async {
    // resetAt one minute before `now` — inside the 2-minute grace. The real
    // quota may not have refreshed yet, so the chain must wait a tick.
    final claude = _FakeAdapter(Provider.claude);
    final store = Store.memory();
    final account = _account(Provider.claude, 'claude-default');
    final barelyLapsed = ProviderStatus(
        session: UsageWindow(usedPct: 100, resetAt: DateTime(2026, 6, 1, 14, 59)));

    await chainExpiredSessions({Provider.claude: claude}, store,
        [(account, preflight, barelyLapsed)],
        now: now);

    expect(claude.startCalls, 0);
    expect(store.statusFor('claude-default'), isNull);
  });

  test('reset older than the grace period fires the chain', () async {
    final claude = _FakeAdapter(Provider.claude,
        afterStart: const ProviderStatus(
            session: UsageWindow(usedPct: 0, resetLabel: '8:00pm')));
    final store = Store.memory();
    final account = _account(Provider.claude, 'claude-default');
    final lapsed = ProviderStatus(
        session: UsageWindow(usedPct: 100, resetAt: DateTime(2026, 6, 1, 14, 57)));

    await chainExpiredSessions(
        {Provider.claude: claude}, store, [(account, preflight, lapsed)], now: now);

    expect(claude.startCalls, 1);
  });

  test('Codex defaults to auto-start off even when lapsed', () async {
    final codex = _FakeAdapter(Provider.codex);
    final store = Store.memory();
    final account = _account(Provider.codex, 'codex-default');
    final lapsed = ProviderStatus(
        session: UsageWindow(usedPct: 100, resetAt: DateTime(2026, 6, 1, 14, 0)));

    await chainExpiredSessions(
        {Provider.codex: codex}, store, [(account, preflight, lapsed)], now: now);

    expect(codex.startCalls, 0);
  });

  test('explicit per-account opt-in overrides the provider default', () async {
    final codex = _FakeAdapter(Provider.codex);
    final store = Store.memory()..setAutoStart('codex-default', true);
    final account = _account(Provider.codex, 'codex-default');
    final lapsed = ProviderStatus(
        session: UsageWindow(usedPct: 100, resetAt: DateTime(2026, 6, 1, 14, 0)));

    await chainExpiredSessions(
        {Provider.codex: codex}, store, [(account, preflight, lapsed)], now: now);

    expect(codex.startCalls, 1);
  });

  test('explicit opt-out overrides Claude\'s on-by-default', () async {
    final claude = _FakeAdapter(Provider.claude);
    final store = Store.memory()..setAutoStart('claude-default', false);
    final account = _account(Provider.claude, 'claude-default');
    final lapsed = ProviderStatus(
        session: UsageWindow(usedPct: 100, resetAt: DateTime(2026, 6, 1, 14, 0)));

    await chainExpiredSessions(
        {Provider.claude: claude}, store, [(account, preflight, lapsed)], now: now);

    expect(claude.startCalls, 0);
  });

  test('failed start records the failure and keeps the stale usage instead of clobbering it', () async {
    final claude = _FakeAdapter(Provider.claude, startOk: false);
    final store = Store.memory();
    final account = _account(Provider.claude, 'claude-default');
    final lapsed = ProviderStatus(
        session: UsageWindow(usedPct: 100, resetAt: DateTime(2026, 6, 1, 14, 0)));

    await chainExpiredSessions(
        {Provider.claude: claude}, store, [(account, preflight, lapsed)], now: now);

    final cached = store.statusFor('claude-default')!;
    expect(cached.lastOutcome, Outcome.failed);
    expect(cached.session.usedPct, 100); // start failed → no fresh read, keep last-known
  });
}
