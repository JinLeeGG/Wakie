import 'dart:io';

import 'package:test/test.dart';
import 'package:wakieai_core/wakieai_core.dart';

void main() {
  test('golden: parses the captured /usage panel (most-constrained group)', () {
    final panel =
        File('test/fixtures/antigravity_usage.txt').readAsStringSync();
    final status = parseAntigravityUsage(panel);

    // Gemini is the binding group in both windows (Claude/GPT shows full quota).
    // Five-hour → session: 98% remaining → 2% used, "4h 44m".
    expect(status.session.usedPct, 2);
    expect(status.session.resetLabel, '4h 44m');
    // Weekly: 99% remaining → 1% used, "125h 16m".
    expect(status.weekly.usedPct, 1);
    expect(status.weekly.resetLabel, '125h 16m');
  });

  test('"Quota available" reads as full (0% used, no reset)', () {
    final status = parseAntigravityUsage('''
GEMINI MODELS
  Weekly Limit
    [██████████] 100.00%
    Quota available
  Five Hour Limit
    [██████████] 100.00%
    Quota available
''');
    expect(status.weekly.usedPct, 0);
    expect(status.weekly.resetLabel, isNull);
    expect(status.session.usedPct, 0);
  });

  test('missing panel degrades to unknown, not a throw', () {
    final status = parseAntigravityUsage('Loading usage…');
    expect(status.session.isKnown, isFalse);
    expect(status.weekly.isKnown, isFalse);
  });
}
