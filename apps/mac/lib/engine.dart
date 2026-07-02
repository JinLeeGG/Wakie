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

  Engine._(this._adapters);

  factory Engine.production() {
    final claude = core.ClaudeAdapter(
      capture: (a) => core.captureClaudeUsagePanel(env: _envFor(a)),
    );
    return Engine._({core.Provider.claude: claude});
  }

  @visibleForTesting
  factory Engine.withAdapters(Map<core.Provider, core.ProviderAdapter> a) =>
      Engine._(a);

  static Map<String, String> _envFor(core.Account a) => a.configHome == null
      ? const {}
      : {'CLAUDE_CONFIG_DIR': a.configHome!};

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

  /// Convenience for tests/one-shot callers: the final, fully-loaded rows.
  Future<List<Account>> load() => watch().last;
}

Account _toRow(core.Account a, core.Preflight pf, core.ProviderStatus s) {
  final session = _meter(s.session);
  return Account(
    provider: _uiProvider(a.provider),
    name: _displayName(a),
    plan: '${a.provider.name} · ${pf.detail ?? '—'}',
    session: session,
    weekly: _meter(s.weekly),
    last: 'just now',
    status: session.pct < 20 ? RunStatus.low : RunStatus.ok,
  );
}

/// The UI shows remaining ("N% left"), while the provider reports used.
Meter _meter(core.UsageWindow w) {
  if (!w.isKnown) return const Meter(0, Tone.warn, '…');
  final remaining = (100 - w.usedPct!).clamp(0, 100);
  final tone = remaining < 20
      ? Tone.crit
      : remaining < 50
          ? Tone.warn
          : Tone.ok;
  return Meter(remaining, tone, _shortReset(w.resetLabel));
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
