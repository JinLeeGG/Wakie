import 'dart:io';

import 'store.dart';

/// Kills leftover `agy` scrape processes from a previous app/runner life.
///
/// A pty capture SIGKILLs its child on dispose, but the hosting process can
/// die first (app quit or hot restart mid-scan) — the orphaned agy then runs
/// forever with its sandbox HOME and, when that home has no keychain, pops
/// the system "Keychain Not Found" dialog on every token store it attempts.
/// Only processes whose environment carries `HOME=<accounts root>/…` are
/// touched — that HOME exists only because we set it, so this can never hit
/// the user's own agy session. Best-effort: returns the number killed.
Future<int> killOrphanedSandboxAgys({String? accountsRoot}) async {
  try {
    // `-e` appends each process's environment to its command line.
    final ps = await Process.run('ps', ['-axeww', '-o', 'pid=,command=']);
    if (ps.exitCode != 0) return 0;
    final pids = orphanedSandboxAgyPids(
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

/// Parses `ps -axeww -o pid=,command=` output into the pids of `agy`
/// processes running with a HOME inside [accountsRoot]. Pure, for tests.
List<int> orphanedSandboxAgyPids(String psOutput,
    {required String accountsRoot}) {
  final pids = <int>[];
  for (final line in psOutput.split('\n')) {
    if (!line.contains('HOME=$accountsRoot/')) continue;
    final m = RegExp(r'^\s*(\d+)\s+(\S+)').firstMatch(line);
    if (m == null) continue;
    final argv0 = m.group(2)!;
    if (argv0 != 'agy' && !argv0.endsWith('/agy')) continue;
    pids.add(int.parse(m.group(1)!));
  }
  return pids;
}
