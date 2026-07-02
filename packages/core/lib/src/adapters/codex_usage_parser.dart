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
/// On a paid plan `primary` is the ~5h session window and `secondary` the
/// weekly window. But a **free** plan reports a single ~30-day window as
/// `primary` and no `secondary` — so keying off position alone would mislabel
/// a 30-day window as the "5h session". Instead each window is placed by its
/// `windowDurationMins`: > 6h goes to the long (weekly) slot, everything else
/// (including a window with no stated duration, kept for back-compat) to the
/// session slot. A missing window yields [UsageWindow.unknown] rather than
/// throwing (FR-ER). Pure and side-effect free so it can be golden-tested
/// against a captured fixture (PRD §14).
ProviderStatus parseCodexRateLimits(Map<String, dynamic> result) {
  final limits = result['rateLimits'];
  if (limits is! Map<String, dynamic>) return ProviderStatus.unknown;
  final primary = limits['primary'];
  final primaryDur =
      primary is Map<String, dynamic> ? primary['windowDurationMins'] : null;

  // Free plans report a single long (~30-day) window as `primary` with no
  // `secondary`. Show that in the weekly (long-window) slot rather than
  // mislabelling it as the 5h session. Otherwise keep the positional default:
  // primary = session, secondary = weekly.
  if (primaryDur is int && primaryDur > 360) {
    return ProviderStatus(session: UsageWindow.unknown, weekly: _window(primary));
  }
  return ProviderStatus(
    session: _window(primary),
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
