import 'dart:io';

import 'package:test/test.dart';
import 'package:wakieai_core/wakieai_core.dart';

void main() {
  group('resolveCli', () {
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('wakieai-cli'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('finds a CLI on PATH and returns its absolute path', () {
      final bin = File('${tmp.path}/claude')..createSync();
      expect(resolveCli('claude', environment: {'PATH': tmp.path}), bin.path);
    });

    test('falls back to well-known dirs when PATH misses it', () {
      // Simulate launchd's minimal PATH with HOME pointing at a fake home
      // whose ~/.local/bin holds the CLI.
      final localBin = Directory('${tmp.path}/.local/bin')
        ..createSync(recursive: true);
      final bin = File('${localBin.path}/agy')..createSync();
      expect(
        resolveCli('agy',
            environment: {'PATH': '/usr/bin:/bin', 'HOME': tmp.path}),
        bin.path,
      );
    });

    test('returns the bare name when the CLI is nowhere', () {
      expect(
        resolveCli('nonexistent-cli',
            environment: {'PATH': tmp.path, 'HOME': tmp.path}),
        'nonexistent-cli',
      );
    });
  });
}
