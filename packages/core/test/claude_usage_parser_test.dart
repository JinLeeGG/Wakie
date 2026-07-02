import 'dart:io';

import 'package:test/test.dart';
import 'package:wakieai_core/wakieai_core.dart';

void main() {
  group('parseClaudeUsage', () {
    test('golden: real /usage panel (2026-07-01 capture)', () {
      final panel = File('test/fixtures/claude_usage.txt').readAsStringSync();
      final status = parseClaudeUsage(panel);

      expect(status.session.usedPct, 19);
      expect(status.session.resetLabel, '2:30am (America/New_York)');
      expect(status.weekly.usedPct, 2);
      expect(status.weekly.resetLabel, 'Jul 7 at 7am (America/New_York)');
    });

    test('does not cross session/week windows', () {
      const panel = '''
Current session
50% used            Resets 9:00am (America/New_York)
Current week (all models)
80% used            Resets Jul 8 at 7am (America/New_York)
''';
      final status = parseClaudeUsage(panel);
      expect(status.session.usedPct, 50);
      expect(status.weekly.usedPct, 80);
    });

    test('still-loading panel yields unknown, not a throw', () {
      final status = parseClaudeUsage('Usage\nLoading usage data…\nEsc to cancel');
      expect(status.session.isKnown, isFalse);
      expect(status.weekly.isKnown, isFalse);
    });
  });
}
