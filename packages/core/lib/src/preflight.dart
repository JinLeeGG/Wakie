/// Per-provider CLI health for an account (PRD §7.5 FR-OB-02).
enum PreflightState {
  ok,
  notInstalled,
  notLoggedIn,
  outdated,
  needsOnboarding,
}

class Preflight {
  final PreflightState state;

  /// Detected CLI version, when resolvable.
  final String? version;

  /// Human-readable detail for the dashboard (e.g. why it's not ok).
  final String? detail;

  /// Signed-in account identity (the login email), when the provider exposes
  /// it. Not a secret — never a token (R0). Null when unavailable.
  final String? email;

  /// Subscription tier as the provider names it (e.g. "pro", "max", "plus").
  /// Null when the provider exposes no plan.
  final String? plan;

  const Preflight(this.state, {this.version, this.detail, this.email, this.plan});

  bool get isOk => state == PreflightState.ok;
}

/// Outcome of starting a session (PRD §10.3, FR-RN-04).
class RunOutcome {
  final bool ok;
  final DateTime startedAt;
  final String? error;

  const RunOutcome({required this.ok, required this.startedAt, this.error});
}
