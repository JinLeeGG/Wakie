import 'package:flutter_test/flutter_test.dart';
import 'package:wakieai/models.dart';
import 'package:wakieai/widgets/summary.dart';

void main() {
  group('parseAnchorTime', () {
    test('accepts 12h forms with am/pm', () {
      expect(parseAnchorTime('7:30am'), (7, 30));
      expect(parseAnchorTime('7:30 PM'), (19, 30));
      expect(parseAnchorTime('12:10am'), (0, 10)); // midnight-hour night owl
      expect(parseAnchorTime('12pm'), (12, 0));
      expect(parseAnchorTime('9am'), (9, 0));
    });

    test('accepts 24h forms', () {
      expect(parseAnchorTime('23:45'), (23, 45));
      expect(parseAnchorTime('0:10'), (0, 10));
      expect(parseAnchorTime('14'), (14, 0));
      expect(parseAnchorTime(' 6:05 '), (6, 5));
    });

    test('rejects out-of-range and junk', () {
      expect(parseAnchorTime('24:00'), isNull);
      expect(parseAnchorTime('7:60'), isNull);
      expect(parseAnchorTime('13pm'), isNull); // am/pm hours are 1–12
      expect(parseAnchorTime('0am'), isNull);
      expect(parseAnchorTime('soon'), isNull);
      expect(parseAnchorTime(''), isNull);
    });
  });

  group('usdLabel', () {
    test('whole dollars with thousands grouping from \$10 up', () {
      expect(usdLabel(1435.54), r'$1,436');
      expect(usdLabel(713.3), r'$713');
      expect(usdLabel(38.6), r'$39');
      expect(usdLabel(10), r'$10');
      expect(usdLabel(1234567.0), r'$1,234,567');
    });
    test('one decimal under \$10, trimming a bare .0', () {
      expect(usdLabel(8.34), r'$8.3');
      expect(usdLabel(9.0), r'$9');
      expect(usdLabel(0), r'$0');
    });
  });

  group('untilLabel', () {
    final now = DateTime(2026, 7, 3, 12, 0);
    test('hours and minutes within a day', () {
      expect(untilLabel(now.add(const Duration(hours: 5, minutes: 12)), now: now),
          '5h 12m');
      expect(untilLabel(now.add(const Duration(minutes: 40)), now: now), '40m');
    });
    test('days and hours past a day', () {
      expect(untilLabel(now.add(const Duration(days: 3, hours: 4)), now: now),
          '3d 4h');
    });
    test('past or sub-minute reads as under a minute', () {
      expect(untilLabel(now.subtract(const Duration(minutes: 5)), now: now),
          'under a minute');
      expect(untilLabel(now.add(const Duration(seconds: 30)), now: now),
          'under a minute');
    });
  });
}
