import 'dart:convert';
import 'dart:io';

/// Makes an isolated Claude config home ([configHome], the `CLAUDE_CONFIG_DIR`)
/// ready for headless `/usage` scraping by pre-accepting the two first-run
/// gates that otherwise block the interactive TUI:
///
///   1. `hasCompletedOnboarding` — skips the theme picker.
///   2. `projects[configHome].hasTrustDialogAccepted` — skips the "trust this
///      folder?" prompt (the capture runs `claude` with cwd = configHome).
///
/// Without this, a freshly `claude auth login`'d config dir launches into
/// onboarding, the capture's `/usage` + Enter keystrokes fall through to the
/// onboarding steps, and a stray Enter can even re-trigger a browser login —
/// so this is what stops the "browser keeps popping up" behaviour for
/// user-added accounts. Merges into any existing `.claude.json`, so it's safe
/// to run before or after login. Best-effort: never throws.
Future<void> prepareClaudeConfigHome(String configHome) async {
  try {
    final file = File('$configHome/.claude.json');
    Map<String, dynamic> json = {};
    if (file.existsSync()) {
      try {
        json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      } catch (_) {
        json = {};
      }
    }

    json['hasCompletedOnboarding'] = true;
    json['theme'] ??= 'dark';

    final projects = (json['projects'] as Map<String, dynamic>?) ?? {};
    projects[configHome] = {
      ...(projects[configHome] as Map<String, dynamic>? ?? const {}),
      'hasTrustDialogAccepted': true,
      'projectOnboardingSeenCount': 1,
      'hasClaudeMdExternalIncludesApproved': false,
      'hasClaudeMdExternalIncludesWarningShown': false,
      'allowedTools': <String>[],
    };
    json['projects'] = projects;

    file.parent.createSync(recursive: true);
    file.writeAsStringSync(jsonEncode(json));
  } catch (_) {
    // Best-effort — a capture that still hits onboarding just yields unknown
    // usage, which the dashboard already tolerates.
  }
}
