import '../status.dart';

/// Parses the on-screen text of Antigravity's `/usage` panel into a
/// [ProviderStatus].
///
/// Input is the rendered panel text (a terminal-grid snapshot), e.g.:
///
/// ```
/// GEMINI MODELS
///   Weekly Limit
///     [██████████] 99.42%
///     99% remaining · Refreshes in 125h 16m
///   Five Hour Limit
///     [█████████░] 98.21%
///     98% remaining · Refreshes in 4h 44m
/// CLAUDE AND GPT MODELS
///   Weekly Limit
///     [██████████] 100.00%
///     Quota available
/// ```
///
/// Antigravity reports two model groups (Gemini vs Claude/GPT), each with a
/// weekly and a five-hour window — four meters in total. WakieAI's dashboard
/// shows one session + one weekly meter, so each window collapses to its
/// **most-constrained group** (least remaining): the meter never overstates the
/// headroom you actually have before the nearest wall.
///
/// A missing window yields [UsageWindow.unknown] rather than throwing (FR-ER).
/// Pure and side-effect free so it can be golden-tested against captured
/// fixtures (PRD §14).
ProviderStatus parseAntigravityUsage(String panel) {
  final weekly = <UsageWindow>[];
  final session = <UsageWindow>[];
  List<UsageWindow>? current;

  for (final line in panel.split('\n')) {
    if (_weeklyHdr.hasMatch(line)) {
      current = weekly;
    } else if (_sessionHdr.hasMatch(line)) {
      current = session;
    } else if (current != null) {
      final w = _readWindow(line);
      if (w != null) {
        current.add(w);
        current = null; // one window per header
      }
    }
  }

  return ProviderStatus(
    session: _mostConstrained(session),
    weekly: _mostConstrained(weekly),
    accountEmail: _email.firstMatch(panel)?.group(0),
    accountPlan: _planFrom(panel),
  );
}

// The panel header shows the signed-in account, e.g.
// "wakieDemo1@gmail.com (Antigravity Starter Quota)". Not a secret (an
// identifier), and the only place an isolated account's email is exposed.
final _email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+');

// Plan tier from the same header — the parenthesized text right after the
// email: "(Google AI Pro)" / "(Antigravity Starter Quota)". Boilerplate
// ("Google AI", "Antigravity", trailing "Quota") is stripped so it reads as
// the bare tier ("Pro", "Starter") like the other providers' plans.
final _emailPlan =
    RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+\s*\(([^)\n]{2,40})\)');

String? _planFrom(String panel) {
  final raw = _emailPlan.firstMatch(panel)?.group(1)?.trim();
  if (raw == null || raw.isEmpty) return null;
  final plan = raw
      .replaceFirst(RegExp(r'^Google AI\s+', caseSensitive: false), '')
      .replaceFirst(RegExp(r'^Antigravity\s+', caseSensitive: false), '')
      .replaceFirst(RegExp(r'\s+Quota$', caseSensitive: false), '')
      .trim();
  return plan.isEmpty ? raw : plan;
}
final _weeklyHdr = RegExp(r'Weekly Limit', caseSensitive: false);
final _sessionHdr = RegExp(r'Five[- ]?Hour Limit', caseSensitive: false);
final _remaining = RegExp(r'(\d{1,3})%\s*remaining', caseSensitive: false);
final _refreshes = RegExp(r'Refreshes in\s+(.+?)\s*$', caseSensitive: false);
final _quota = RegExp(r'Quota available', caseSensitive: false);

/// Reads a limit's value line ("N% remaining · Refreshes in Xh Ym" or
/// "Quota available"), or null if [line] isn't one (e.g. the bar or a blank).
UsageWindow? _readWindow(String line) {
  final rem = _remaining.firstMatch(line);
  if (rem != null) {
    return UsageWindow(
      usedPct: 100 - int.parse(rem.group(1)!),
      resetLabel: _refreshes.firstMatch(line)?.group(1)?.trim(),
    );
  }
  if (_quota.hasMatch(line)) {
    return const UsageWindow(usedPct: 0); // full quota, no reset shown
  }
  return null;
}

/// The group with the least remaining (highest used) wins — the binding limit.
UsageWindow _mostConstrained(List<UsageWindow> windows) {
  if (windows.isEmpty) return UsageWindow.unknown;
  return windows.reduce((a, b) => (b.usedPct ?? 0) > (a.usedPct ?? 0) ? b : a);
}
