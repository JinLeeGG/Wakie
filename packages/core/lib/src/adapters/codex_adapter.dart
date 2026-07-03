import 'dart:io';

import '../account.dart';
import '../adapter.dart';
import '../preflight.dart';
import '../status.dart';
import 'codex_usage_parser.dart';

/// Reads an account's Codex rate limits, returning the JSON-RPC `result` object
/// (or null on failure). Injected so [CodexAdapter] stays testable and the
/// app-server/process concern lives in the runtime layer (see codex_app_server.dart).
typedef CodexRateLimitsRead = Future<Map<String, dynamic>?> Function(
    Account account);

/// Reads an account's identity object (`{type, email, planType}`) from the
/// app-server `account/read`, or null. Injected like [CodexRateLimitsRead] so
/// the adapter stays testable; optional so tests can omit it.
typedef CodexAccountRead = Future<Map<String, dynamic>?> Function(
    Account account);

/// Codex adapter (PRD §7.3 FR-PA-02). Official `codex` binary only; usage comes
/// from the structured `account/rateLimits/read` app-server call, not TUI
/// scraping. Tokens are never read or extracted (R0 invariant).
class CodexAdapter implements ProviderAdapter {
  final CodexRateLimitsRead read;
  final CodexAccountRead? readAccount;
  final String executable;

  CodexAdapter({required this.read, this.readAccount, this.executable = 'codex'});

  @override
  String get id => 'codex';

  @override
  Map<String, String> envFor(Account a) => a.configHome == null
      ? const {} // ambient default account — no override.
      : {'CODEX_HOME': a.configHome!};

  @override
  Future<Preflight> detect(Account a) async {
    final ProcessResult result;
    try {
      result = await Process.run(
        executable,
        ['login', 'status'],
        environment: envFor(a),
      );
    } on ProcessException {
      return const Preflight(PreflightState.notInstalled);
    }

    // `codex login status` prints "Logged in using ChatGPT" to stderr (stdout
    // is empty), so check both streams.
    final out =
        '${result.stdout as String}\n${result.stderr as String}'.trim();
    if (result.exitCode != 0 || !out.contains('Logged in')) {
      return Preflight(PreflightState.notLoggedIn,
          detail: out.isEmpty ? null : out);
    }
    // Logged in — enrich with identity (email + plan) from account/read.
    final account = await readAccount?.call(a);
    return Preflight(PreflightState.ok,
        email: account?['email'] as String?,
        plan: account?['planType'] as String?);
  }

  @override
  Future<ProviderStatus> readStatus(Account a) async {
    final result = await read(a);
    if (result == null) return ProviderStatus.unknown;
    return parseCodexRateLimits(result);
  }

  @override
  Future<RunOutcome> startSession(Account a, {String? model}) async {
    final startedAt = DateTime.now();
    try {
      // gpt-5.4-mini is the cheapest id a ChatGPT-plan account accepts
      // (the /model picker's "cost-efficient" entry; api-only ids 400).
      // Effort is pinned low too so the user's configured default (often
      // high) can't leak into chain starts.
      final result = await Process.run(
        executable,
        [
          'exec',
          '--model', model ?? 'gpt-5.4-mini',
          '-c', 'model_reasoning_effort=low',
          'hi',
        ],
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
