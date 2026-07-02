import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wakieai_core/wakieai_core.dart' as core;

import 'models.dart';

/// Bridges the WakieAI engine (`packages/core`) to the dashboard's view model.
///
/// Discovers logged-in accounts and reads each one's live `/usage`, mapping
/// the raw core status into the [Account] rows the UI renders.
class Engine {
  final Map<core.Provider, core.ProviderAdapter> _adapters;

  /// Accounts discovered by the last [watch], keyed by id, so [refreshAccount]
  /// can re-read one without re-detecting everything.
  final Map<String, (core.Account, core.Preflight)> _live = {};

  Engine._(this._adapters);

  factory Engine.production() {
    final claude = core.ClaudeAdapter(
      capture: (a) => core.captureClaudeUsagePanel(env: _claudeEnv(a)),
    );
    final codex = core.CodexAdapter(
      read: (a) => core.readCodexRateLimits(env: _codexEnv(a)),
    );
    final antigravity = core.AntigravityAdapter(
      capture: (a) => core.captureAntigravityUsagePanel(env: _antigravityEnv(a)),
    );
    return Engine._({
      core.Provider.claude: claude,
      core.Provider.codex: codex,
      core.Provider.antigravity: antigravity,
    });
  }

  @visibleForTesting
  factory Engine.withAdapters(Map<core.Provider, core.ProviderAdapter> a) =>
      Engine._(a);

  static Map<String, String> _claudeEnv(core.Account a) => a.configHome == null
      ? const {}
      : {'CLAUDE_CONFIG_DIR': a.configHome!};

  static Map<String, String> _codexEnv(core.Account a) => a.configHome == null
      ? const {}
      : {'CODEX_HOME': a.configHome!};

  static Map<String, String> _antigravityEnv(core.Account a) =>
      a.configHome == null ? const {} : {'HOME': a.configHome!};

  /// Emits account rows in two phases so the dashboard fills fast:
  ///   1. detect all providers in parallel → emit rows with usage still loading;
  ///   2. read each account's `/usage` in parallel → re-emit as each completes.
  Stream<List<Account>> watch() {
    final controller = StreamController<List<Account>>();
    _run(controller);
    return controller.stream;
  }

  Future<void> _run(StreamController<List<Account>> out) async {
    try {
      final candidates = core.defaultCandidateAccounts(_adapters.keys);
      final preflights = await Future.wait(
          candidates.map((a) => _adapters[a.provider]!.detect(a)));

      final live = <(core.Account, core.Preflight)>[
        for (var i = 0; i < candidates.length; i++)
          if (preflights[i].isOk) (candidates[i], preflights[i]),
      ];

      // Remember the discovered accounts so a single row can be refreshed
      // on demand (the per-account Update button) without a full rescan.
      _live
        ..clear()
        ..addEntries(live.map((e) => MapEntry(e.$1.id, e)));

      // Phase 1: show the accounts immediately, usage still loading.
      final rows = [
        for (final (a, pf) in live) _toRow(a, pf, core.ProviderStatus.unknown),
      ];
      out.add(List.of(rows));

      // Phase 2: fill each account's usage as its read completes.
      await Future.wait([
        for (var i = 0; i < live.length; i++)
          _adapters[live[i].$1.provider]!.readStatus(live[i].$1).then((s) {
            rows[i] = _toRow(live[i].$1, live[i].$2, s);
            out.add(List.of(rows));
          }),
      ]);
    } finally {
      await out.close();
    }
  }

  /// Re-reads one account's usage live (the per-account Update button).
  /// Read-only — no session is started, so it costs no quota. Returns the
  /// refreshed row, or null if the id isn't among the discovered accounts.
  Future<Account?> refreshAccount(String id) async {
    final entry = _live[id];
    if (entry == null) return null;
    final (account, pf) = entry;
    final status = await _adapters[account.provider]!.readStatus(account);
    return _toRow(account, pf, status);
  }

  /// Convenience for tests/one-shot callers: the final, fully-loaded rows.
  Future<List<Account>> load() => watch().last;
}

Account _toRow(core.Account a, core.Preflight pf, core.ProviderStatus s) {
  final session = _meter(s.session, weekly: false);
  return Account(
    id: a.id,
    provider: _uiProvider(a.provider),
    name: _displayName(a),
    plan: '${a.provider.name} · ${pf.detail ?? '—'}',
    session: session,
    weekly: _meter(s.weekly, weekly: true),
    last: 'just now',
    status: session.pct < 20 ? RunStatus.low : RunStatus.ok,
  );
}

/// The UI shows remaining ("N% left"), while the provider reports used.
Meter _meter(core.UsageWindow w, {required bool weekly}) {
  if (!w.isKnown) return const Meter(0, Tone.warn, '…');
  final remaining = (100 - w.usedPct!).clamp(0, 100);
  final tone = remaining < 20
      ? Tone.crit
      : remaining < 50
          ? Tone.warn
          : Tone.ok;
  return Meter(remaining, tone, _resetLabel(w, weekly: weekly));
}

/// Codex reports an absolute [resetAt] (epoch); Claude a rendered [resetLabel].
/// Show a date for the weekly window, a time for the session window — matching
/// the mock's "Jul 7" / "4:30 AM" columns.
String _resetLabel(core.UsageWindow w, {required bool weekly}) {
  final at = w.resetAt;
  if (at != null) {
    final local = at.toLocal();
    return weekly ? _fmtDate(local) : _fmtTime(local);
  }
  return _shortReset(w.resetLabel);
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';

String _fmtTime(DateTime d) {
  final ampm = d.hour < 12 ? 'am' : 'pm';
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final mm = d.minute.toString().padLeft(2, '0');
  return '$h12:$mm$ampm';
}

/// Drops the "(timezone)" suffix: "2:30am (America/New_York)" → "2:30am".
String _shortReset(String? label) {
  if (label == null) return '—';
  final paren = label.indexOf('(');
  return (paren == -1 ? label : label.substring(0, paren)).trim();
}

String _displayName(core.Account a) {
  final provider = _uiProvider(a.provider);
  final base = switch (provider) {
    Provider.claude => 'Claude',
    Provider.codex => 'Codex',
    Provider.anti => 'Antigravity',
  };
  return a.label == 'default' ? base : '$base · ${a.label}';
}

Provider _uiProvider(core.Provider p) => switch (p) {
      core.Provider.claude => Provider.claude,
      core.Provider.codex => Provider.codex,
      core.Provider.antigravity => Provider.anti,
    };
