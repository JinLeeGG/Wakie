import 'package:test/test.dart';
import 'package:wakie_core/wakie_core.dart';

void main() {
  const root = '/Users/u/.wakie/accounts';

  test('finds orphaned agy processes whose HOME is inside the sandbox', () {
    const ps = '''
  101     1 /sbin/launchd PATH=/usr/bin
28720     1 agy TERM=xterm-256color HOME=$root/antigravity-1 PATH=/usr/bin
87617     1 /Users/u/.local/bin/agy HOME=$root/antigravity-2 TERM=xterm
33479     1 agy HOME=/Users/u PATH=/usr/bin
  555     1 vim HOME=$root/antigravity-1
''';
    expect(orphanedSandboxScrapePids(ps, accountsRoot: root), [28720, 87617]);
  });

  test('finds orphaned claude scrapes plus their script pty wrapper', () {
    // `script` is a platform binary, so ps redacts its env — it is only
    // reachable through its claude child's CLAUDE_CONFIG_DIR marker.
    const ps = '''
 6173     1 script -q /dev/null /Users/u/.local/bin/claude
 6175  6173 /Users/u/.local/bin/claude CLAUDE_CONFIG_DIR=$root/claude-1 TERM=x
''';
    expect(orphanedSandboxScrapePids(ps, accountsRoot: root), [6173, 6175]);
  });

  test('spares in-flight scrapes owned by a live app or login window', () {
    // claude's script wrapper still belongs to the app (ppid 900 ≠ 1), and
    // the agy login window's shell is alive — neither is orphaned.
    const ps = '''
  900     1 /Applications/wakie.app/Contents/MacOS/wakie HOME=/Users/u
  901   900 script -q /dev/null claude
  902   901 claude CLAUDE_CONFIG_DIR=$root/claude-1 TERM=x
  910   905 agy HOME=$root/antigravity-1 TERM=x
''';
    expect(orphanedSandboxScrapePids(ps, accountsRoot: root), isEmpty);
  });

  test('never matches the user\'s own CLIs (real config) or other tools', () {
    const ps = '''
  200     1 agy HOME=/Users/u
  201     1 /usr/bin/agyx HOME=$root/antigravity-1
  202     1 claude CLAUDE_CONFIG_DIR=/Users/u/.claude
''';
    expect(orphanedSandboxScrapePids(ps, accountsRoot: root), isEmpty);
  });

  test('removal kill matches the home\'s processes regardless of parentage',
      () {
    // The login window's agy has a live shell parent — orphan cleanup spares
    // it, but removing the account must not: its home is being deleted.
    const ps = '''
  700   650 agy HOME=$root/antigravity-1 TERM=x
  701     1 script -q /dev/null claude
  702   701 claude CLAUDE_CONFIG_DIR=$root/antigravity-1 TERM=x
''';
    expect(sandboxProcessPids(ps, configHome: '$root/antigravity-1'),
        [700, 701, 702]);
  });

  test('removal kill is exact — a sibling home sharing the prefix is spared',
      () {
    const ps = '''
  700     1 agy HOME=$root/antigravity-12 TERM=x
  701     1 agy HOME=$root/antigravity-1
''';
    expect(
        sandboxProcessPids(ps, configHome: '$root/antigravity-1'), [701]);
  });
}
