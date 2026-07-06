import 'dart:io';

import 'package:wakie_core/wakie_core.dart';

/// Prints the LaunchAgent plist for the installed runner binary, using the
/// morning anchor from the local store. Args: `executablePath [stdoutPath]
/// [stderrPath]`. Used by scripts/install_dark_wake.sh so the installed
/// plist always matches the tested `launchAgentPlist` generator.
void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: print_launch_agent_plist.dart <executablePath> [stdoutPath] [stderrPath]');
    exitCode = 64;
    return;
  }
  final store = Store.load();
  stdout.write(launchAgentPlist(
    executablePath: args[0],
    hour: store.morningAnchorHour,
    minute: store.morningAnchorMinute,
    stdoutPath: args.length > 1 ? args[1] : null,
    stderrPath: args.length > 2 ? args[2] : null,
  ));
}
