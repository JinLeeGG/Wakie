import 'dart:io';

/// Runs a macOS `security` subcommand. Injected so tests never touch real
/// keychains. Returns the process result.
typedef SecurityRunner = Future<ProcessResult> Function(List<String> args);

Future<ProcessResult> _realSecurity(List<String> args) =>
    Process.run('security', args);

/// Gives an isolated Antigravity config home ([configHome], used as `HOME` for
/// `agy`) its OWN empty login keychain, so a second `agy` account can sign in
/// independently of the system one.
///
/// Why this is needed: `agy` keeps its OAuth token in the macOS **login
/// keychain**, which the Security framework resolves from `$HOME`. Overriding
/// HOME alone makes agy find *no* keychain ("Keychain Not Found" dialog) so
/// the login can't persist. Symlinking the real keychain instead makes agy
/// reuse the *existing* account (not isolated). The fix that actually isolates:
/// create a fresh, empty `login.keychain-db` inside the sandbox HOME. agy then
/// stores this account's token there, separate from every other account —
/// verified: `HOME=sandbox agy` reports "please sign in" (no leakage of the
/// system account).
///
/// Crucially this does NOT pollute the user's global keychain search list:
/// `create-keychain` adds the new keychain to that list, so we immediately
/// restore the saved list. The sandbox keychain stays reachable only via the
/// sandbox HOME. Empty password → auto-unlockable; no auto-lock timeout so agy
/// can read it unattended (e.g. during a dark-wake refresh).
///
/// Best-effort and idempotent: never throws, safe to re-run (re-unlocks an
/// existing keychain).
Future<void> prepareAntigravityConfigHome(String configHome,
    {SecurityRunner? runSecurity}) async {
  final run = runSecurity ?? _realSecurity;
  final keychainsDir = '$configHome/Library/Keychains';
  final keychain = '$keychainsDir/login.keychain-db';
  try {
    Directory(keychainsDir).createSync(recursive: true);

    if (!File(keychain).existsSync()) {
      // Save the current user search list so we can restore it after
      // create-keychain (which would otherwise leave the sandbox keychain in
      // the global list).
      final before = await run(['list-keychains', '-d', 'user']);
      final original = _parseKeychainList(before.stdout.toString());

      await run(['create-keychain', '-p', '', keychain]);
      if (original.isNotEmpty) {
        await run(['list-keychains', '-d', 'user', '-s', ...original]);
      }
      // No auto-lock, so agy can read it during unattended refreshes.
      await run(['set-keychain-settings', keychain]);
    }

    // Ensure it's unlocked before agy touches it (empty password).
    await run(['unlock-keychain', '-p', '', keychain]);
  } catch (_) {
    // Best-effort — without it, agy shows "Keychain Not Found" and the user
    // can retry; we never leave the global keychain list broken.
  }
}

/// Parses `security list-keychains` output (quoted, indented paths) into a
/// plain list of keychain paths.
List<String> _parseKeychainList(String output) => [
      for (final line in output.split('\n'))
        if (line.trim().isNotEmpty) line.trim().replaceAll('"', ''),
    ];
