import 'package:test/test.dart';
import 'package:wakie_core/wakie_core.dart';

void main() {
  final now = DateTime(2026, 6, 1, 15, 0); // Mon Jun 1, 3:00pm

  test('an already-absolute resetAt (Codex) is returned as-is', () {
    final at = DateTime(2026, 6, 5, 9, 0);
    final w = UsageWindow(usedPct: 10, resetAt: at);
    expect(resolveResetAt(w, now: now), at);
  });

  group('duration countdown (Antigravity)', () {
    test('hours + minutes', () {
      final w = const UsageWindow(usedPct: 10, resetLabel: '4h 25m');
      expect(resolveResetAt(w, now: now),
          now.add(const Duration(hours: 4, minutes: 25)));
    });

    test('days + hours', () {
      final w = const UsageWindow(usedPct: 10, resetLabel: '5d 2h');
      expect(resolveResetAt(w, now: now),
          now.add(const Duration(days: 5, hours: 2)));
    });

    test('minutes only', () {
      final w = const UsageWindow(usedPct: 10, resetLabel: '45m');
      expect(
          resolveResetAt(w, now: now), now.add(const Duration(minutes: 45)));
    });
  });

  group('rendered clock string (Claude)', () {
    test('bare time later today rolls to today', () {
      final w = const UsageWindow(
          usedPct: 10, resetLabel: '11:30pm (America/New_York)');
      expect(resolveResetAt(w, now: now), DateTime(2026, 6, 1, 23, 30));
    });

    test('bare time already past today rolls to tomorrow', () {
      final w =
          const UsageWindow(usedPct: 10, resetLabel: '2:30am (America/New_York)');
      expect(resolveResetAt(w, now: now), DateTime(2026, 6, 2, 2, 30));
    });

    test('date + time this year', () {
      final w = const UsageWindow(
          usedPct: 10, resetLabel: 'Jul 7 at 7am (America/New_York)');
      expect(resolveResetAt(w, now: now), DateTime(2026, 7, 7, 7, 0));
    });

    test('date + time already passed this year rolls to next year', () {
      final w = const UsageWindow(
          usedPct: 10, resetLabel: 'Jan 3 at 9am (America/New_York)');
      expect(resolveResetAt(w, now: now), DateTime(2027, 1, 3, 9, 0));
    });

    test('noon and midnight hour wraparound', () {
      final morning = DateTime(2026, 6, 1, 8, 0); // before both today
      expect(
          resolveResetAt(
              const UsageWindow(usedPct: 1, resetLabel: '12:00pm'),
              now: morning),
          DateTime(2026, 6, 1, 12, 0)); // noon, later today
      expect(
          resolveResetAt(
              const UsageWindow(usedPct: 1, resetLabel: '12:00am'),
              now: morning),
          DateTime(2026, 6, 2, 0, 0)); // midnight already passed → tomorrow
    });
  });

  test('unparseable label resolves to null', () {
    const w = UsageWindow(usedPct: 10, resetLabel: 'soon-ish');
    expect(resolveResetAt(w, now: now), isNull);
  });

  test('no resetAt and no resetLabel resolves to null', () {
    expect(resolveResetAt(UsageWindow.unknown, now: now), isNull);
  });
}
