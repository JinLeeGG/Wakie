import 'dart:io';

import 'package:test/test.dart';
import 'package:wakie_core/wakie_core.dart';

void main() {
  group('runWithAdminPrompt', () {
    test('wraps the command in an administrator-privileges osascript call', () async {
      late List<String> captured;
      final err = await runWithAdminPrompt('pmset repeat cancel',
          run: (exe, args) async {
        expect(exe, 'osascript');
        captured = args;
        return ProcessResult(0, 0, '', '');
      });

      expect(err, isNull);
      expect(captured, [
        '-e',
        'do shell script "pmset repeat cancel" with administrator privileges'
      ]);
    });

    test('escapes quotes and backslashes for the AppleScript string', () async {
      late List<String> captured;
      await runWithAdminPrompt(r'echo "a\b"',
          run: (exe, args) async {
        captured = args;
        return ProcessResult(0, 0, '', '');
      });
      expect(captured.last,
          r'do shell script "echo \"a\\b\"" with administrator privileges');
    });

    test('reports a dismissed password dialog (error -128) as cancelled', () async {
      final err = await runWithAdminPrompt('pmset repeat cancel',
          run: (_, _) async =>
              ProcessResult(0, 1, '', 'execution error: User canceled. (-128)'));
      expect(err, 'Cancelled.');
    });

    test('surfaces other failures', () async {
      final err = await runWithAdminPrompt('pmset repeat cancel',
          run: (_, _) async => ProcessResult(0, 1, '', 'boom'));
      expect(err, 'boom');
    });
  });

  group('pmset commands', () {
    test('raw command omits sudo (the admin prompt elevates)', () {
      expect(pmsetDailyWakeCommandRaw(hour: 8, minute: 5),
          'pmset repeat wakeorpoweron MTWRFSU 08:05:00');
    });

    test('sudo command is the raw one prefixed with sudo', () {
      expect(pmsetDailyWakeCommand(hour: 8, minute: 5),
          'sudo ${pmsetDailyWakeCommandRaw(hour: 8, minute: 5)}');
    });

    test('cancel command has no sudo', () {
      expect(pmsetCancelCommandRaw, 'pmset repeat cancel');
    });
  });
}
