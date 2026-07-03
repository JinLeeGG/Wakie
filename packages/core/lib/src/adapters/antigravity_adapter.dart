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

    final home = envFor(a)['HOME'] ?? Platform.environment['HOME'];
    final gemini = '$home/.gemini';

    // An isolated (extra) account keeps its token ONLY in its own login
    // keychain — no `oauth_creds.json`/`google_accounts.json` files — so we
    // detect it by the presence of the `agy` credential *item* in that
    // keychain (existence only; the token itself is never read — R0). The
    // email isn't file-exposed for these, so the row shows its label alone.
    if (a.configHome != null) {
      final signedIn = await _hasKeychainCredential(a.configHome!);
      return signedIn
          ? const Preflight(PreflightState.ok)
          : const Preflight(PreflightState.notLoggedIn);
    }

    // Ambient default: token + email live in ~/.gemini files. Existence check
    // only — never the contents (R0).
    final email = _activeAccount(gemini);
    final loggedIn =
        File('$gemini/oauth_creds.json').existsSync() || email != null;
    if (!loggedIn) return const Preflight(PreflightState.notLoggedIn);
    return Preflight(PreflightState.ok, email: email);
  }

  /// True if [configHome]'s isolated login keychain holds the `agy` credential
  /// (service `gemini`, account `antigravity`) — i.e. a login has completed.
  /// Existence probe only; the credential value is never requested (R0).
  Future<bool> _hasKeychainCredential(String configHome) async {
    final keychain = '$configHome/Library/Keychains/login.keychain-db';
    if (!File(keychain).existsSync()) return false;
    try {
      final r = await Process.run('security', [
        'find-generic-password',
        '-s', 'gemini',
        '-a', 'antigravity',
        keychain,
      ]);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
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
    // Never launch agy for an isolated account that isn't actually signed in:
    // a logged-out `agy` pops the Google OAuth browser, and the capture's
    // keystrokes would drive it — so an account whose login was lost would
    // spam login windows on every refresh. Gate on the keychain credential.
    if (a.configHome != null && !await _hasKeychainCredential(a.configHome!)) {
      return ProviderStatus.unknown;
    }
    final panel = await capture(a);
    return parseAntigravityUsage(panel);
  }

  @override
  Future<RunOutcome> startSession(Account a, {String? model}) async {
    final startedAt = DateTime.now();
    try {
      // agy has no stable alias like claude's 'haiku' — --model takes the
      // display name from `agy models`. Flash (Low) is the cheapest; if a
      // CLI update renames it the start fails visibly (alert) rather than
      // silently burning a pricier model.
      final result = await Process.run(
        executable,
        ['--print', '--model', model ?? 'Gemini 3.5 Flash (Low)', 'hi'],
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
