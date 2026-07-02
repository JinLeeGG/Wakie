import 'status.dart';

const _months = [
  'jan', 'feb', 'mar', 'apr', 'may', 'jun', //
  'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
];

/// Resolves a [UsageWindow]'s reset to an absolute local [DateTime],
/// regardless of how the provider reported it (PRD §10.3 Q4):
///
///   - Codex already gives an absolute epoch → returned as-is.
///   - Antigravity gives a countdown ("4h 25m", "5d 2h") → `now + duration`.
///   - Claude gives a rendered wall-clock string ("2:30am (America/New_York)",
///     "Jul 7 at 7am (America/New_York)") → parsed directly. The CLI always
///     runs on this same Mac, so that clock time already *is* local time; the
///     "(timezone)" suffix is display-only and safely dropped.
///
/// Pure function of the window + [now] (injectable for tests) — no I/O. This
/// lives in core (not the Mac app's UI layer) because the headless runner
/// (Phase 1: auto-start chaining, alerts) needs it without any Flutter
/// dependency. Returns null when [UsageWindow.resetLabel] doesn't match any
/// known shape.
DateTime? resolveResetAt(UsageWindow w, {DateTime? now}) {
  if (w.resetAt != null) return w.resetAt;
  final label = w.resetLabel;
  if (label == null) return null;
  final at = now ?? DateTime.now();
  return _fromDuration(label, at) ?? _fromClockString(label, at);
}

/// "125h 16m", "3h 13m", "5d 2h", "45m" → `now + duration`. Null when it
/// isn't a duration (e.g. Claude's "2:30am"), so the caller tries the next
/// shape.
DateTime? _fromDuration(String label, DateTime now) {
  final m = RegExp(r'^(?:(\d+)\s*d)?\s*(?:(\d+)\s*h)?\s*(?:(\d+)\s*m)?$')
      .firstMatch(label.trim());
  if (m == null ||
      (m.group(1) == null && m.group(2) == null && m.group(3) == null)) {
    return null;
  }
  final days = int.tryParse(m.group(1) ?? '') ?? 0;
  final hours = int.tryParse(m.group(2) ?? '') ?? 0;
  final mins = int.tryParse(m.group(3) ?? '') ?? 0;
  if (days == 0 && hours == 0 && mins == 0) return null;
  return now.add(Duration(days: days, hours: hours, minutes: mins));
}

/// Claude's two rendered shapes, timezone suffix stripped:
///   - "7:36am"                → time-of-day; rolls to tomorrow if past.
///   - "Jul 7 at 7am" / "7:30" → month + day + time; rolls to next year if
///     that date already passed this year.
DateTime? _fromClockString(String raw, DateTime now) {
  final paren = raw.indexOf('(');
  final label = (paren == -1 ? raw : raw.substring(0, paren)).trim();

  final withDate = RegExp(
    r'^([A-Za-z]{3})[a-z]*\s+(\d{1,2})\s+at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)$',
    caseSensitive: false,
  ).firstMatch(label);
  if (withDate != null) {
    final month = _months.indexOf(withDate.group(1)!.toLowerCase()) + 1;
    if (month == 0) return null;
    final day = int.parse(withDate.group(2)!);
    final hour = _hour24(withDate.group(3)!, withDate.group(5)!);
    final minute = int.tryParse(withDate.group(4) ?? '0') ?? 0;
    var at = DateTime(now.year, month, day, hour, minute);
    if (at.isBefore(now)) at = DateTime(now.year + 1, month, day, hour, minute);
    return at;
  }

  final timeOnly =
      RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*(am|pm)$', caseSensitive: false)
          .firstMatch(label);
  if (timeOnly != null) {
    final hour = _hour24(timeOnly.group(1)!, timeOnly.group(3)!);
    final minute = int.tryParse(timeOnly.group(2) ?? '0') ?? 0;
    var at = DateTime(now.year, now.month, now.day, hour, minute);
    if (at.isBefore(now)) at = at.add(const Duration(days: 1));
    return at;
  }

  return null;
}

int _hour24(String h, String ampm) {
  final hour = int.parse(h) % 12;
  return ampm.toLowerCase() == 'pm' ? hour + 12 : hour;
}
