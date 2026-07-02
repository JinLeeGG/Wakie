import 'dart:convert';
import 'dart:io';

import '../account.dart';
import '../adapter.dart';
import '../preflight.dart';
import '../status.dart';
import 'antigravity_usage_parser.dart';

/// Captures an account's rendered `/usage` panel text (or '' on failure).
/// Injected so [AntigravityAdapter] stays testable and the fragile pty/TUI
/// concern lives in the capture layer (see antigravity_usage_capture.dart).
typedef AntigravityUsageCapture = Future<String> Function(Account account);

/// Antigravity adapter (PRD §7.3 FR-PA-03). Official `agy` binary only; usage
/// comes from scraping the interactive `/usage` panel — `agy` has no structured
/// status surface. Tokens are never read or extracted (R0 invariant); login is
/// inferred only from the *presence* of the OAuth credential file.
class AntigravityAdapter implements ProviderAdapter {
  final AntigravityUsageCapture capture;
  final String executable;

  AntigravityAdapter({required this.capture, this.executable = 'agy'});

  @override
  String get id => 'antigravity';

  @override
  Map<String, String> envFor(Account a) => a.configHome == null
      ? const {} // ambient default account — no override.
      : {'HOME': a.configHome!};

  @override
  Future<Preflight> detect(Account a) async {
    try {
      await Process.run(executable, ['--version'], environment: envFor(a));
    } on ProcessException {
      return const Preflight(PreflightState.notInstalled);
    }

    // Auth lives under ~/.gemini (HOME-relative). We check for the credential
    // file's existence only — never its contents (R0).
    final home = envFor(a)['HOME'] ?? Platform.environment['HOME'];
    final gemini = '$home/.gemini';
    if (!File('$gemini/oauth_creds.json').existsSync()) {
      return const Preflight(PreflightState.notLoggedIn);
    }
    return Preflight(PreflightState.ok, email: _activeAccount(gemini));
  }

  /// The signed-in Google account email, from `google_accounts.json`'s
  /// `active` field (not a secret). Null if unavailable.
  String? _activeAccount(String geminiDir) {
    try {
      final raw = File('$geminiDir/google_accounts.json').readAsStringSync();
      final active = (jsonDecode(raw) as Map<String, dynamic>)['active'];
      return active is String && active.isNotEmpty ? active : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ProviderStatus> readStatus(Account a) async {
    final panel = await capture(a);
    return parseAntigravityUsage(panel);
  }

  @override
  Future<RunOutcome> startSession(Account a, {String? model}) async {
    final startedAt = DateTime.now();
    try {
      final result = await Process.run(
        executable,
        ['--print', if (model != null) ...['--model', model], 'hi'],
        environment: envFor(a),
      );
      return RunOutcome(
        ok: result.exitCode == 0,
        startedAt: startedAt,
        error: result.exitCode == 0 ? null : (result.stderr as String).trim(),
      );
    } on ProcessException catch (e) {
      return RunOutcome(ok: false, startedAt: startedAt, error: e.message);
    }
  }
}
