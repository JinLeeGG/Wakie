import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:wakieai_core/wakieai_core.dart';

void main() {
  test('parseCodexRateLimits golden: real account/rateLimits/read (2026-07-02)',
      () {
    final raw = File('test/fixtures/codex_rate_limits.json').readAsStringSync();
    final result = jsonDecode(raw) as Map<String, dynamic>;

    final status = parseCodexRateLimits(result);

    // primary → 5h session window.
    expect(status.session.usedPct, 1);
    expect(status.session.resetAt!.millisecondsSinceEpoch, 1782984529 * 1000);
    // secondary → weekly window.
    expect(status.weekly.usedPct, 44);
    expect(status.weekly.resetAt!.millisecondsSinceEpoch, 1783392259 * 1000);
  });

  test('missing rateLimits yields unknown, not a throw', () {
    expect(parseCodexRateLimits(const {}).session.isKnown, isFalse);
    expect(parseCodexRateLimits(const {}).weekly.isKnown, isFalse);
  });

  test('missing secondary window yields unknown weekly', () {
    final status = parseCodexRateLimits({
      'rateLimits': {
        'primary': {'usedPercent': 7, 'resetsAt': 1782984529},
      },
    });
    expect(status.session.usedPct, 7);
    expect(status.weekly.isKnown, isFalse);
  });

  test('null resetsAt is tolerated', () {
    final status = parseCodexRateLimits({
      'rateLimits': {
        'primary': {'usedPercent': 3, 'resetsAt': null},
      },
    });
    expect(status.session.usedPct, 3);
    expect(status.session.resetAt, isNull);
  });

  test('free plan: a 30-day primary window maps to weekly, not session', () {
    // Free-tier Codex reports one long window as primary and no secondary.
    final status = parseCodexRateLimits({
      'rateLimits': {
        'primary': {
          'usedPercent': 5,
          'windowDurationMins': 43200, // 30 days
          'resetsAt': 1785581976,
        },
        'secondary': null,
      },
    });
    // Not shown as a "5h session" — the session slot stays unknown.
    expect(status.session.isKnown, isFalse);
    expect(status.weekly.usedPct, 5);
    expect(status.weekly.resetAt!.millisecondsSinceEpoch, 1785581976 * 1000);
  });
}
