import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:wakieai_core/wakieai_core.dart';

String _claudeLine({
  String type = 'assistant',
  String? msgId = 'msg_1',
  String? requestId = 'req_1',
  String model = 'claude-opus-4-8',
  String timestamp = '2026-07-03T12:00:00.000Z',
  int input = 0,
  int output = 0,
  int cacheRead = 0,
  int? cacheCreate,
  int? w5m,
  int? w1h,
}) {
  final usage = <String, dynamic>{
    'input_tokens': input,
    'output_tokens': output,
    'cache_read_input_tokens': cacheRead,
    'cache_creation_input_tokens': ?cacheCreate,
    if (w5m != null || w1h != null)
      'cache_creation': {
        'ephemeral_5m_input_tokens': w5m ?? 0,
        'ephemeral_1h_input_tokens': w1h ?? 0,
      },
  };
  return jsonEncode({
    'type': type,
    'timestamp': timestamp,
    'requestId': ?requestId,
    'message': {
      'id': ?msgId,
      'model': model,
      'usage': usage,
    },
  });
}

String _codexCountLine({
  String timestamp = '2026-07-03T12:00:00.000Z',
  int input = 0,
  int cached = 0,
  int output = 0,
}) =>
    jsonEncode({
      'timestamp': timestamp,
      'type': 'event_msg',
      'payload': {
        'type': 'token_count',
        'info': {
          'total_token_usage': {
            'input_tokens': input,
            'cached_input_tokens': cached,
            'output_tokens': output,
          },
        },
      },
    });

void main() {
  group('claudeRates', () {
    test('matches by family and skips non-models', () {
      expect(claudeRates('claude-fable-5')!.input, 10);
      expect(claudeRates('claude-opus-4-8')!.input, 5);
      expect(claudeRates('claude-sonnet-5')!.input, 3);
      expect(claudeRates('claude-haiku-4-5-20251001')!.input, 1);
      // Unknown claude family falls back to the middle tier.
      expect(claudeRates('claude-newthing-9')!.input, 5);
      expect(claudeRates('<synthetic>'), isNull);
    });
  });

  group('parseClaudeLog', () {
    test('prices input/output/cache read/cache write by TTL', () {
      final events = parseClaudeLog(_claudeLine(
        model: 'claude-opus-4-8',
        input: 1000000,
        output: 1000000,
        cacheRead: 1000000,
        w5m: 1000000,
        w1h: 1000000,
      ));
      // 5 + 25 + 0.5 + 6.25 + 10
      expect(events.single.cost, closeTo(46.75, 1e-9));
    });

    test('aggregate cache_creation without breakdown prices as 1h', () {
      final events = parseClaudeLog(_claudeLine(
        model: 'claude-sonnet-5',
        cacheCreate: 1000000,
      ));
      expect(events.single.cost, closeTo(6.0, 1e-9)); // 2× of $3 input
    });

    test('carries a dedup key only when both ids exist', () {
      expect(parseClaudeLog(_claudeLine()).single.key, 'msg_1:req_1');
      expect(parseClaudeLog(_claudeLine(requestId: null)).single.key, isNull);
    });

    test('skips synthetic models, junk lines, and missing usage', () {
      final content = [
        _claudeLine(model: '<synthetic>'),
        'not json at all "usage"',
        jsonEncode({'type': 'user', 'timestamp': '2026-07-03T12:00:00Z'}),
        _claudeLine(output: 100),
      ].join('\n');
      expect(parseClaudeLog(content), hasLength(1));
    });
  });

  group('parseCodexRollout', () {
    test('prices the last cumulative total with the cached-input discount',
        () {
      final content = [
        jsonEncode({
          'type': 'turn_context',
          'payload': {'model': 'gpt-5.5'},
        }),
        _codexCountLine(input: 10000, cached: 4000, output: 2000),
        _codexCountLine(
          timestamp: '2026-07-03T13:00:00.000Z',
          input: 1000000,
          cached: 400000,
          output: 200000,
        ),
      ].join('\n');
      final events = parseCodexRollout(content);
      // (1M-400k)×1.25 + 400k×0.125 + 200k×10, per MTok
      expect(events.single.cost, closeTo(0.75 + 0.05 + 2.0, 1e-9));
      expect(events.single.at, DateTime.utc(2026, 7, 3, 13));
    });

    test('returns nothing for a rollout without token counts', () {
      expect(parseCodexRollout('{"type":"session_meta","payload":{}}'),
          isEmpty);
    });
  });

  group('ApiValueScanner', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('apivalue'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('sums a claude home, dedups repeats, and windows to 7 days', () async {
      final now = DateTime.utc(2026, 7, 4, 12);
      final dir = Directory('${tmp.path}/projects/p1')..createSync(recursive: true);
      // Two files repeating the same message (continued session) + an event
      // older than the window inside an otherwise-recent file.
      File('${dir.path}/a.jsonl').writeAsStringSync([
        _claudeLine(msgId: 'm1', requestId: 'r1', output: 1000000),
        _claudeLine(
          msgId: 'old',
          requestId: 'r0',
          timestamp: '2026-06-01T00:00:00.000Z',
          output: 1000000,
        ),
      ].join('\n'));
      File('${dir.path}/b.jsonl').writeAsStringSync(
        _claudeLine(msgId: 'm1', requestId: 'r1', output: 1000000),
      );
      final scanner = ApiValueScanner();
      final v = await scanner.claudeWeekly(tmp.path, now: now);
      expect(v, closeTo(25.0, 1e-9)); // one opus output MTok, once

      // Cached rescan returns the same value.
      expect(await scanner.claudeWeekly(tmp.path, now: now),
          closeTo(25.0, 1e-9));
    });

    test('re-reads only the appended tail of a growing claude file', () async {
      final now = DateTime.utc(2026, 7, 4, 12);
      final dir = Directory('${tmp.path}/projects/p1')
        ..createSync(recursive: true);
      final f = File('${dir.path}/live.jsonl')
        ..writeAsStringSync(
            _claudeLine(msgId: 'm1', requestId: 'r1', output: 1000000));
      final scanner = ApiValueScanner();
      expect(
          await scanner.claudeWeekly(tmp.path, now: now), closeTo(25.0, 1e-9));

      // Append a second message as a new line — the prefix is untouched, so the
      // scanner should tail-read only the new bytes and add to the cached
      // total without re-counting the first message.
      f.writeAsStringSync(
          '\n${_claudeLine(msgId: 'm2', requestId: 'r2', output: 1000000)}',
          mode: FileMode.append);
      expect(
          await scanner.claudeWeekly(tmp.path, now: now), closeTo(50.0, 1e-9));

      // A rescan with nothing appended stays put (no double-count, no drift).
      expect(
          await scanner.claudeWeekly(tmp.path, now: now), closeTo(50.0, 1e-9));
    });

    test('sums codex rollouts per session', () async {
      final now = DateTime.utc(2026, 7, 4, 12);
      final dir = Directory('${tmp.path}/sessions/2026/07/03')
        ..createSync(recursive: true);
      File('${dir.path}/rollout-1.jsonl')
          .writeAsStringSync(_codexCountLine(output: 1000000));
      File('${dir.path}/rollout-2.jsonl')
          .writeAsStringSync(_codexCountLine(output: 1000000));
      final v = await ApiValueScanner().codexWeekly(tmp.path, now: now);
      expect(v, closeTo(20.0, 1e-9)); // 2 sessions × 1 MTok output × $10
    });

    test('missing home reads as zero', () async {
      expect(
        await ApiValueScanner().claudeWeekly('${tmp.path}/nope'),
        0,
      );
    });

    test('weeklyByOwner splits a shared home by the login at each timestamp',
        () async {
      final now = DateTime.utc(2026, 7, 4, 12);
      final dir = Directory('${tmp.path}/projects/p1')
        ..createSync(recursive: true);
      File('${dir.path}/a.jsonl').writeAsStringSync([
        // While a@b.com was signed in.
        _claudeLine(
          msgId: 'm1',
          timestamp: '2026-07-01T10:00:00.000Z',
          output: 1000000,
        ),
        // After the switch to x@b.com.
        _claudeLine(
          msgId: 'm2',
          timestamp: '2026-07-03T10:00:00.000Z',
          output: 1000000,
        ),
        _claudeLine(
          msgId: 'm3',
          timestamp: '2026-07-03T11:00:00.000Z',
          output: 1000000,
        ),
      ].join('\n'));

      final switchAt = DateTime.utc(2026, 7, 2);
      String? ownerAt(DateTime at) =>
          at.isBefore(switchAt) ? 'a@b.com' : 'x@b.com';

      final split =
          await ApiValueScanner().claudeWeeklyByOwner(tmp.path, ownerAt, now: now);
      expect(split['a@b.com'], closeTo(25.0, 1e-9));
      expect(split['x@b.com'], closeTo(50.0, 1e-9));
    });

    test('weeklyByOwner drops events with no known owner', () async {
      final now = DateTime.utc(2026, 7, 4, 12);
      final dir = Directory('${tmp.path}/projects/p1')
        ..createSync(recursive: true);
      File('${dir.path}/a.jsonl')
          .writeAsStringSync(_claudeLine(output: 1000000));

      final split =
          await ApiValueScanner().claudeWeeklyByOwner(tmp.path, (_) => null, now: now);
      expect(split, isEmpty);
    });
  });
}
