import 'dart:io';

import 'privileged.dart';

/// Support for going back to sleep after a scheduled dark wake.
///
/// macOS offers no third-party "wake without the display" — an RTC wake
/// (`pmset repeat`) is always a full user wake. The next best thing: detect
/// that nobody is at the machine, keep the display dark while the runner
/// works, and put the Mac back to sleep when it's done. "Nobody is here" is
/// judged from two kernel facts, not guesses: the system woke only moments
/// ago (kern.waketime) and there has been zero human input since (IOKit
/// HIDIdleTime spans the whole time since wake).

/// Parses `sysctl kern.waketime` output, e.g.
/// `{ sec = 1751513580, usec = 123456 } Fri Jul  3 00:33:00 2026`.
DateTime? parseKernWakeTime(String output) {
  final m = RegExp(r'sec\s*=\s*(\d+)').firstMatch(output);
  if (m == null) return null;
  final sec = int.parse(m.group(1)!);
  if (sec == 0) return null; // never slept since boot
  return DateTime.fromMillisecondsSinceEpoch(sec * 1000);
}

/// Parses `HIDIdleTime` (nanoseconds since last keyboard/mouse input) out of
/// `ioreg -c IOHIDSystem` output. Null when the field is missing.
double? parseHidIdleSeconds(String output) {
  final m = RegExp(r'"HIDIdleTime"\s*=\s*(\d+)').firstMatch(output);
  if (m == null) return null;
  return int.parse(m.group(1)!) / 1e9;
}

/// When the machine last woke from sleep, or null if unknown/never.
Future<DateTime?> lastWakeAt({ProcessRun run = Process.run}) async {
  final r = await run('sysctl', ['-n', 'kern.waketime']);
  if (r.exitCode != 0) return null;
  return parseKernWakeTime(r.stdout as String);
}

/// Seconds since the last keyboard/mouse input, or null if unreadable.
Future<double?> hidIdleSeconds({ProcessRun run = Process.run}) async {
  final r = await run('ioreg', ['-c', 'IOHIDSystem', '-d', '4']);
  if (r.exitCode != 0) return null;
  return parseHidIdleSeconds(r.stdout as String);
}

/// True when this process is running inside an unattended scheduled wake:
/// the system woke within [wakeWindow] and no human input has arrived since
/// (the idle span covers the whole time awake). Any doubt — missing data,
/// input after wake, a long-awake machine — reads as attended, so callers
/// never dim or sleep a Mac someone is using.
bool unattendedWake({
  required DateTime now,
  required DateTime? wokeAt,
  required double? idleSeconds,
  Duration wakeWindow = const Duration(minutes: 10),
}) {
  if (wokeAt == null || idleSeconds == null) return false;
  final sinceWake = now.difference(wokeAt);
  if (sinceWake.isNegative || sinceWake > wakeWindow) return false;
  return idleSeconds >= sinceWake.inMilliseconds / 1000;
}

/// Best-effort: turn the display off (no root needed). A dark-wake pass
/// shouldn't leave the screen glowing while it scrapes.
Future<void> displaySleep({ProcessRun run = Process.run}) async {
  try {
    await run('pmset', ['displaysleepnow']);
  } catch (_) {
    // Best-effort.
  }
}

/// Puts the machine back to sleep: `pmset sleepnow` first, then AppleScript
/// as a fallback (some setups restrict one but not the other). Returns null
/// on success or a short reason string for the runner's log.
Future<String?> systemSleep({ProcessRun run = Process.run}) async {
  try {
    final direct = await run('pmset', ['sleepnow']);
    if (direct.exitCode == 0) return null;
    final script = await run('osascript',
        ['-e', 'tell application "System Events" to sleep']);
    if (script.exitCode == 0) return null;
    return 'pmset: ${(direct.stderr as String).trim()} / '
        'osascript: ${(script.stderr as String).trim()}';
  } catch (e) {
    return '$e';
  }
}
