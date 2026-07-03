import 'package:test/test.dart';
import 'package:wakieai_core/wakieai_core.dart';

void main() {
  const root = '/Users/u/.wakieai/accounts';

  test('finds agy processes whose HOME is inside the accounts sandbox', () {
    const ps = '''
  101 /sbin/launchd PATH=/usr/bin
28720 agy TERM=xterm-256color HOME=$root/antigravity-1 PATH=/usr/bin
87617 /Users/u/.local/bin/agy HOME=$root/antigravity-2 TERM=xterm
33479 agy HOME=/Users/u PATH=/usr/bin
  555 vim HOME=$root/antigravity-1
''';
    expect(orphanedSandboxAgyPids(ps, accountsRoot: root), [28720, 87617]);
  });

  test('never matches the user\'s own agy (real HOME) or other tools', () {
    const ps = '''
  200 agy HOME=/Users/u
  201 /usr/bin/agyx HOME=$root/antigravity-1
''';
    expect(orphanedSandboxAgyPids(ps, accountsRoot: root), isEmpty);
  });
}
