import 'dart:io';

import 'store.dart';

/// Kills leftover scrape processes (`agy`, `claude`, `codex`) from a previous
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
Future<int> killOrphanedSandboxScrapes({String? accountsRoot}) =>
    _killMatching((out) => orphanedSandboxScrapePids(out,
        accountsRoot: accountsRoot ?? Store.defaultAccountsDir()));

/// Kills every scrape/login process still running inside [configHome] — any
/// parentage. For when the account is removed and its sandbox deleted: an
/// open login window's agy would otherwise keep running against the deleted
/// home (no keychain → dialog spam) until the window is closed by hand.
/// Best-effort: returns the number killed.
Future<int> killSandboxProcesses(String configHome) =>
    _killMatching((out) => sandboxProcessPids(out, configHome: configHome));

Future<int> _killMatching(List<int> Function(String psOutput) parse) async {
  try {
    // BSD-style `e` (no dash) appends each process's environment to its
    // command line; the POSIX `-e` form silently omits it on macOS.
    final ps = await Process.run('ps', ['axeww', '-o', 'pid=,ppid=,command=']);
    if (ps.exitCode != 0) return 0;
    final pids = parse(ps.stdout as String);
    for (final pid in pids) {
      Process.killPid(pid, ProcessSignal.sigkill);
    }
    return pids.length;
  } catch (_) {
    return 0; // cleanup must never break startup / removal
  }
}

/// The env var each provider CLI receives its sandbox config path in — the
/// marker that identifies a process as one of ours.
const _markerVar = <String, String>{
  'agy': 'HOME',
  'claude': 'CLAUDE_CONFIG_DIR',
  'codex': 'CODEX_HOME',
};

/// Parses `ps axeww -o pid=,ppid=,command=` output into the pids of orphaned
/// sandbox scrapes. Pure, for tests.
///
/// A process qualifies when its environment points into [accountsRoot], its
/// argv0 is a provider CLI, and it is orphaned: re-parented to pid 1
/// directly, or a child of a `script` pty wrapper that is. Qualifying
/// `script` parents are killed too (their own env is a platform binary's,
/// which ps redacts, so they can only be found through their child).
List<int> orphanedSandboxScrapePids(String psOutput,
        {required String accountsRoot}) =>
    _scrapePids(psOutput,
        marked: (line, envVar) => line.contains('$envVar=$accountsRoot/'),
        onlyOrphans: true);

/// Same parse, but for one exact [configHome] and regardless of parentage
/// (the whole sandbox is being deleted). Pure, for tests.
List<int> sandboxProcessPids(String psOutput, {required String configHome}) =>
    _scrapePids(psOutput, marked: (line, envVar) {
      // Exact-home match: the value ends at a space (next env var) or at the
      // end of the line, so home `…/antigravity-1` never matches `…-12`.
      final marker = '$envVar=$configHome';
      return line.contains('$marker ') || line.endsWith(marker);
    }, onlyOrphans: false);

List<int> _scrapePids(String psOutput,
    {required bool Function(String line, String envVar) marked,
    required bool onlyOrphans}) {
  final lineRe = RegExp(r'^\s*(\d+)\s+(\d+)\s+(\S+)');
  // pid -> (ppid, argv0) for every process, so parents can be looked up.
  final procs = <int, (int, String)>{};
  final candidates = <(int, int)>[]; // (pid, ppid) of marker-matched CLIs
  for (final line in psOutput.split('\n')) {
    final m = lineRe.firstMatch(line);
    if (m == null) continue;
    final pid = int.parse(m.group(1)!);
    final ppid = int.parse(m.group(2)!);
    final argv0 = m.group(3)!;
    procs[pid] = (ppid, argv0);
    final envVar = _markerVar[argv0.split('/').last];
    if (envVar == null || !marked(line, envVar)) continue;
    candidates.add((pid, ppid));
  }

  final pids = <int>[];
  for (final (pid, ppid) in candidates) {
    // A pty capture runs the CLI under `script`; when the host dies it is
    // the wrapper that re-parents to launchd, not the CLI itself.
    final parent = procs[ppid];
    final viaScript = parent != null && parent.$2.split('/').last == 'script';
    if (onlyOrphans && ppid != 1 && !(viaScript && parent.$1 == 1)) continue;
    if (viaScript) pids.add(ppid);
    pids.add(pid);
  }
  return pids;
}
