import 'dart:io';

import 'package:test/test.dart';
import 'package:wakie_core/wakie_core.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('wakie_store_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  String path() => '${tmp.path}/store.json';

  test('missing file loads as empty store', () {
    final store = Store.load(path());
    expect(store.isRemoved('claude-default'), isFalse);
    expect(store.statusFor('claude-default'), isNull);
  });

  test('corrupt file loads as empty store instead of throwing', () {
    File(path()).writeAsStringSync('not json');
    final store = Store.load(path());
    expect(store.isRemoved('claude-default'), isFalse);
  });

  test('removed account survives reload from the same path', () {
    Store.load(path()).removeAccount('claude-default');

    final reloaded = Store.load(path());
    expect(reloaded.isRemoved('claude-default'), isTrue);
    expect(reloaded.isRemoved('codex-default'), isFalse);
  });

  test('saved status round-trips through reload', () {
    final status = Status(
      accountId: 'codex-default',
      session: UsageWindow(
          usedPct: 40, resetAt: DateTime.utc(2026, 6, 1, 15, 30)),
      weekly: const UsageWindow(usedPct: 10, resetLabel: 'Jul 7 at 7am'),
      lastStartedAt: DateTime.utc(2026, 6, 1, 10),
      lastOutcome: Outcome.ok,
      lastCheckedAt: DateTime.utc(2026, 6, 1, 15, 31),
    );
    Store.load(path()).saveStatus(status);

    final reloaded = Store.load(path()).statusFor('codex-default')!;
    expect(reloaded.session.usedPct, 40);
    expect(reloaded.session.resetAt, DateTime.utc(2026, 6, 1, 15, 30));
    expect(reloaded.weekly.usedPct, 10);
    expect(reloaded.weekly.resetLabel, 'Jul 7 at 7am');
    expect(reloaded.lastStartedAt, DateTime.utc(2026, 6, 1, 10));
    expect(reloaded.lastOutcome, Outcome.ok);
    expect(reloaded.lastCheckedAt, DateTime.utc(2026, 6, 1, 15, 31));
  });

  test('cacheStatus wraps a live ProviderStatus with now + ok outcome', () {
    final store = Store.memory();
    const status = ProviderStatus(
      session: UsageWindow(usedPct: 40, resetLabel: '2:30am'),
      weekly: UsageWindow(usedPct: 10, resetLabel: 'Jul 7 at 7am'),
    );

    store.cacheStatus('claude-default', status);

    final cached = store.statusFor('claude-default')!;
    expect(cached.session.usedPct, 40);
    expect(cached.weekly.usedPct, 10);
    expect(cached.lastOutcome, Outcome.ok);
    expect(cached.lastCheckedAt, isNotNull);
  });

  test('memory store never touches disk', () {
    final store = Store.memory();
    store.removeAccount('claude-default');
    expect(store.isRemoved('claude-default'), isTrue);
    expect(File(path()).existsSync(), isFalse);
  });

  test('autoStart preference survives reload; unset stays null', () {
    Store.load(path()).setAutoStart('claude-default', false);

    final reloaded = Store.load(path());
    expect(reloaded.autoStartPreference('claude-default'), isFalse);
    expect(reloaded.autoStartPreference('codex-default'), isNull);
  });

  test('launchAtLogin defaults off and survives reload', () {
    final fresh = Store.load(path());
    expect(fresh.launchAtLogin, isFalse);

    fresh.setLaunchAtLogin(true);
    expect(Store.load(path()).launchAtLogin, isTrue);
  });

  test('darkWake defaults off and survives reload', () {
    final fresh = Store.load(path());
    expect(fresh.darkWake, isFalse);

    fresh.setDarkWake(true);
    expect(Store.load(path()).darkWake, isTrue);
  });

  test('morning anchor defaults to 8:00am and survives reload', () {
    final fresh = Store.load(path());
    expect(fresh.morningAnchorHour, 8);
    expect(fresh.morningAnchorMinute, 0);

    fresh.setMorningAnchor(7, 30);
    final reloaded = Store.load(path());
    expect(reloaded.morningAnchorHour, 7);
    expect(reloaded.morningAnchorMinute, 30);
  });

  test('removeAccount deletes an extra account and prevents rediscovery', () {
    final store = Store.load(path());
    store.addExtraAccount(ExtraAccount(
      id: 'claude-work',
      provider: Provider.claude,
      label: 'work',
      configHome: '/tmp/x',
      addedAt: DateTime.utc(2026),
    ));

    final reloaded = Store.load(path());
    reloaded.removeAccount('claude-work');

    final again = Store.load(path());
    expect(again.extraAccounts, isEmpty);
    expect(again.isRemoved('claude-work'), isTrue);
  });

  test('extra accounts survive reload and re-add replaces by id', () {
    final store = Store.load(path());
    store.addExtraAccount(ExtraAccount(
      id: 'claude-work',
      provider: Provider.claude,
      label: 'work',
      configHome: '/Users/x/.wakie/claude-work',
      addedAt: DateTime.utc(2026, 6, 1),
    ));

    var reloaded = Store.load(path());
    expect(reloaded.extraAccounts, hasLength(1));
    expect(reloaded.extraAccounts.single.label, 'work');

    // Re-adding the same id updates in place rather than duplicating.
    reloaded.addExtraAccount(ExtraAccount(
      id: 'claude-work',
      provider: Provider.claude,
      label: 'work-relabeled',
      configHome: '/Users/x/.wakie/claude-work',
      addedAt: DateTime.utc(2026, 6, 1),
    ));
    reloaded = Store.load(path());
    expect(reloaded.extraAccounts, hasLength(1));
    expect(reloaded.extraAccounts.single.label, 'work-relabeled');
  });
}
