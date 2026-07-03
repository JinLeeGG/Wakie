import 'package:flutter_test/flutter_test.dart';
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
}
