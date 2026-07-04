import 'dart:async';

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
      const core.Preflight(core.PreflightState.ok,
          email: 'a@b.com', plan: 'pro');
  @override
  Future<core.ProviderStatus> readStatus(core.Account a) async => status;
  @override
  Future<core.RunOutcome> startSession(core.Account a, {String? model}) async =>
      core.RunOutcome(ok: true, startedAt: DateTime(2026));
}

/// Like [_FakeClaude], but extra (config-home-isolated) accounts start not
/// logged in until [extraLoggedIn] flips — mimicking the real add-account
/// flow where sign-in happens later in Terminal. The ambient default stays
/// logged in throughout.
class _PendingClaude extends _FakeClaude {
  bool extraLoggedIn = false;
  final String extraEmail;
  _PendingClaude(super.status, {this.extraEmail = 'work@b.com'});

  @override
  Future<core.Preflight> detect(core.Account a) async {
    if (a.configHome == null) return super.detect(a);
    return extraLoggedIn
        ? core.Preflight(core.PreflightState.ok, email: extraEmail, plan: 'pro')
        : const core.Preflight(core.PreflightState.notLoggedIn);
  }
}

/// Extra accounts sign in *independently* (each with its own identity, derived
/// from its config home) once [extrasLoggedIn] flips — for the parallel
/// add-account flow. [detectGate], when set, blocks every detect so a test can
/// interleave an addAccount with an in-flight scan.
class _ParallelPendingClaude extends _FakeClaude {
  bool extrasLoggedIn = false;
  Completer<void>? detectGate;
  _ParallelPendingClaude(super.status);

  @override
  Future<core.Preflight> detect(core.Account a) async {
    await detectGate?.future;
    if (a.configHome == null) return super.detect(a);
    return extrasLoggedIn
        ? core.Preflight(core.PreflightState.ok,
            email: '${a.configHome!.split('/').last}@b.com', plan: 'pro')
        : const core.Preflight(core.PreflightState.notLoggedIn);
  }
}

/// Counts detect() calls so a test can assert an expired sign-in is dropped
/// *without* spending a detect subprocess on it. Extra accounts never log in.
class _CountingPendingClaude extends _FakeClaude {
  final void Function() onDetect;
  _CountingPendingClaude(this.onDetect)
      : super(const core.ProviderStatus());

  @override
  Future<core.Preflight> detect(core.Account a) async {
    onDetect();
    if (a.configHome == null) return super.detect(a);
    return const core.Preflight(core.PreflightState.notLoggedIn);
  }
}

/// The provider CLI is missing entirely — every detect reports notInstalled.
class _NotInstalledClaude extends _FakeClaude {
  _NotInstalledClaude() : super(const core.ProviderStatus());

  @override
  Future<core.Preflight> detect(core.Account a) async =>
      const core.Preflight(core.PreflightState.notInstalled);
}

/// Counts startSession/readStatus calls for awake-tick assertions.
class _CountingClaude extends _FakeClaude {
  int starts = 0;
  int reads = 0;
  _CountingClaude(super.status);

  @override
  Future<core.RunOutcome> startSession(core.Account a, {String? model}) async {
    starts++;
    return super.startSession(a, model: model);
  }

  @override
  Future<core.ProviderStatus> readStatus(core.Account a) async {
    reads++;
    return super.readStatus(a);
  }
}

/// readStatus blocks on [gate] when set — for concurrency-guard tests.
class _GatedClaude extends _FakeClaude {
  Completer<core.ProviderStatus>? gate;
  _GatedClaude() : super(const core.ProviderStatus());

  @override
  Future<core.ProviderStatus> readStatus(core.Account a) =>
      gate?.future ?? super.readStatus(a);
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
    expect(a.plan, 'a@b.com · Pro');
    expect(a.session.pct, 12);
    expect(a.session.tone, Tone.crit);
    expect(a.session.reset, '2:30am');
    expect(a.weekly.pct, 70);
    expect(a.weekly.tone, Tone.ok);
    // Claude's rendered "Jul 7 at 7am" now resolves through core's absolute
    // parsing too, so it zero-pads minutes just like Codex's epoch does —
    // one unified format across providers instead of ad-hoc string surgery.
    expect(a.weekly.reset, 'Jul 7 (7:00am)');
    expect(a.status, RunStatus.low); // session nearly exhausted
    expect(a.autoStart, isTrue); // Claude defaults to auto-start on (R0 🟢)
    expect(a.autoStartAvailable, isTrue);
  });

  test('maps Codex epoch resetAt to date (weekly) and time (session)', () async {
    final sessionAt = DateTime(2026, 6, 1, 15, 30); // local
    final weeklyAt = DateTime(2026, 6, 5, 9, 0); // local
    final engine = Engine.withAdapters({
      core.Provider.codex: _FakeClaude(core.ProviderStatus(
        session: core.UsageWindow(usedPct: 1, resetAt: sessionAt), // 99% left
        weekly: core.UsageWindow(usedPct: 44, resetAt: weeklyAt), // 56% left
      )),
    });

    final a = (await engine.load()).single;
    expect(a.provider, Provider.codex);
    expect(a.session.pct, 99);
    expect(a.session.tone, Tone.ok);
    expect(a.session.reset, '3:30pm'); // session window → time
    expect(a.weekly.pct, 56);
    expect(a.weekly.reset, 'Jun 5 (9:00am)'); // weekly window → date (time)
    expect(a.autoStart, isFalse); // Codex defaults to auto-start off (R0 🟡)
  });

  test('weekly reset within 24h shows a countdown, not a date', () async {
    final engine = Engine.withAdapters({
      core.Provider.codex: _FakeClaude(core.ProviderStatus(
        // Session always resolves under 5h — keeps its clock time. Weekly
        // lands inside a day, so it flips to "Xh Ym" remaining.
        session: core.UsageWindow(
            usedPct: 10,
            resetAt: DateTime.now().add(const Duration(hours: 3))),
        weekly: core.UsageWindow(
            usedPct: 20,
            resetAt: DateTime.now().add(const Duration(hours: 5, minutes: 20))),
      )),
    });

    final a = (await engine.load()).single;
    expect(a.weekly.reset, matches(RegExp(r'^\d+h \d+m$')));
    expect(a.session.reset, isNot(matches(RegExp(r'^\d+h \d+m$'))));
  });

  test('unknown usage falls back gracefully', () async {
    final engine = Engine.withAdapters({
      core.Provider.claude: _FakeClaude(core.ProviderStatus.unknown),
    });
    final a = (await engine.load()).single;
    expect(a.session.known, isFalse);
    expect(a.session.reset, '');
    expect(a.autoStartAvailable, isFalse);
  });

  test('refreshAccount re-reads a single discovered account by id', () async {
    final engine = Engine.withAdapters({
      core.Provider.claude: _FakeClaude(const core.ProviderStatus(
        session: core.UsageWindow(usedPct: 40, resetLabel: '2:30am'),
        weekly: core.UsageWindow(usedPct: 10, resetLabel: 'Jul 7 at 7am'),
      )),
    });
    await engine.load(); // discovers + remembers accounts

    final row = await engine.refreshAccount('claude-default');
    expect(row, isNotNull);
    expect(row!.provider, Provider.claude);
    expect(row.session.pct, 60); // 40% used → 60% left, re-read live

    expect(await engine.refreshAccount('nope'), isNull);
  });

  test('removeAccount is persisted so rediscovery does not resurrect it',
      () async {
    final engine = Engine.withAdapters({
      core.Provider.claude: _FakeClaude(const core.ProviderStatus(
        session: core.UsageWindow(usedPct: 40, resetLabel: '2:30am'),
        weekly: core.UsageWindow(usedPct: 10, resetLabel: 'Jul 7 at 7am'),
      )),
    });
    await engine.load(); // discovers + remembers accounts

    engine.removeAccount('claude-default');
    final rows = await engine.load(); // full rediscovery

    expect(rows, isEmpty);
    expect(await engine.refreshAccount('claude-default'), isNull);
  });

  test('caches last-known status so a fresh cold start shows it immediately',
      () async {
    final store = core.Store.memory();
    final adapter = _FakeClaude(const core.ProviderStatus(
      session: core.UsageWindow(usedPct: 40, resetLabel: '2:30am'),
      weekly: core.UsageWindow(usedPct: 10, resetLabel: 'Jul 7 at 7am'),
    ));
    await Engine.withAdapters({core.Provider.claude: adapter}, store: store)
        .load();

    // A new Engine instance sharing the same store (simulating app restart)
    // should show the cached 60% left on its very first emission, before
    // its own live read resolves — not the "…/unknown" placeholder.
    final coldEngine =
        Engine.withAdapters({core.Provider.claude: adapter}, store: store);
    final firstEmission = await coldEngine.watch().first;
    expect(firstEmission.single.session.pct, 60); // 40% used → 60% left
  });

  test('setAutoStart overrides the provider default and is reflected on reload',
      () async {
    final engine = Engine.withAdapters({
      core.Provider.claude: _FakeClaude(const core.ProviderStatus()),
    });
    await engine.load();
    expect(engine.autoStartEnabled('claude-default'), isTrue); // default

    engine.setAutoStart('claude-default', false);
    final a = (await engine.load()).single;
    expect(a.autoStart, isFalse);
  });

  test('addAccount (Codex) runs a hidden login, isolated by CODEX_HOME',
      () async {
    String? hiddenCommand;
    String? ensuredPath;
    final engine = Engine.withAdapters(
      {core.Provider.codex: _FakeClaude(const core.ProviderStatus())},
      runHidden: (cmd) async => hiddenCommand = cmd,
      ensureDir: (path) async => ensuredPath = path,
    );

    await engine.addAccount(Provider.codex, 'work');

    expect(ensuredPath, isNotNull);
    expect(hiddenCommand, contains('CODEX_HOME='));
    expect(hiddenCommand, contains('codex login'));
    expect(hiddenCommand, contains(ensuredPath!));
  });

  test('addAccount (Antigravity) opens a Terminal + prepares its isolated keychain first',
      () async {
    String? hiddenCommand;
    String? terminalCommand;
    final prepared = <(core.Provider, String)>[];
    String? ensuredPath;
    final engine = Engine.withAdapters(
      {core.Provider.antigravity: _FakeClaude(const core.ProviderStatus())},
      runHidden: (cmd) async => hiddenCommand = cmd,
      openTerminal: (cmd) async => terminalCommand = cmd,
      ensureDir: (p) async => ensuredPath = p,
      prepareConfig: (prov, home) async => prepared.add((prov, home)),
    );

    await engine.addAccount(Provider.anti, 'work');

    expect(hiddenCommand, isNull); // TUI, not a hidden browser-OAuth flow
    expect(terminalCommand, contains(' agy'));
    expect(terminalCommand, contains('HOME='));
    // Its own login keychain is prepared BEFORE the login launches.
    expect(prepared.single.$1, core.Provider.antigravity);
    expect(prepared.single.$2, ensuredPath);
  });

  test('addAccount returns null on success', () async {
    final engine = Engine.withAdapters(
      {core.Provider.claude: _FakeClaude(const core.ProviderStatus())},
      runHidden: (_) async {},
      ensureDir: (_) async {},
    );
    expect(await engine.addAccount(Provider.claude, 'work'), isNull);
  });

  test('addAccount reports (not throws) when the login cannot be launched',
      () async {
    final store = core.Store.memory();
    final engine = Engine.withAdapters(
      {core.Provider.claude: _FakeClaude(const core.ProviderStatus())},
      store: store,
      runHidden: (_) async => throw Exception('spawn failed'),
      ensureDir: (_) async {},
    );

    final error = await engine.addAccount(Provider.claude, 'work');

    expect(error, isNotNull);
    // Account is still registered — only the login launch failed.
    expect(store.extraAccounts, hasLength(1));
  });

  test('addAccount reports (not throws) when the config dir cannot be created',
      () async {
    final store = core.Store.memory();
    final engine = Engine.withAdapters(
      {core.Provider.claude: _FakeClaude(const core.ProviderStatus())},
      store: store,
      ensureDir: (_) async => throw Exception('permission denied'),
    );

    final error = await engine.addAccount(Provider.claude, 'work');

    expect(error, isNotNull);
    expect(store.extraAccounts, isEmpty); // never registered
  });

  test('addAccount builds the right login command per provider', () async {
    final commands = <core.Provider, String>{};
    void record(String cmd) {
      if (cmd.contains('CLAUDE_CONFIG_DIR')) commands[core.Provider.claude] = cmd;
      if (cmd.contains('CODEX_HOME')) commands[core.Provider.codex] = cmd;
      if (cmd.contains('HOME=') && !cmd.contains('CODEX_HOME')) {
        commands[core.Provider.antigravity] = cmd;
      }
    }

    final engine = Engine.withAdapters(
      {},
      runHidden: (cmd) async => record(cmd),
      openTerminal: (cmd) async => record(cmd),
    );

    await engine.addAccount(Provider.claude, 'a');
    await engine.addAccount(Provider.codex, 'b');
    await engine.addAccount(Provider.anti, 'c');

    expect(commands[core.Provider.claude], contains('claude auth login'));
    expect(commands[core.Provider.codex], contains('codex login'));
    expect(commands[core.Provider.antigravity], contains(' agy'));
  });

  test('a second Claude account signs in via a private browser window',
      () async {
    final commands = <String>[];
    final engine = Engine.withAdapters(
      {core.Provider.claude: _FakeClaude(const core.ProviderStatus())},
      runHidden: (cmd) async => commands.add(cmd),
      privateBrowserPrefix: () async => 'BROWSER="/x/pb" ',
    );
    await engine.load(); // ambient default Claude account is signed in

    await engine.addAccount(Provider.claude, 'second');

    // The private window has no claude.ai session, so the browser can't
    // silently re-authorize the already-signed-in account.
    expect(commands.single, startsWith('BROWSER="/x/pb" '));
    expect(commands.single, contains('claude auth login'));
  });

  test('the first Claude account keeps the normal browser (session reuse)',
      () async {
    var prefixerCalls = 0;
    String? command;
    final engine = Engine.withAdapters(
      {},
      runHidden: (cmd) async => command = cmd,
      privateBrowserPrefix: () async {
        prefixerCalls++;
        return 'BROWSER="/x/pb" ';
      },
    );

    await engine.addAccount(Provider.claude, 'first');

    expect(prefixerCalls, 0);
    expect(command, isNot(contains('BROWSER=')));
  });

  test('a row removed mid-scan does not reappear in later emissions',
      () async {
    final gate = Completer<core.ProviderStatus>();
    final engine = Engine.withAdapters(
      {core.Provider.claude: _GatedClaude()..gate = gate},
    );

    final emissions = <List<Account>>[];
    final done = Completer<void>();
    engine.watch().listen(emissions.add, onDone: done.complete);

    // Wait for phase 1 (accounts listed, usage read still gated open).
    while (emissions.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(emissions.first.single.id, 'claude-default');

    // Remove while the scan is still loading, then let the read land.
    engine.removeAccount('claude-default');
    gate.complete(const core.ProviderStatus());
    await done.future;

    // The completed read must not resurrect the removed row.
    expect(emissions.last, isEmpty);
  });

  test('removeAccount deletes an extra account\'s isolated config dir', () async {
    String? deleted;
    final store = core.Store.memory();
    final engine = Engine.withAdapters(
      {core.Provider.claude: _FakeClaude(const core.ProviderStatus())},
      store: store,
      runHidden: (_) async {},
      ensureDir: (_) async {},
      deleteDir: (path) => deleted = path,
    );
    await engine.addAccount(Provider.claude, 'work');
    final added = store.extraAccounts.single;

    engine.removeAccount(added.id);

    expect(deleted, added.configHome);
    expect(deleted, startsWith(core.Store.defaultAccountsDir()));
    expect(store.isRemoved(added.id), isTrue);
  });

  test('removeAccount kills the sandbox\'s processes before deleting it',
      () async {
    final killed = <String>[];
    final store = core.Store.memory();
    final engine = Engine.withAdapters(
      {core.Provider.claude: _FakeClaude(const core.ProviderStatus())},
      store: store,
      killSandbox: (home) async => killed.add(home),
    );
    await engine.addAccount(Provider.claude, 'work');
    final added = store.extraAccounts.single;

    engine.removeAccount(added.id);
    await Future<void>.delayed(Duration.zero); // let the unawaited kill land

    expect(killed, [added.configHome]);
  });

  test('removeAccount never deletes the ambient default (null config home)',
      () async {
    var deleteCalls = 0;
    final engine = Engine.withAdapters(
      {core.Provider.claude: _FakeClaude(const core.ProviderStatus())},
      deleteDir: (_) => deleteCalls++,
    );
    await engine.load(); // discovers ambient default (configHome == null)

    engine.removeAccount('claude-default');

    expect(deleteCalls, 0); // nothing on disk to delete for an ambient account
  });

  test('Claude sign-ins run in parallel — a second add keeps the first pending',
      () async {
    var launches = 0;
    final deleted = <String>[];
    final store = core.Store.memory();
    final engine = Engine.withAdapters(
      {core.Provider.claude: _FakeClaude(const core.ProviderStatus())},
      store: store,
      runHidden: (_) async => launches++,
      ensureDir: (_) async {},
      deleteDir: deleted.add,
    );

    expect(await engine.addAccount(Provider.claude, 'one'), isNull);
    expect(await engine.addAccount(Provider.claude, 'two'), isNull);

    // Both attempts stay live: whichever logins the user completes land.
    expect(launches, 2);
    expect(store.extraAccounts, hasLength(2));
    expect(engine.pendingSigninIds(), hasLength(2));
    expect(deleted, isEmpty);
  });

  test('every completed Claude login lands as its own account', () async {
    final store = core.Store.memory();
    final adapter = _ParallelPendingClaude(const core.ProviderStatus());
    final engine =
        Engine.withAdapters({core.Provider.claude: adapter}, store: store);

    await engine.addAccount(Provider.claude, 'one');
    await engine.addAccount(Provider.claude, 'two');
    expect(await engine.pollSignins(), isEmpty); // neither login landed yet

    adapter.extrasLoggedIn = true; // both browser logins complete
    final resolved = await engine.pollSignins();
    expect(resolved, hasLength(2));
    expect(resolved.map((r) => r.state), everyElement(SignInState.ready));
    expect(resolved.map((r) => r.row!.id).toSet(), hasLength(2));
    expect(engine.pendingSigninIds(), isEmpty);
  });

  test('re-adding Codex supersedes its unfinished sign-in (fixed OAuth port)',
      () async {
    var launches = 0;
    final deleted = <String>[];
    final store = core.Store.memory();
    final engine = Engine.withAdapters(
      {core.Provider.codex: _FakeClaude(const core.ProviderStatus())},
      store: store,
      runHidden: (_) async => launches++,
      ensureDir: (_) async {},
      deleteDir: deleted.add,
    );

    expect(await engine.addAccount(Provider.codex, 'one'), isNull);
    final first = store.extraAccounts.single.id;

    // Only one `codex login` can listen on its callback port — the second
    // add clears the abandoned first attempt (and its dir) and proceeds.
    expect(await engine.addAccount(Provider.codex, 'two'), isNull);
    expect(launches, 2);
    expect(store.extraAccounts, hasLength(1)); // only the new one remains
    expect(store.extraAccounts.single.label, 'two');
    expect(store.isRemoved(first), isTrue);
    expect(deleted, contains(startsWith(core.Store.defaultAccountsDir())));
  });

  test('the first-ever read gets the cold timeout; cached accounts do not',
      () async {
    final store = core.Store.memory();
    final engine = Engine.withAdapters(
      {core.Provider.claude: _FakeClaude(const core.ProviderStatus())},
      store: store,
    );

    final cold = engine.readTimeoutFor('claude-fresh');
    store.cacheStatus('claude-fresh', const core.ProviderStatus());
    final warm = engine.readTimeoutFor('claude-fresh');

    expect(cold, greaterThan(warm)); // room for the CLI's cold start
    expect(warm, const Duration(seconds: 30));
  });

  test('a pending added mid-scan survives the scan (login still lands)',
      () async {
    final store = core.Store.memory();
    final adapter = _ParallelPendingClaude(const core.ProviderStatus());
    final engine =
        Engine.withAdapters({core.Provider.claude: adapter}, store: store);

    // Scan blocks inside discovery's detect — after it has already read the
    // store's extras — while the user adds an account.
    adapter.detectGate = Completer<void>();
    final scan = engine.watch().drain<void>();
    await Future<void>.delayed(Duration.zero); // let the scan reach detect
    await engine.addAccount(Provider.claude, 'work');
    adapter.detectGate!.complete();
    adapter.detectGate = null;
    await scan;

    // The scan's stale snapshot must not orphan the new pending — the poll
    // keeps watching it, so the completed login lands.
    expect(engine.pendingSigninIds(), hasLength(1));
    adapter.extrasLoggedIn = true;
    final resolved = await engine.pollSignins();
    expect(resolved.single.state, SignInState.ready);
  });

  test('a pending account is NOT a visible row; it appears only once signed in',
      () async {
    final store = core.Store.memory()
      ..addExtraAccount(core.ExtraAccount(
        id: 'claude-work',
        provider: core.Provider.claude,
        label: 'work',
        configHome: '/tmp/wakieai-test-claude-work',
        addedAt: DateTime.now(), // recent — not past the sign-in timeout
      ));
    final adapter = _PendingClaude(const core.ProviderStatus(
      session: core.UsageWindow(usedPct: 40, resetLabel: '2:30am'),
      weekly: core.UsageWindow(usedPct: 10, resetLabel: 'Jul 7 at 7am'),
    ));
    final engine =
        Engine.withAdapters({core.Provider.claude: adapter}, store: store);

    // Before login lands: the pending account is invisible (no flicker), but
    // tracked so it can be polled.
    final rows = await engine.load();
    expect(rows.where((a) => a.id == 'claude-work'), isEmpty);
    expect(engine.pendingSigninIds(), contains('claude-work'));

    // Poll while still pending → nothing resolves, still invisible.
    expect(await engine.pollSignins(), isEmpty);
    expect(engine.pendingSigninIds(), contains('claude-work'));

    // User finishes login → poll resolves it to a row that appears at once
    // (with its identity), no longer pending. Live usage is filled by the
    // follow-up refresh, not inline, so the row shows up instantly.
    adapter.extraLoggedIn = true;
    final resolved = await engine.pollSignins();
    expect(resolved, hasLength(1));
    expect(resolved.single.state, SignInState.ready);
    final row = resolved.single.row!;
    expect(row.status, isNot(RunStatus.signin));
    expect(row.plan, 'work@b.com · Pro');
    expect(engine.pendingSigninIds(), isEmpty);

    // The follow-up refresh fills live usage.
    final refreshed = await engine.refreshAccount('claude-work');
    expect(refreshed!.session.pct, 60); // 40% used → 60% left
  });

  test('pollSignins expires (removes) a sign-in pending longer than the timeout',
      () async {
    String? deleted;
    final store = core.Store.memory()
      ..addExtraAccount(core.ExtraAccount(
        id: 'claude-stale',
        provider: core.Provider.claude,
        label: 'stale',
        configHome: '${core.Store.defaultAccountsDir()}/claude-stale',
        // Added 20 minutes ago — well past the sign-in timeout, and STILL not
        // signed in, so it's treated as abandoned.
        addedAt: DateTime.now().subtract(const Duration(minutes: 20)),
      ));
    final adapter = _CountingPendingClaude(() {});
    final engine = Engine.withAdapters({core.Provider.claude: adapter},
        store: store, deleteDir: (p) => deleted = p);

    await engine.load();
    final resolved = await engine.pollSignins();

    expect(resolved.single.state, SignInState.expired);
    expect(resolved.single.message, contains('timed out'));
    expect(store.isRemoved('claude-stale'), isTrue);
    expect(deleted, '${core.Store.defaultAccountsDir()}/claude-stale');
    expect(engine.pendingSigninIds(), isEmpty);
  });

  test('isProviderInstalled reflects the adapter detect', () async {
    final installed = Engine.withAdapters(
        {core.Provider.claude: _FakeClaude(const core.ProviderStatus())});
    expect(await installed.isProviderInstalled(Provider.claude), isTrue);

    final missing =
        Engine.withAdapters({core.Provider.claude: _NotInstalledClaude()});
    expect(await missing.isProviderInstalled(Provider.claude), isFalse);
  });

  test('pollSignins drops a pending sign-in at once when the CLI is missing',
      () async {
    // The login launch died as "command not found" — without this, the user
    // would wait out the full 15-minute timeout in silence.
    String? deleted;
    final store = core.Store.memory()
      ..addExtraAccount(core.ExtraAccount(
        id: 'claude-nocli',
        provider: core.Provider.claude,
        label: 'nocli',
        configHome: '${core.Store.defaultAccountsDir()}/claude-nocli',
        addedAt: DateTime.now(), // recent — NOT past the sign-in timeout
      ));
    final engine = Engine.withAdapters(
        {core.Provider.claude: _NotInstalledClaude()},
        store: store, deleteDir: (p) => deleted = p);

    await engine.load();
    final resolved = await engine.pollSignins();

    expect(resolved.single.state, SignInState.expired);
    expect(resolved.single.message, contains('not installed'));
    expect(store.isRemoved('claude-nocli'), isTrue);
    expect(deleted, '${core.Store.defaultAccountsDir()}/claude-nocli');
    expect(engine.pendingSigninIds(), isEmpty);
  });

  test('a landed account is never removed when its CLI goes missing',
      () async {
    // The account signed in and has cached usage — then the CLI was
    // uninstalled (or a brew upgrade broke it). That's a machine condition to
    // wait out, not an abandoned sign-in: the sandbox (and the login in it)
    // must survive.
    final store = core.Store.memory()
      ..addExtraAccount(core.ExtraAccount(
        id: 'claude-real',
        provider: core.Provider.claude,
        label: 'real',
        configHome: '${core.Store.defaultAccountsDir()}/claude-real',
        addedAt: DateTime.now().subtract(const Duration(days: 3)),
      ))
      ..cacheStatus(
          'claude-real',
          const core.ProviderStatus(
              weekly: core.UsageWindow(usedPct: 10, resetLabel: 'Jul 7')));
    final engine = Engine.withAdapters(
        {core.Provider.claude: _NotInstalledClaude()},
        store: store);

    await engine.load();
    expect(await engine.pollSignins(), isEmpty); // waits — never resolves
    expect(store.isRemoved('claude-real'), isFalse);
    expect(engine.pendingSigninIds(), contains('claude-real'));
  });

  test('a landed account whose login is lost is not timeout-removed',
      () async {
    // Same principle for a lost login (keychain hiccup, logged out in the
    // sandbox): the 15-minute expiry is for sign-ins that never landed.
    final store = core.Store.memory()
      ..addExtraAccount(core.ExtraAccount(
        id: 'claude-landed',
        provider: core.Provider.claude,
        label: 'landed',
        configHome: '${core.Store.defaultAccountsDir()}/claude-landed',
        addedAt: DateTime.now().subtract(const Duration(minutes: 20)),
      ))
      ..cacheStatus(
          'claude-landed',
          const core.ProviderStatus(
              weekly: core.UsageWindow(usedPct: 10, resetLabel: 'Jul 7')));
    final engine = Engine.withAdapters(
        {core.Provider.claude: _PendingClaude(const core.ProviderStatus())},
        store: store);

    await engine.load();
    expect(await engine.pollSignins(), isEmpty);
    expect(store.isRemoved('claude-landed'), isFalse);
  });

  test('a past-timeout account that just finished signing in is NOT expired',
      () async {
    // Login completed slowly (past the timeout) — it must resolve to a real
    // account, never be wrongly removed.
    final store = core.Store.memory()
      ..addExtraAccount(core.ExtraAccount(
        id: 'claude-slow',
        provider: core.Provider.claude,
        label: 'slow',
        configHome: '/tmp/wakieai-test-claude-slow',
        addedAt: DateTime.now().subtract(const Duration(minutes: 20)),
      ));
    final adapter = _PendingClaude(const core.ProviderStatus());
    final engine =
        Engine.withAdapters({core.Provider.claude: adapter}, store: store);

    await engine.load(); // still pending at load time (not signed in yet)
    adapter.extraLoggedIn = true; // login finishes now — late, past timeout
    final resolved = await engine.pollSignins();

    expect(resolved.single.state, SignInState.ready); // resolved, not expired
    expect(store.isRemoved('claude-slow'), isFalse);
  });

  test('pollSignins drops a duplicate login without ever showing a row',
      () async {
    // Ambient default (a@b.com) already managed; the extra logs into the same
    // email → duplicate, dropped silently (never becomes a row).
    final store = core.Store.memory()
      ..addExtraAccount(core.ExtraAccount(
        id: 'claude-dup',
        provider: core.Provider.claude,
        label: 'dup',
        configHome: '/tmp/wakieai-test-claude-dup',
        addedAt: DateTime.now(), // recent — not past the sign-in timeout
      ));
    final adapter =
        _PendingClaude(const core.ProviderStatus(), extraEmail: 'a@b.com');
    final engine =
        Engine.withAdapters({core.Provider.claude: adapter}, store: store);

    final rows = await engine.load(); // ambient default + invisible pending
    expect(rows.where((a) => a.id == 'claude-dup'), isEmpty);

    adapter.extraLoggedIn = true; // extra logs in — but as a@b.com too
    final resolved = await engine.pollSignins();

    expect(resolved, hasLength(1));
    expect(resolved.single.state, SignInState.duplicate);
    expect(resolved.single.message, contains('already added'));
    expect(store.isRemoved('claude-dup'), isTrue);
    expect(engine.pendingSigninIds(), isEmpty);
  });

  group('awakeTick', () {
    // A cached status whose session window lapsed 5 minutes ago.
    core.Status lapsed(String id) => core.Status(
          accountId: id,
          session: core.UsageWindow(
              usedPct: 100,
              resetAt: DateTime.now().subtract(const Duration(minutes: 5))),
          weekly: const core.UsageWindow(usedPct: 10),
          lastOutcome: core.Outcome.ok,
          lastCheckedAt: DateTime.now().subtract(const Duration(hours: 1)),
        );

    test('lapsed window + auto-start on → chains a new session', () async {
      final adapter = _CountingClaude(const core.ProviderStatus(
          session: core.UsageWindow(usedPct: 0, resetLabel: '8:00pm')));
      final store = core.Store.memory();
      final engine = Engine.withAdapters({core.Provider.claude: adapter},
          store: store);
      await engine.load(); // Claude defaults auto-start ON
      store.saveStatus(lapsed('claude-default'));

      final changed = await engine.awakeTick();

      expect(changed.map((r) => r.id), ['claude-default']);
      expect(adapter.starts, 1); // a new session was started
      expect(store.statusFor('claude-default')!.session.usedPct, 0); // re-read
      // The returned row is built from the just-cached status — the caller
      // must not re-scrape it (that would erase the failure backoff).
      expect(changed.single.session.pct, 100); // 0% used → 100% left
    });

    test('a label-only lapsed window (Claude/agy shape) still chains', () async {
      // Claude and Antigravity parsers emit resetLabel only, never an
      // absolute resetAt. Regression: the chain used to re-anchor the label
      // to the current clock, roll it into the future, and silently skip.
      final adapter = _CountingClaude(const core.ProviderStatus(
          session: core.UsageWindow(usedPct: 0, resetLabel: '8:00pm')));
      final store = core.Store.memory();
      final engine = Engine.withAdapters({core.Provider.claude: adapter},
          store: store);
      await engine.load(); // Claude defaults auto-start ON
      final readAt = DateTime.now().subtract(const Duration(hours: 20));
      // A clock label rendering readAt+1min: anchored at readAt it resolves
      // ~20h in the past (lapsed); re-anchored at DateTime.now() it would
      // roll to the future — exactly the regression this test pins down.
      final t = readAt.add(const Duration(minutes: 1));
      final label = '${t.hour % 12 == 0 ? 12 : t.hour % 12}:'
          '${t.minute.toString().padLeft(2, '0')}${t.hour < 12 ? 'am' : 'pm'}';
      store.saveStatus(core.Status(
        accountId: 'claude-default',
        session: core.UsageWindow(usedPct: 100, resetLabel: label),
        weekly: const core.UsageWindow(usedPct: 10),
        lastOutcome: core.Outcome.ok,
        lastCheckedAt: readAt,
      ));

      final changed = await engine.awakeTick();

      expect(changed.map((r) => r.id), ['claude-default']);
      expect(adapter.starts, 1); // the chain actually fired
    });

    test('lapsed window + auto-start OFF → refreshes only, never starts', () async {
      final adapter = _CountingClaude(const core.ProviderStatus(
          session: core.UsageWindow(usedPct: 3, resetLabel: '8:00pm')));
      final store = core.Store.memory()
        ..setAutoStart('claude-default', false);
      final engine = Engine.withAdapters({core.Provider.claude: adapter},
          store: store);
      await engine.load();
      final readsAfterLoad = adapter.reads;
      store.saveStatus(lapsed('claude-default'));

      final changed = await engine.awakeTick();

      expect(changed.map((r) => r.id), ['claude-default']);
      expect(adapter.starts, 0); // read-only: no session consumed
      expect(adapter.reads, readsAfterLoad + 1);
      expect(store.statusFor('claude-default')!.session.usedPct, 3);
    });

    test('window still ahead → nothing happens (no subprocess)', () async {
      final adapter = _CountingClaude(const core.ProviderStatus());
      final store = core.Store.memory();
      final engine = Engine.withAdapters({core.Provider.claude: adapter},
          store: store);
      await engine.load();
      final readsAfterLoad = adapter.reads;
      store.saveStatus(core.Status(
        accountId: 'claude-default',
        session: core.UsageWindow(
            usedPct: 40, resetAt: DateTime.now().add(const Duration(hours: 2))),
        lastCheckedAt: DateTime.now(),
      ));

      expect(await engine.awakeTick(), isEmpty);
      expect(adapter.starts, 0);
      expect(adapter.reads, readsAfterLoad);
    });

    test('a recently failed start is not retried every tick', () async {
      final adapter = _CountingClaude(const core.ProviderStatus());
      final store = core.Store.memory();
      final engine = Engine.withAdapters({core.Provider.claude: adapter},
          store: store);
      await engine.load();
      store.saveStatus(core.Status(
        accountId: 'claude-default',
        session: core.UsageWindow(
            usedPct: 100,
            resetAt: DateTime.now().subtract(const Duration(minutes: 5))),
        lastOutcome: core.Outcome.failed,
        lastStartedAt: DateTime.now().subtract(const Duration(minutes: 2)),
        lastCheckedAt: DateTime.now().subtract(const Duration(minutes: 2)),
      ));

      expect(await engine.awakeTick(), isEmpty);
      expect(adapter.starts, 0); // backing off after the recent failure
    });
  });

  group('concurrency guards', () {
    test('a second read of the same account is refused while one is in flight',
        () async {
      final adapter = _GatedClaude();
      final store = core.Store.memory()
        ..setAutoStart('claude-default', false);
      final engine = Engine.withAdapters({core.Provider.claude: adapter},
          store: store);
      await engine.load();
      store.saveStatus(core.Status(
        accountId: 'claude-default',
        session: core.UsageWindow(
            usedPct: 100,
            resetAt: DateTime.now().subtract(const Duration(minutes: 5))),
        lastCheckedAt: DateTime.now().subtract(const Duration(hours: 1)),
      ));

      adapter.gate = Completer<core.ProviderStatus>(); // block the tick's read
      final tick = engine.awakeTick();
      await Future<void>.delayed(Duration.zero); // let the tick reach the read

      // Update on the same account while the tick holds it → refused, no
      // second pty scrape on the same config home.
      expect(await engine.refreshAccount('claude-default'), isNull);

      adapter.gate!.complete(const core.ProviderStatus(
          session: core.UsageWindow(usedPct: 0, resetLabel: '8:00pm')));
      adapter.gate = null;
      expect((await tick).map((r) => r.id), ['claude-default']);

      // Once released, Update works again.
      expect(await engine.refreshAccount('claude-default'), isNotNull);
    });

    test('awakeTick skips a pass while a full scan is in flight', () async {
      final adapter = _GatedClaude();
      final store = core.Store.memory();
      final engine = Engine.withAdapters({core.Provider.claude: adapter},
          store: store);
      store.saveStatus(core.Status(
        accountId: 'claude-default',
        session: core.UsageWindow(
            usedPct: 100,
            resetAt: DateTime.now().subtract(const Duration(minutes: 5))),
        lastCheckedAt: DateTime.now().subtract(const Duration(hours: 1)),
      ));

      adapter.gate = Completer<core.ProviderStatus>(); // hold phase-2 reads
      final scan = engine.watch().last;
      await Future<void>.delayed(Duration.zero); // scan discovers, then reads

      expect(await engine.awakeTick(), isEmpty); // deferred to the scan

      adapter.gate!.complete(const core.ProviderStatus(
          session: core.UsageWindow(usedPct: 0, resetLabel: '8:00pm')));
      adapter.gate = null;
      await scan;
    });
  });

  test('setLaunchAtLogin persists and installs/removes the login item', () async {
    final calls = <bool>[];
    final store = core.Store.memory();
    final engine = Engine.withAdapters({},
        store: store, installLoginItem: (on) async => calls.add(on));

    await engine.setLaunchAtLogin(true);
    expect(engine.launchAtLogin, isTrue);
    expect(store.launchAtLogin, isTrue);

    await engine.setLaunchAtLogin(false);
    expect(engine.launchAtLogin, isFalse);
    expect(calls, [true, false]);
  });

  test('a row with unknown usage is not badged LOW (loading, not empty)',
      () async {
    final engine = Engine.withAdapters(
        {core.Provider.claude: _FakeClaude(core.ProviderStatus.unknown)});

    final rows = await engine.load();

    expect(rows.single.session.known, isFalse);
    expect(rows.single.status, RunStatus.ok);
  });

  group('setDarkWake', () {
    test('on → configures the wake at the anchor and persists', () async {
      final calls = <(bool, int, int)>[];
      final store = core.Store.memory()..setMorningAnchor(7, 30);
      final engine = Engine.withAdapters({},
          store: store, configureDarkWake: (e, h, m) async {
        calls.add((e, h, m));
        return null;
      });

      final err = await engine.setDarkWake(true);

      expect(err, isNull);
      expect(calls, [(true, 7, 30)]);
      expect(engine.darkWake, isTrue);
    });

    test('off → configures removal and persists', () async {
      final calls = <(bool, int, int)>[];
      final store = core.Store.memory()..setDarkWake(true);
      final engine = Engine.withAdapters({},
          store: store, configureDarkWake: (e, h, m) async {
        calls.add((e, h, m));
        return null;
      });

      await engine.setDarkWake(false);

      expect(calls.single.$1, isFalse);
      expect(engine.darkWake, isFalse);
    });

    test('a cancelled/failed configure leaves stored state unchanged', () async {
      final store = core.Store.memory();
      final engine = Engine.withAdapters({},
          store: store, configureDarkWake: (_, _, _) async => 'Cancelled.');

      final err = await engine.setDarkWake(true);

      expect(err, 'Cancelled.');
      expect(engine.darkWake, isFalse); // not persisted on failure
    });
  });

  group('setMorningAnchor with dark wake enabled', () {
    test('reprograms the schedule to the new time', () async {
      final calls = <(bool, int, int)>[];
      final store = core.Store.memory()..setDarkWake(true);
      final engine = Engine.withAdapters({},
          store: store, configureDarkWake: (e, h, m) async {
        calls.add((e, h, m));
        return null;
      });

      final err = await engine.setMorningAnchor(6, 30);

      expect(err, isNull);
      expect(calls, [(true, 6, 30)]);
      expect(engine.morningAnchorHour, 6);
    });

    test('a cancelled reprogram reverts the anchor', () async {
      final store = core.Store.memory()..setDarkWake(true);
      final engine = Engine.withAdapters({},
          store: store, configureDarkWake: (_, _, _) async => 'Cancelled.');

      final err = await engine.setMorningAnchor(6, 30);

      expect(err, 'Cancelled.');
      expect(engine.morningAnchorHour, 8); // reverted to the default
    });

    test('dark wake off → anchor persists without touching the schedule',
        () async {
      var configured = 0;
      final engine = Engine.withAdapters({}, configureDarkWake: (_, _, _) async {
        configured++;
        return null;
      });

      await engine.setMorningAnchor(6, 30);

      expect(configured, 0);
      expect(engine.morningAnchorHour, 6);
    });
  });

  test('morning anchor defaults to 8:00am and setMorningAnchor persists via the store',
      () async {
    final store = core.Store.memory();
    final engine = Engine.withAdapters({}, store: store);

    expect(engine.morningAnchorHour, 8);
    expect(engine.morningAnchorMinute, 0);

    await engine.setMorningAnchor(7, 15);
    expect(engine.morningAnchorHour, 7);
    expect(engine.morningAnchorMinute, 15);
    expect(store.morningAnchorHour, 7); // same store, reflected immediately
  });
}
