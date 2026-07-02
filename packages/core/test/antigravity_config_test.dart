import 'dart:io';

import 'package:test/test.dart';
import 'package:wakieai_core/wakieai_core.dart';

ProcessResult _ok([String stdout = '']) => ProcessResult(0, 0, stdout, '');

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('wakieai_agy_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('creates an isolated keychain, then restores the global search list', () async {
    final calls = <List<String>>[];
    final sandbox = '${tmp.path}/sandbox';

    await prepareAntigravityConfigHome(sandbox, runSecurity: (args) async {
      calls.add(args);
      if (args.first == 'list-keychains') {
        return _ok('    "/Users/x/Library/Keychains/login.keychain-db"\n');
      }
      return _ok();
    });

    final verbs = calls.map((c) => c.first).toList();
    // Saves the list, creates the keychain, restores the list, disables
    // auto-lock, and unlocks it.
    expect(verbs, containsAllInOrder(
        ['list-keychains', 'create-keychain', 'list-keychains',
         'set-keychain-settings', 'unlock-keychain']));

    final keychain = '$sandbox/Library/Keychains/login.keychain-db';
    expect(calls.firstWhere((c) => c.first == 'create-keychain'),
        ['create-keychain', '-p', '', keychain]);
    // The restore uses the ORIGINAL single-entry list (not the polluted one).
    final restore = calls.lastWhere((c) => c.first == 'list-keychains' && c.contains('-s'));
    expect(restore, contains('/Users/x/Library/Keychains/login.keychain-db'));
  });

  test('existing keychain is only re-unlocked, not recreated', () async {
    final sandbox = '${tmp.path}/sandbox';
    Directory('$sandbox/Library/Keychains').createSync(recursive: true);
    File('$sandbox/Library/Keychains/login.keychain-db').writeAsStringSync('x');
    final calls = <List<String>>[];

    await prepareAntigravityConfigHome(sandbox,
        runSecurity: (args) async {
      calls.add(args);
      return _ok();
    });

    final verbs = calls.map((c) => c.first).toList();
    expect(verbs, ['unlock-keychain']); // no create/list when it already exists
  });

  test('never throws if security calls fail', () async {
    final sandbox = '${tmp.path}/sandbox';
    await prepareAntigravityConfigHome(sandbox,
        runSecurity: (_) async => throw Exception('security boom'));
    // No throw = pass.
  });
}
