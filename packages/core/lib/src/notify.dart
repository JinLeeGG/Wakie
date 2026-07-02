import 'dart:io';

/// Posts a macOS user notification via `osascript` — no extra package
/// dependency, works headlessly (dark wake) and from the GUI alike (FR-NT-06,
/// Phase 0-1 channel = Mac notifications). Best effort: a missing/blocked
/// `osascript` never throws — a notification failing to show shouldn't crash
/// the runner.
Future<void> showMacNotification(String title, String body) async {
  try {
    await Process.run(
        'osascript', ['-e', 'display notification ${_q(body)} with title ${_q(title)}']);
  } catch (_) {
    // Best-effort.
  }
}

String _q(String s) =>
    '"${s.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';
