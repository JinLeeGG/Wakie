import 'package:test/test.dart';
import 'package:wakie_core/wakie_core.dart';

void main() {
  group('parseKernWakeTime', () {
    test('reads the epoch seconds', () {
      expect(
        parseKernWakeTime(
            '{ sec = 1751513580, usec = 123456 } Fri Jul  3 00:33:00 2026'),
        DateTime.fromMillisecondsSinceEpoch(1751513580 * 1000),
      );
    });

    test('null on sec = 0 (never slept) or junk', () {
      expect(parseKernWakeTime('{ sec = 0, usec = 0 }'), isNull);
      expect(parseKernWakeTime('nope'), isNull);
    });
  });

  group('parseHidIdleSeconds', () {
    test('converts nanoseconds to seconds', () {
      expect(
        parseHidIdleSeconds('    "HIDIdleTime" = 300000000000\n'),
        300.0,
      );
    });

    test('null when the field is absent', () {
      expect(parseHidIdleSeconds('"SomethingElse" = 5'), isNull);
    });
  });

  group('unattendedWake', () {
    final now = DateTime(2026, 7, 3, 0, 33, 30);

    test('true: woke 30s ago, idle spans it (input was before sleep)', () {
      expect(
        unattendedWake(
            now: now,
            wokeAt: now.subtract(const Duration(seconds: 30)),
            idleSeconds: 300),
        isTrue,
      );
    });

    test('false: user typed after the wake (idle shorter than time awake)',
        () {
      expect(
        unattendedWake(
            now: now,
            wokeAt: now.subtract(const Duration(seconds: 30)),
            idleSeconds: 4),
        isFalse,
      );
    });

    test('false: machine has been awake too long to be our scheduled wake',
        () {
      expect(
        unattendedWake(
            now: now,
            wokeAt: now.subtract(const Duration(hours: 2)),
            idleSeconds: 9999),
        isFalse,
      );
    });

    test('false: missing kernel data reads as attended', () {
      expect(unattendedWake(now: now, wokeAt: null, idleSeconds: 300), isFalse);
      expect(
        unattendedWake(
            now: now,
            wokeAt: now.subtract(const Duration(seconds: 30)),
            idleSeconds: null),
        isFalse,
      );
    });
  });
}
