import 'dart:io';

/// Runs a process, injected so tests never spawn a real admin prompt.
typedef ProcessRun = Future<ProcessResult> Function(
    String executable, List<String> args);

/// Runs [command] as root via the native macOS auth prompt (Touch ID /
/// password) using AppleScript's `with administrator privileges` — the
/// app-driven alternative to having the user paste a `sudo` line into a
/// terminal (FR-UI-05). [command] must NOT include `sudo`; the prompt does
/// the elevating.
///
/// Returns null on success, or a short message to show the user — including
/// the case where they dismiss the password dialog (osascript reports that as
/// error -128).
Future<String?> runWithAdminPrompt(String command,
    {ProcessRun run = Process.run}) async {
  // Escape for the AppleScript string literal: backslashes first, then quotes.
  final escaped = command.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  final result = await run('osascript',
      ['-e', 'do shell script "$escaped" with administrator privileges']);
  if (result.exitCode == 0) return null;
  final err = (result.stderr as String).trim();
  if (err.contains('-128')) return 'Cancelled.';
  return err.isEmpty ? 'Failed (exit ${result.exitCode}).' : err;
}
