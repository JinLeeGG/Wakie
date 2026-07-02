import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'claude_usage_parser.dart';
import '../vt.dart';

/// Live pty capture of Claude's `/usage` panel (the fragile A1 seam).
///
/// Drives the interactive `claude` TUI inside a pty via macOS `script`, opens
/// `/usage`, and returns the VT-rendered screen text (feed to
/// `parseClaudeUsage`). Rather than sleeping for fixed worst-case durations, it
/// polls the live screen and advances the moment it sees the signal it needs —
/// the input prompt is ready, then the usage numbers have rendered — so a warm
/// machine finishes in a few seconds instead of ~20. The `max*` values are only
/// fallback ceilings. Not unit-tested — the parser and VT emulator it feeds are
/// (see vt_test.dart).
Future<String> captureClaudeUsagePanel({
  Map<String, String> env = const {},
  String executable = 'claude',
  String? workingDirectory,
  Duration maxBoot = const Duration(seconds: 15),
  Duration maxRender = const Duration(seconds: 12),
  Duration poll = const Duration(milliseconds: 200),
}) async {
  final proc = await Process.start(
    'script',
    ['-q', '/dev/null', executable],
    environment: env,
    // For an isolated (extra) account, run inside its own config home so the
    // pre-trusted directory (see prepareClaudeConfigHome) matches — otherwise
    // claude shows a "trust this folder?" dialog that blocks the /usage panel.
    workingDirectory: workingDirectory,
  );

  final screen = VtScreen();
  final done = Completer<void>();
  proc.stdout.transform(utf8.decoder).listen(screen.write, onDone: () {
    if (!done.isCompleted) done.complete();
  });
  proc.stderr.drain<void>();

  try {
    // 1. Wait for the input prompt to be ready, then open /usage.
    await _pollUntil(() => _promptReady.hasMatch(screen.text), maxBoot, poll);
    proc.stdin.write('/usage');
    await proc.stdin.flush();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    proc.stdin.write('\r');
    await proc.stdin.flush();

    // If the panel hasn't started opening shortly, the Enter may have missed
    // (autocomplete race); resend once.
    if (!await _pollUntil(
        () => _panelOpening.hasMatch(screen.text),
        const Duration(seconds: 3),
        poll)) {
      proc.stdin.write('\r');
      await proc.stdin.flush();
    }

    // 2. Wait until the panel's numbers have actually rendered.
    await _pollUntil(() {
      final s = parseClaudeUsage(screen.text);
      return s.session.isKnown && s.weekly.isKnown;
    }, maxRender, poll);

    // Leave the TUI cleanly.
    proc.stdin.write('\x1b'); // Esc closes the panel
    await proc.stdin.flush();
    proc.stdin.write('\x03'); // Ctrl-C to exit
    await proc.stdin.flush();
  } finally {
    await done.future
        .timeout(const Duration(seconds: 3), onTimeout: () => proc.kill());
  }

  return screen.text;
}

/// The resting TUI shows the shortcuts hint once input is accepted.
final _promptReady = RegExp(r'shortcuts|Try "', caseSensitive: false);

/// The /usage panel is opening (still loading or already showing numbers).
final _panelOpening =
    RegExp(r'Current session|Loading usage|% used', caseSensitive: false);

/// Polls [cond] every [poll] until true or [max] elapses. Returns whether it
/// became true (false = timed out).
Future<bool> _pollUntil(
    bool Function() cond, Duration max, Duration poll) async {
  final deadline = DateTime.now().add(max);
  while (DateTime.now().isBefore(deadline)) {
    if (cond()) return true;
    await Future<void>.delayed(poll);
  }
  return cond();
}
