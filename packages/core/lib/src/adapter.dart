import 'account.dart';
import 'preflight.dart';
import 'status.dart';

/// A provider adapter — the seam between WakieAI and one AI CLI (PRD §10.3).
///
/// Invariant (R0): official binaries only, tokens never extracted, prompt /
/// response bodies never stored.
abstract class ProviderAdapter {
  /// Stable id, e.g. `claude`.
  String get id;

  /// Environment that isolates this account (e.g. `CLAUDE_CONFIG_DIR`).
  Map<String, String> envFor(Account a);

  /// Is the CLI installed, logged in, and up to date for this account?
  Future<Preflight> detect(Account a);

  /// Start a session with the cheapest model + minimal prompt (FR-RN-04).
  Future<RunOutcome> startSession(Account a, {String? model});

  /// Scrape `/usage` for this account. Returns unknown windows on parse miss
  /// rather than throwing (FR-ER).
  Future<ProviderStatus> readStatus(Account a);
}
