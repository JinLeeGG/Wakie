import 'account.dart';
import 'adapter.dart';
import 'adapters/antigravity_adapter.dart';
import 'adapters/antigravity_usage_capture.dart';
import 'adapters/claude_adapter.dart';
import 'adapters/claude_usage_capture.dart';
import 'adapters/codex_adapter.dart';
import 'adapters/codex_app_server.dart';
import 'provider.dart';

/// Wires the three provider adapters against the real CLIs (pty scraping,
/// app-server JSON-RPC). The one production adapter map shared by the Mac
/// GUI engine and the headless runner (PRD §9.2), so the account-isolation
/// env vars (`CLAUDE_CONFIG_DIR`/`CODEX_HOME`/`HOME`) are wired in exactly
/// one place.
Map<Provider, ProviderAdapter> productionAdapters() => {
      Provider.claude: ClaudeAdapter(
        // Isolated (extra) accounts run the capture inside their own config
        // home so prepareClaudeConfigHome's pre-trusted dir matches; the
        // ambient default keeps the process's own cwd.
        capture: (a) => captureClaudeUsagePanel(
            env: _claudeEnv(a), workingDirectory: a.configHome),
      ),
      Provider.codex: CodexAdapter(
        read: (a) => readCodexRateLimits(env: _codexEnv(a)),
        readAccount: (a) => readCodexAccount(env: _codexEnv(a)),
      ),
      Provider.antigravity: AntigravityAdapter(
        capture: (a) => captureAntigravityUsagePanel(env: _antigravityEnv(a)),
      ),
    };

Map<String, String> _claudeEnv(Account a) =>
    a.configHome == null ? const {} : {'CLAUDE_CONFIG_DIR': a.configHome!};

Map<String, String> _codexEnv(Account a) =>
    a.configHome == null ? const {} : {'CODEX_HOME': a.configHome!};

Map<String, String> _antigravityEnv(Account a) =>
    a.configHome == null ? const {} : {'HOME': a.configHome!};
