import 'dart:convert';
import 'dart:io';

import '../account.dart';
import '../adapter.dart';
import '../preflight.dart';
import '../status.dart';
import 'claude_usage_parser.dart';

/// Captures the rendered text of an account's `/usage` panel.
///
/// This is the fragile, provider-coupled seam (PRD A1): it must drive the
/// interactive `claude` TUI in a pty and return a terminal-grid snapshot.
/// Injected so [ClaudeAdapter] stays testable and the pty/VT-emulation concern
/// lives in the runtime layer, not the parser.
typedef UsageCapture = Future<String> Function(Account account);

/// Claude adapter (PRD §7.3 FR-PA-01). Official `claude` binary only; tokens
/// are never read or extracted (R0 invariant).
class ClaudeAdapter implements ProviderAdapter {
  final UsageCapture capture;
  final String executable;

  ClaudeAdapter({required this.capture, this.executable = 'claude'});

  @override
  String get id => 'claude';

  @override
  Map<String, String> envFor(Account a) => a.configHome == null
      ? const {} // ambient default account — token in Keychain, no override.
      : {'CLAUDE_CONFIG_DIR': a.configHome!};

  @override
  Future<Preflight> detect(Account a) async {
    final ProcessResult result;
    try {
      result = await Process.run(
        executable,
        ['auth', 'status', '--json'],
        environment: envFor(a),
      );
    } on ProcessException {
      return const Preflight(PreflightState.notInstalled);
    }

    if (result.exitCode != 0) {
      return Preflight(PreflightState.notLoggedIn,
          detail: (result.stderr as String).trim());
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    } on FormatException {
      return const Preflight(PreflightState.notLoggedIn,
          detail: 'unparseable auth status');
    }

    if (json['loggedIn'] != true) {
      return const Preflight(PreflightState.notLoggedIn);
    }
    return Preflight(PreflightState.ok,
        email: json['email'] as String?,
        plan: json['subscriptionType'] as String?);
  }

  @override
  Future<ProviderStatus> readStatus(Account a) async {
    final panel = await capture(a);
    return parseClaudeUsage(panel);
  }

  @override
  Future<RunOutcome> startSession(Account a, {String? model}) async {
    final startedAt = DateTime.now();
    try {
      final result = await Process.run(
        executable,
        ['-p', '--model', model ?? 'haiku', 'hi'],
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
