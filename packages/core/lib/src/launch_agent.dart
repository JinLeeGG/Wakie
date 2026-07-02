/// LaunchAgent + `pmset` artifacts for dark-wake scheduling (PRD §9.2, §16).
///
/// Scope for this pass: a single **daily** dark wake at the morning anchor
/// (PRD's confirmed §15 flow — "아침 기상 → 상태 갱신/체이닝"). A
/// `StartCalendarInterval` with only Hour/Minute set (no Year/Month/Day)
/// recurs every day at that clock time, so the plist is installed once and
/// never needs rewriting. Waking for each account's own mid-day reset would
/// need dynamically re-scheduling `pmset schedule wake` after every run —
/// meaningfully more moving parts for a background job with no one watching
/// it — so it's left for a later pass; the daily anchor already catches up
/// any lapsed session the moment the Mac wakes.
///
/// Pure string generation only — installing the plist (`launchctl`) and
/// programming the hardware wake (`sudo pmset`) are separate, explicit steps
/// (see `packages/core/scripts/install_dark_wake.sh`) since both mutate real
/// system state and `pmset`'s wake schedule needs admin (FR-UI-05).
library;

const wakieaiLaunchAgentLabel = 'ai.wakie.runner';

/// The LaunchAgent plist that runs [executablePath] once a day at
/// [hour]:[minute] local time.
String launchAgentPlist({
  required String executablePath,
  required int hour,
  required int minute,
  String label = wakieaiLaunchAgentLabel,
  String? stdoutPath,
  String? stderrPath,
}) {
  final out = stdoutPath == null
      ? ''
      : '\n  <key>StandardOutPath</key>\n  <string>$stdoutPath</string>';
  final err = stderrPath == null
      ? ''
      : '\n  <key>StandardErrorPath</key>\n  <string>$stderrPath</string>';
  return '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$label</string>
  <key>ProgramArguments</key>
  <array>
    <string>$executablePath</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>$hour</integer>
    <key>Minute</key>
    <integer>$minute</integer>
  </dict>
  <key>RunAtLoad</key>
  <false/>$out$err
</dict>
</plist>
''';
}

/// The `pmset` command that programs a daily hardware wake at [hour]:[minute]
/// (`MTWRFSU` = every day). Requires admin — printed for the user to run
/// themselves rather than executed on their behalf (FR-UI-05).
String pmsetDailyWakeCommand({required int hour, required int minute}) {
  final hh = hour.toString().padLeft(2, '0');
  final mm = minute.toString().padLeft(2, '0');
  return 'sudo pmset repeat wakeorpoweron MTWRFSU $hh:$mm:00';
}

const wakieaiLoginItemLabel = 'ai.wakie.app';

/// The LaunchAgent plist that opens the WakieAI app at login (the footer's
/// "Launch at login" toggle). RunAtLoad-only — launchd starts it once per
/// login session and never restarts it (no KeepAlive; quitting stays quit).
String loginItemPlist({required String executablePath}) => '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$wakieaiLoginItemLabel</string>
  <key>ProgramArguments</key>
  <array>
    <string>$executablePath</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
''';
