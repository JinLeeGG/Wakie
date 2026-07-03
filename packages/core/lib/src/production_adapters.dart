import 'dart:io';

import 'account.dart';
import 'adapter.dart';
import 'adapters/antigravity_adapter.dart';
import 'adapters/antigravity_usage_capture.dart';
import 'adapters/claude_adapter.dart';
import 'adapters/claude_usage_capture.dart';
import 'adapters/codex_adapter.dart';
import 'adapters/codex_app_server.dart';
import 'provider.dart';

/// Locates a provider CLI by name: `$PATH` first (terminal launches), then
/// the well-known install dirs. Needed because launchd- and Finder-launched
/// processes get a minimal PATH (`/usr/bin:/bin:/usr/sbin:/sbin`) with no
/// `~/.local/bin` or `/opt/homebrew/bin` — a bare name that works in a
/// terminal finds nothing under dark wake. Falls back to the bare [name] so
/// a missing CLI still fails as "not installed", not as a crash here.
String resolveCli(String name, {Map<String, String>? environment}) {
  final env = environment ?? Platform.environment;
  final home = env['HOME'];
  final dirs = [
    ...?env['PATH']?.split(':'),
    if (home != null) '$home/.local/bin',
    '/opt/homebrew/bin',
    '/usr/local/bin',
    if (home != null) '$home/.npm-global/bin',
  ];
  for (final dir in dirs) {
    if (dir.isEmpty) continue;
    final file = File('$dir/$name');
    if (file.existsSync()) return file.path;
  }
  return name;
}

/// Wires the three provider adapters against the real CLIs (pty scraping,
/// app-server JSON-RPC). The one production adapter map shared by the Mac
/// GUI engine and the headless runner (PRD §9.2), so the account-isolation
/// env vars (`CLAUDE_CONFIG_DIR`/`CODEX_HOME`/`HOME`) and CLI path
/// resolution are wired in exactly one place.
Map<Provider, ProviderAdapter> productionAdapters() {
  final claude = resolveCli('claude');
  final codex = resolveCli('codex');
  final agy = resolveCli('agy');
  return {
    Provider.claude: ClaudeAdapter(
      executable: claude,
      // Isolated (extra) accounts run the capture inside their own config
      // home so prepareClaudeConfigHome's pre-trusted dir matches; the
      // ambient default keeps the process's own cwd.
      capture: (a) => captureClaudeUsagePanel(
          executable: claude,
          env: _claudeEnv(a),
          workingDirectory: a.configHome),
    ),
    Provider.codex: CodexAdapter(
      executable: codex,
      read: (a) => readCodexRateLimits(executable: codex, env: _codexEnv(a)),
      readAccount: (a) =>
          readCodexAccount(executable: codex, env: _codexEnv(a)),
    ),
    Provider.antigravity: AntigravityAdapter(
      executable: agy,
      capture: (a) =>
          captureAntigravityUsagePanel(executable: agy, env: _antigravityEnv(a)),
    ),
  };
}

Map<String, String> _claudeEnv(Account a) =>
    a.configHome == null ? const {} : {'CLAUDE_CONFIG_DIR': a.configHome!};

Map<String, String> _codexEnv(Account a) =>
    a.configHome == null ? const {} : {'CODEX_HOME': a.configHome!};

Map<String, String> _antigravityEnv(Account a) =>
    a.configHome == null ? const {} : {'HOME': a.configHome!};
