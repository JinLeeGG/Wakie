import 'dart:io';

import 'package:wakie_core/wakie_core.dart';

/// Headless one-shot runner (PRD §9.2, Phase 1 dark wake). Discovers
/// logged-in accounts, reads each one's live usage, chains a fresh session
/// for any account whose window has lapsed (auto-start), fires macOS
/// notifications for threshold/failure alerts, and caches everything in the
/// local store — no Flutter/GUI involved, so this can run from a LaunchAgent
/// during a dark wake (when the windowed app can't). The Mac GUI picks up
/// the cached status on its next cold start.
Future<void> main() async {
  // Decide up front whether anyone is at the machine: an RTC wake is always
  // a full wake (screen on), so an unattended pass keeps the display dark
  // while it works and puts the Mac back to sleep when done. Attended runs
  // (user awake at the anchor time) touch neither.
  final wokeAt = await lastWakeAt();
  Future<bool> unattended() async => unattendedWake(
      now: DateTime.now(), wokeAt: wokeAt, idleSeconds: await hidIdleSeconds());
  final darkPass = await unattended();
  if (darkPass) await displaySleep();

  try {
    // A previous life (app quit / crashed runner) can leave a scrape's CLI
    // orphaned in its sandbox config — kill those before spawning new ones.
    await killOrphanedSandboxScrapes();

    final adapters = productionAdapters();
    final store = Store.load();

    final live = await discoverLiveAccounts(adapters, store);
    if (live.isEmpty) {
      print('wakie: no logged-in accounts found');
      return;
    }

    // Snapshot pre-run status so alerts can be edge-triggered against it,
    // then do the plain read pass (chaining below may refine some of these).
    final previous = {for (final (a, _) in live) a.id: store.statusFor(a.id)};

    final read = <(Account, Preflight, ProviderStatus)>[];
    await Future.wait([
      for (final (account, preflight) in live)
        _readPrepared(adapters, account).then((status) {
          store.cacheStatus(account.id, status);
          read.add((account, preflight, status));
          print('wakie: ${account.id} — '
              'session ${status.session.usedPct ?? '?'}% used, '
              'weekly ${status.weekly.usedPct ?? '?'}% used');
        }),
    ]);

    await chainExpiredSessions(adapters, store, read, log: print);

    for (final (account, _, _) in read) {
      final current = store.statusFor(account.id)!; // chaining may have refreshed it
      final alerts =
          evaluateAlerts(account.id, previous[account.id], current);
      for (final alert in alerts) {
        print('wakie: alert — ${alert.message}');
        await showMacNotification('Wakie', alert.message);
      }
    }

    print('wakie: updated ${read.length}/${live.length} account(s)');
  } catch (e, st) {
    stderr.writeln('wakie: runner failed: $e\n$st');
    exitCode = 1;
  } finally {
    // Whatever happened above, don't leave an unattended Mac awake all
    // night — but only if the user still hasn't touched it mid-pass.
    if (darkPass && await unattended()) {
      print('wakie: unattended wake — going back to sleep');
      final err = await systemSleep();
      if (err != null) print('wakie: could not re-sleep — $err');
    }
  }
}

/// Makes an isolated config home ready before its read, mirroring the app's
/// engine: Claude skips onboarding/trust; Antigravity re-unlocks its sandbox
/// keychain (locked again after a reboot, and agy pops the system "Keychain
/// Not Found"/unlock dialog instead of rendering /usage without it).
Future<ProviderStatus> _readPrepared(
    Map<Provider, ProviderAdapter> adapters, Account account) async {
  final home = account.configHome;
  if (home != null) {
    switch (account.provider) {
      case Provider.claude:
        await prepareClaudeConfigHome(home);
      case Provider.antigravity:
        await prepareAntigravityConfigHome(home);
      case Provider.codex:
        break; // CODEX_HOME files need no preparation
    }
  }
  return adapters[account.provider]!.readStatus(account);
}
