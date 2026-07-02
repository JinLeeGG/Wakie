import 'package:test/test.dart';
import 'package:wakieai_core/wakieai_core.dart';

void main() {
  group('launchAgentPlist', () {
    test('embeds the executable path, label, and Hour/Minute only (daily recurrence)', () {
      final plist = launchAgentPlist(
        executablePath: '/Users/x/Library/Application Support/WakieAI/wakieai_runner',
        hour: 8,
        minute: 30,
      );

      expect(plist, contains('<string>ai.wakie.runner</string>'));
      expect(plist,
          contains('<string>/Users/x/Library/Application Support/WakieAI/wakieai_runner</string>'));
      expect(plist, contains('<key>Hour</key>\n    <integer>8</integer>'));
      expect(plist, contains('<key>Minute</key>\n    <integer>30</integer>'));
      // No Year/Month/Day keys — that's what makes it recur every day.
      expect(plist, isNot(contains('<key>Year</key>')));
      expect(plist, isNot(contains('<key>Day</key>')));
      expect(plist, contains('<key>RunAtLoad</key>\n  <false/>'));
    });

    test('omits StandardOutPath/StandardErrorPath when not given', () {
      final plist =
          launchAgentPlist(executablePath: '/bin/true', hour: 8, minute: 0);
      expect(plist, isNot(contains('StandardOutPath')));
      expect(plist, isNot(contains('StandardErrorPath')));
    });

    test('includes log paths when given', () {
      final plist = launchAgentPlist(
        executablePath: '/bin/true',
        hour: 8,
        minute: 0,
        stdoutPath: '/tmp/out.log',
        stderrPath: '/tmp/err.log',
      );
      expect(plist, contains('<string>/tmp/out.log</string>'));
      expect(plist, contains('<string>/tmp/err.log</string>'));
    });

    test('a custom label overrides the default', () {
      final plist = launchAgentPlist(
          executablePath: '/bin/true', hour: 8, minute: 0, label: 'com.test.x');
      expect(plist, contains('<string>com.test.x</string>'));
      expect(plist, isNot(contains('ai.wakie.runner')));
    });
  });

  group('loginItemPlist', () {
    test('runs the app at load only (no calendar, no keep-alive)', () {
      final plist = loginItemPlist(
          executablePath: '/Applications/WakieAI.app/Contents/MacOS/wakieai');
      expect(plist, contains('<string>ai.wakie.app</string>'));
      expect(plist,
          contains('<string>/Applications/WakieAI.app/Contents/MacOS/wakieai</string>'));
      expect(plist, contains('<key>RunAtLoad</key>'));
      expect(plist, isNot(contains('StartCalendarInterval')));
      expect(plist, isNot(contains('KeepAlive')));
    });
  });

  group('pmsetDailyWakeCommand', () {
    test('zero-pads hour and minute and targets every day', () {
      expect(pmsetDailyWakeCommand(hour: 8, minute: 5),
          'sudo pmset repeat wakeorpoweron MTWRFSU 08:05:00');
    });

    test('handles double-digit values without extra padding', () {
      expect(pmsetDailyWakeCommand(hour: 23, minute: 45),
          'sudo pmset repeat wakeorpoweron MTWRFSU 23:45:00');
    });
  });
}
