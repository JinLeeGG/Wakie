import '../status.dart';

/// Parses Codex's `account/rateLimits/read` result into a [ProviderStatus].
///
/// Unlike Claude (a scraped TUI panel), Codex exposes usage as structured JSON
/// over the `codex app-server` JSON-RPC surface — no pty, no VT emulation. The
/// `result` object looks like:
///
/// ```json
/// {"rateLimits":{
///   "primary":  {"usedPercent":1,  "windowDurationMins":300,   "resetsAt":1782984529},
///   "secondary":{"usedPercent":44, "windowDurationMins":10080,  "resetsAt":1783392259},
///   "planType":"plus"}}
/// ```
///
/// `primary` is the ~5h session window, `secondary` the weekly window. A missing
/// window yields [UsageWindow.unknown] rather than throwing (FR-ER). Pure and
/// side-effect free so it can be golden-tested against a captured fixture
/// (PRD §14).
ProviderStatus parseCodexRateLimits(Map<String, dynamic> result) {
  final limits = result['rateLimits'];
  if (limits is! Map<String, dynamic>) return ProviderStatus.unknown;
  return ProviderStatus(
    session: _window(limits['primary']),
    weekly: _window(limits['secondary']),
  );
}

UsageWindow _window(Object? raw) {
  if (raw is! Map<String, dynamic>) return UsageWindow.unknown;
  final used = raw['usedPercent'];
  final resets = raw['resetsAt'];
  return UsageWindow(
    usedPct: used is int ? used : null,
    resetAt: resets is int
        ? DateTime.fromMillisecondsSinceEpoch(resets * 1000)
        : null,
  );
}
