/// A single usage meter read from a provider (session or weekly window).
class UsageWindow {
  /// Percent of the window already consumed (0..100), or null if unknown.
  /// Mirrors the provider's own "N% used" wording; remaining = 100 - usedPct.
  final int? usedPct;

  /// The provider's raw reset wording, e.g. "2:30am (America/New_York)" or
  /// "Jul 7 at 7am (America/New_York)". Kept verbatim when the provider only
  /// exposes a rendered string (Claude's `/usage` panel).
  final String? resetLabel;

  /// Absolute reset instant, when the provider reports it as a timestamp
  /// (Codex's `account/rateLimits/read` returns epoch `resetsAt`). Null when
  /// only [resetLabel] is available.
  final DateTime? resetAt;

  const UsageWindow({this.usedPct, this.resetLabel, this.resetAt});

  static const unknown = UsageWindow();

  bool get isKnown => usedPct != null;
}

/// The result of scraping a provider's `/usage` (PRD §10.3, FR-RN-03).
///
/// All fields nullable: a parse miss surfaces as "unknown" in the dashboard
/// rather than failing the whole read (FR-ER).
class ProviderStatus {
  final UsageWindow session;
  final UsageWindow weekly;

  const ProviderStatus({
    this.session = UsageWindow.unknown,
    this.weekly = UsageWindow.unknown,
  });

  static const unknown = ProviderStatus();
}

/// Outcome of the last runner action against an account.
enum Outcome { ok, failed, unknown }

/// The stored per-account status record (PRD §10.1).
class Status {
  final String accountId;
  final UsageWindow session;
  final UsageWindow weekly;
  final DateTime? lastStartedAt;
  final Outcome lastOutcome;
  final DateTime? lastCheckedAt;

  const Status({
    required this.accountId,
    this.session = UsageWindow.unknown,
    this.weekly = UsageWindow.unknown,
    this.lastStartedAt,
    this.lastOutcome = Outcome.unknown,
    this.lastCheckedAt,
  });

  Status copyWith({
    UsageWindow? session,
    UsageWindow? weekly,
    DateTime? lastStartedAt,
    Outcome? lastOutcome,
    DateTime? lastCheckedAt,
  }) {
    return Status(
      accountId: accountId,
      session: session ?? this.session,
      weekly: weekly ?? this.weekly,
      lastStartedAt: lastStartedAt ?? this.lastStartedAt,
      lastOutcome: lastOutcome ?? this.lastOutcome,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
    );
  }
}
