import 'dart:io';

import 'package:test/test.dart';
import 'package:wakie_core/wakie_core.dart';

void main() {
  group('VtScreen cursor mechanics', () {
    test('cursor-forward leaves spaces instead of gluing text', () {
      // "AB" then CUF(3) then "CD" → "AB   CD"
      expect(renderVt('AB\x1b[3CCD'), 'AB   CD');
    });

    test('CR returns to column 0; later writes overwrite', () {
      expect(renderVt('XXXX\rYY'), 'YYXX');
    });

    test('CUP positions absolutely and pads rows', () {
      final text = renderVt('\x1b[2;3Hhi');
      expect(text.split('\n'), ['', '  hi']);
    });

    test('erase-line to end clears the tail', () {
      expect(renderVt('ABCDEF\r\x1b[3C\x1b[K'), 'ABC');
    });

    test('ignores SGR styling and OSC titles', () {
      expect(renderVt('\x1b[31mred\x1b[0m\x1b]0;title\x07!'), 'red!');
    });
  });

  group('end-to-end: real /usage capture', () {
    test('raw pty bytes → VT grid → parser yields real usage', () {
      final raw = File('test/fixtures/claude_usage_raw.ansi').readAsStringSync();
      final status = parseClaudeUsage(renderVt(raw));

      expect(status.session.usedPct, 19);
      expect(status.session.resetLabel, '2:30am (America/New_York)');
      expect(status.weekly.usedPct, 2);
      expect(status.weekly.resetLabel, 'Jul 7 at 7am (America/New_York)');
    });
  });
}
