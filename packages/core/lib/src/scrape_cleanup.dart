import 'dart:io';

import 'store.dart';

/// Kills leftover scrape processes (`agy`, `claude`) from a previous
/// app/runner life.
///
/// A pty capture SIGKILLs its child on dispose, but the hosting process can
/// die first (app quit or hot restart mid-scan) — the orphaned scrape then
/// runs forever with its sandbox environment and, for agy in a home with no
/// keychain, pops the system "Keychain Not Found" dialog on every token
/// store it attempts. Only processes whose environment carries a
/// `<accounts root>/…` config path are touched — that path exists only
/// because we set it, so this can never hit the user's own sessions. And
/// only processes re-parented to launchd (ppid 1, or a `script` pty wrapper
/// that is) are killed, so an in-flight scrape owned by a live app/runner is
/// always safe. Best-effort: returns the number killed.
Future<int> killOrphanedSandboxScrapes({String? accountsRoot}) async {
  try {
    // BSD-style `e` (no dash) appends each process's environment to its
    // command line; the POSIX `-e` form silently omits it on macOS.
    final ps = await Process.run('ps', ['axeww', '-o', 'pid=,ppid=,command=']);
    if (ps.exitCode != 0) return 0;
    final pids = orphanedSandboxScrapePids(
      ps.stdout as String,
      accountsRoot: accountsRoot ?? Store.defaultAccountsDir(),
    );
    for (final pid in pids) {
      Process.killPid(pid, ProcessSignal.sigkill);
    }
    return pids.length;
  } catch (_) {
    return 0; // cleanup must never break startup
  }
}

/// Parses `ps axeww -o pid=,ppid=,command=` output into the pids of orphaned
/// sandbox scrapes. Pure, for tests.
///
/// A process qualifies when its environment points into [accountsRoot]
/// (`HOME=` for agy, `CLAUDE_CONFIG_DIR=` for claude), its argv0 is the
/// matching CLI, and it is orphaned: re-parented to pid 1 directly, or a
/// child of a `script` pty wrapper that is. Qualifying `script` parents are
/// killed too (their own env is a platform binary's, which ps redacts, so
/// they can only be found through their child).
List<int> orphanedSandboxScrapePids(String psOutput,
    {required String accountsRoot}) {
  final line = RegExp(r'^\s*(\d+)\s+(\d+)\s+(\S+)');
  // pid -> (ppid, argv0) for every process, so parents can be looked up.
  final procs = <int, (int, String)>{};
  final candidates = <(int, int)>[]; // (pid, ppid) of marker-matched scrapes
  for (final l in psOutput.split('\n')) {
    final m = line.firstMatch(l);
    if (m == null) continue;
    final pid = int.parse(m.group(1)!);
    final ppid = int.parse(m.group(2)!);
    final argv0 = m.group(3)!;
    procs[pid] = (ppid, argv0);
    final name = argv0.split('/').last;
    final marker = switch (name) {
      'agy' => 'HOME=$accountsRoot/',
      'claude' => 'CLAUDE_CONFIG_DIR=$accountsRoot/',
      _ => null,
    };
    if (marker == null || !l.contains(marker)) continue;
    candidates.add((pid, ppid));
  }

  final pids = <int>[];
  for (final (pid, ppid) in candidates) {
    if (ppid == 1) {
      pids.add(pid);
      continue;
    }
    // A pty capture runs the CLI under `script`; when the host dies it is
    // the wrapper that re-parents to launchd, not the CLI itself.
    final parent = procs[ppid];
    if (parent != null &&
        parent.$2.split('/').last == 'script' &&
        parent.$1 == 1) {
      pids.add(ppid);
      pids.add(pid);
    }
  }
  return pids;
}
