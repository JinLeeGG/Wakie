import 'dart:io';

import 'package:wakieai_core/wakieai_core.dart';

/// Headless one-shot runner (PRD §9.2, Phase 1 dark wake). Discovers
/// logged-in accounts, reads each one's live usage, chains a fresh session
/// for any account whose window has lapsed (auto-start), fires macOS
/// notifications for threshold/failure alerts, and caches everything in the
/// local store — no Flutter/GUI involved, so this can run from a LaunchAgent
/// during a dark wake (when the windowed app can't). The Mac GUI picks up
/// the cached status on its next cold start.
Future<void> main() async {
  try {
    final adapters = productionAdapters();
    final store = Store.load();

    final live = await discoverLiveAccounts(adapters, store);
    if (live.isEmpty) {
      print('wakieai: no logged-in accounts found');
      return;
    }

    // Snapshot pre-run status so alerts can be edge-triggered against it,
    // then do the plain read pass (chaining below may refine some of these).
    final previous = {for (final (a, _) in live) a.id: store.statusFor(a.id)};

    final read = <(Account, Preflight, ProviderStatus)>[];
    await Future.wait([
      for (final (account, preflight) in live)
        adapters[account.provider]!.readStatus(account).then((status) {
          store.cacheStatus(account.id, status);
          read.add((account, preflight, status));
          print('wakieai: ${account.id} — '
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
        print('wakieai: alert — ${alert.message}');
        await showMacNotification('WakieAI', alert.message);
      }
    }

    print('wakieai: updated ${read.length}/${live.length} account(s)');
  } catch (e, st) {
    stderr.writeln('wakieai: runner failed: $e\n$st');
    exitCode = 1;
  }
}
