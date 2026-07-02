import '../status.dart';

/// Parses the on-screen text of Claude's `/usage` panel into a [ProviderStatus].
///
/// Input is the rendered panel text (a terminal-grid snapshot), e.g.:
///
/// ```
/// Current session
/// █████████▌ 19% used            Resets 2:30am (America/New_York)
/// Current week (all models)
/// █ 2% used                      Resets Jul 7 at 7am (America/New_York)
/// ```
///
/// A missing window (e.g. while "Loading usage data…") yields
/// [UsageWindow.unknown] rather than throwing (FR-ER). Pure and side-effect
/// free so it can be golden-tested against captured fixtures (PRD §14).
ProviderStatus parseClaudeUsage(String panel) {
  return ProviderStatus(
    session: _windowUnder(panel, RegExp(r'Current session', caseSensitive: false)),
    weekly: _windowUnder(panel, RegExp(r'Current week', caseSensitive: false)),
  );
}

final _sectionEnd = RegExp(r'Current (session|week)|Extra usage', caseSensitive: false);
final _pct = RegExp(r'(\d{1,3})\s*%\s*used', caseSensitive: false);
final _reset = RegExp(r'Resets\s+(.+)$', caseSensitive: false, multiLine: true);

UsageWindow _windowUnder(String panel, RegExp header) {
  final start = header.firstMatch(panel);
  if (start == null) return UsageWindow.unknown;

  final rest = panel.substring(start.end);
  final next = _sectionEnd.firstMatch(rest);
  final section = next == null ? rest : rest.substring(0, next.start);

  final pctMatch = _pct.firstMatch(section);
  final resetMatch = _reset.firstMatch(section);

  return UsageWindow(
    usedPct: pctMatch == null ? null : int.parse(pctMatch.group(1)!),
    resetLabel: resetMatch?.group(1)?.trim(),
  );
}
