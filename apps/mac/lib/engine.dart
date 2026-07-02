import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:wakieai_core/wakieai_core.dart' as core;

import 'models.dart';

/// Runs [command] to sign an account in. Injected so tests never spawn real
/// processes/Terminal. Throws if it can't launch.
typedef LoginRunner = Future<void> Function(String command);

/// Creates an account's isolated config-home directory. Injected so tests
/// never touch the real `~/.wakieai/accounts/` on disk.
typedef DirEnsurer = Future<void> Function(String path);

/// Deletes a removed account's isolated config-home directory. Injected so
/// tests never touch real disk. Best-effort: failure is non-fatal.
typedef DirDeleter = void Function(String path);

/// Makes an isolated config home ready for its provider — Claude: skip
/// onboarding+trust; Antigravity: give it its own login keychain so a second
/// agy account can sign in in isolation. No-op for Codex (CODEX_HOME files).
/// Injected so tests never touch real disk/keychains.
typedef ConfigPreparer = Future<void> Function(
    core.Provider provider, String configHome);

Future<void> _realPrepareConfig(core.Provider provider, String configHome) {
  return switch (provider) {
    core.Provider.claude => core.prepareClaudeConfigHome(configHome),
    core.Provider.antigravity => core.prepareAntigravityConfigHome(configHome),
    core.Provider.codex => Future.value(),
  };
}

/// Runs a browser-OAuth login (`claude auth login`, `codex login`) in the
/// background — no Terminal window. The CLI opens the browser itself and
/// waits for the callback; we don't need a visible terminal for that, so the
/// user just sees the browser. A login *login* shell (`zsh -l`) gives it the
/// user's real PATH (homebrew, npm globals). Detached so it outlives a brief
/// app hiccup; output is dropped (the dashboard tracks completion by polling
/// auth status).
Future<void> _runLoginHidden(String command) async {
  await Process.start('/bin/zsh', ['-lc', command],
      mode: ProcessStartMode.detached);
}

/// Opens a visible Terminal for a login that needs one — Antigravity (`agy`)
/// is an interactive TUI, not a browser-OAuth flow. Uses `open -a Terminal
/// <script>` (Launch Services), which needs no "Automation" TCC grant.
Future<void> _openTerminalWithScript(String command) async {
  final dir = await Directory.systemTemp.createTemp('wakieai_login');
  final script = File('${dir.path}/login.command');
  await script.writeAsString('#!/bin/zsh -l\n$command\n');
  final chmod = await Process.run('chmod', ['+x', script.path]);
  if (chmod.exitCode != 0) {
    throw ProcessException('chmod', ['+x', script.path],
        chmod.stderr.toString(), chmod.exitCode);
  }
  final open = await Process.run('open', ['-a', 'Terminal', script.path]);
  if (open.exitCode != 0) {
    throw ProcessException('open', ['-a', 'Terminal', script.path],
        open.stderr.toString(), open.exitCode);
  }
}

Future<void> _realEnsureDir(String path) async {
  await Directory(path).create(recursive: true);
}

void _realDeleteDir(String path) {
  try {
    final dir = Directory(path);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  } catch (_) {
    // Best-effort — a leftover dir is harmless (not referenced by the store).
  }
}

/// Outcome of polling a pending (added, signing-in) account.
enum SignInState { pending, ready, duplicate, expired }

class SignInResult {
  final SignInState state;
  final Account? row; // populated when [state] == ready
  final String? message; // populated when [state] == duplicate / expired
  const SignInResult(this.state, {this.row, this.message});
}

/// How long a *still-unfinished* sign-in may linger before it's assumed
/// abandoned and auto-removed. Only ever removes accounts that are still not
/// signed in (the poll detects first — a completed login always resolves,
/// never expires), and re-adding the same provider supersedes a stale one
/// anyway, so this is just a generous backstop for genuinely-abandoned
/// attempts. Long enough to never cut off a slow interactive agy login.
const _signinTimeout = Duration(minutes: 15);

/// Hard cap on a single account's usage read, so one wedged interactive scrape
/// can't hang the whole dashboard load — it degrades to "unknown" instead.
const _readTimeout = Duration(seconds: 30);

/// Bridges the WakieAI engine (`packages/core`) to the dashboard's view model.
///
/// Discovers logged-in accounts and reads each one's live `/usage`, mapping
/// the raw core status into the [Account] rows the UI renders.
class Engine {
  final Map<core.Provider, core.ProviderAdapter> _adapters;
  final core.Store _store;
  final LoginRunner _runHidden; // browser-OAuth logins (Claude, Codex)
  final LoginRunner _openTerminal; // TUI login (Antigravity)
  final DirEnsurer _ensureDir;
  final DirDeleter _deleteDir;
  final ConfigPreparer _prepareConfig;

  /// Accounts discovered by the last [watch], keyed by id, so [refreshAccount]
  /// can re-read one without re-detecting everything.
  final Map<String, (core.Account, core.Preflight)> _live = {};

  Engine._(this._adapters, this._store, this._runHidden, this._openTerminal,
      this._ensureDir, this._deleteDir, this._prepareConfig);

  factory Engine.production() => Engine._(
      core.productionAdapters(),
      core.Store.load(),
      _runLoginHidden,
      _openTerminalWithScript,
      _realEnsureDir,
      _realDeleteDir,
      _realPrepareConfig);

  @visibleForTesting
  factory Engine.withAdapters(Map<core.Provider, core.ProviderAdapter> a,
          {core.Store? store,
          LoginRunner? runHidden,
          LoginRunner? openTerminal,
          DirEnsurer? ensureDir,
          DirDeleter? deleteDir,
          ConfigPreparer? prepareConfig}) =>
      Engine._(a, store ?? core.Store.memory(), runHidden ?? (_) async {},
          openTerminal ?? (_) async {}, ensureDir ?? (_) async {},
          deleteDir ?? (_) {}, prepareConfig ?? (_, _) async {});

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
      // Discover everything (including pending extras) so [_live] can track
      // in-flight sign-ins for [pollSignins] — but only *signed-in* accounts
      // become visible rows. A pending extra stays invisible until its login
      // lands and it's confirmed not a duplicate, so nothing ever flashes
      // into the list and back out.
      final all = await core.discoverLiveAccounts(_adapters, _store,
          includePendingExtras: true);
      _live
        ..clear()
        ..addEntries(all.map((e) => MapEntry(e.$1.id, e)));

      final visible = [for (final e in all) if (e.$2.isOk) e];

      // Phase 1: show accounts immediately, with last-known usage from the
      // local store (if any) while a live read is still in flight.
      final rows = [
        for (final (a, pf) in visible)
          _toRow(a, pf, _cachedStatus(a.id), autoStart: _autoStartFor(a)),
      ];
      out.add(List.of(rows));

      // Phase 2: fill each account's usage as its read completes, in
      // parallel. Uses _readReady (not readStatus directly) so an isolated
      // Claude account is made capture-ready first — otherwise its very first
      // load could stall on / get bounced into the onboarding flow.
      await Future.wait([
        for (var i = 0; i < visible.length; i++)
          _readReady(visible[i].$1).then((s) {
            rows[i] = _toRow(visible[i].$1, visible[i].$2, s,
                autoStart: _autoStartFor(visible[i].$1));
            _store.cacheStatus(visible[i].$1.id, s);
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
  ///
  /// Always re-detects first, so Update reflects a login that changed since
  /// the last scan — the account was signed out, or switched to a different
  /// email — rather than showing the stale identity it was discovered with.
  /// (detect is a cheap `auth status`-style check, no browser.) A pending
  /// account that just finished signing in also flips live here.
  Future<Account?> refreshAccount(String id) async {
    final entry = _live[id];
    if (entry == null) return null;
    final account = entry.$1;
    final pf = await _adapters[account.provider]!.detect(account);
    _live[id] = (account, pf);
    if (!pf.isOk) {
      return _toRow(account, pf, core.ProviderStatus.unknown,
          autoStart: _autoStartFor(account));
    }
    final status = await _readReady(account);
    _store.cacheStatus(id, status);
    return _toRow(account, pf, status, autoStart: _autoStartFor(account));
  }

  /// Polls a pending (added, signing-in) account. Cheap by default — just
  /// re-detects; only runs the slow `/usage` read once login actually lands.
  /// Rejects a login that turns out to be the *same* account already managed
  /// (same provider + email) so a duplicate can't sneak in (dedup happens
  /// here, post-login, because the email is only knowable after sign-in).
  Future<SignInResult> checkPendingSignin(String id) async {
    final entry = _live[id];
    if (entry == null) return const SignInResult(SignInState.pending);
    final account = entry.$1;

    // Detect FIRST: a just-completed login must always resolve to a real
    // account, never be wrongly expired mid-sign-in (agy's interactive login
    // can take a few minutes). Only a still-not-signed-in account that's past
    // the timeout is treated as abandoned and removed.
    final pf = await _adapters[account.provider]!.detect(account);
    _live[id] = (account, pf);
    if (!pf.isOk) {
      if (DateTime.now().difference(account.addedAt) > _signinTimeout) {
        removeAccount(id);
        return SignInResult(SignInState.expired,
            message: '${_displayName(account)} sign-in timed out — removed.');
      }
      return const SignInResult(SignInState.pending);
    }

    final dupOf = _duplicateOf(id, account.provider, pf.email);
    if (dupOf != null) {
      removeAccount(id);
      return SignInResult(SignInState.duplicate,
          message: '${pf.email} is already added as "$dupOf" — '
              'removed the duplicate.');
    }

    // Return the row immediately (with any cached usage), so a just-signed-in
    // account appears at once — the caller fills live usage via a follow-up
    // refresh. Without this the row would wait on the full `/usage` scrape,
    // which for a cold isolated Antigravity home can take ~30s.
    return SignInResult(SignInState.ready,
        row: _toRow(account, pf, _cachedStatus(id),
            autoStart: _autoStartFor(account)));
  }

  /// Ids of extra accounts registered but whose sign-in hasn't landed yet —
  /// tracked in [_live] but not shown as rows. The dashboard polls these.
  List<String> pendingSigninIds() => [
        for (final e in _live.entries)
          if (e.value.$1.configHome != null && !e.value.$2.isOk) e.key,
      ];

  /// Polls every in-flight sign-in once, returning only the ones that
  /// resolved (ready with a live row, or a rejected duplicate). Still-pending
  /// accounts are omitted. Cheap when nothing is pending (empty list).
  Future<List<SignInResult>> pollSignins() async {
    final resolved = <SignInResult>[];
    for (final id in pendingSigninIds()) {
      final r = await checkPendingSignin(id);
      if (r.state != SignInState.pending) resolved.add(r);
    }
    return resolved;
  }

  /// Reads an account's usage, first making an isolated config home ready for
  /// its provider (Claude: skip onboarding+trust; Antigravity: symlink the
  /// login keychain) so the interactive scrape doesn't stall on the first-run
  /// flow or a missing-keychain failure.
  ///
  /// A hard [_readTimeout] caps any single read: an interactive TUI scrape
  /// that gets wedged (e.g. a not-yet-warmed isolated Antigravity home) yields
  /// "unknown" instead of hanging the whole dashboard load. The row still
  /// shows; usage just reads as "…" until a later refresh succeeds.
  Future<core.ProviderStatus> _readReady(core.Account account) async {
    if (account.configHome != null) {
      await _prepareConfig(account.provider, account.configHome!);
    }
    try {
      return await _adapters[account.provider]!
          .readStatus(account)
          .timeout(_readTimeout);
    } on TimeoutException {
      debugPrint('wakieai: readStatus timed out for ${account.id}');
      return core.ProviderStatus.unknown;
    }
  }

  /// The display name of an already-managed account with the same provider and
  /// email as [id], or null if [id] isn't a duplicate. Compares against the
  /// live set (ambient defaults + other extras), ignoring [id] itself.
  String? _duplicateOf(String id, core.Provider provider, String? email) {
    if (email == null || email.isEmpty) return null;
    final target = email.toLowerCase().trim();
    for (final e in _live.values) {
      final (other, otherPf) = e;
      if (other.id == id || other.provider != provider || !otherPf.isOk) {
        continue;
      }
      if ((otherPf.email ?? '').toLowerCase().trim() == target) {
        return _displayName(other);
      }
    }
    return null;
  }

  bool _autoStartFor(core.Account a) =>
      _store.autoStartPreference(a.id) ?? core.defaultAutoStart(a.provider);

  /// Removes an account (the row's Remove action). Persisted so the next
  /// discovery/refresh doesn't resurrect it, and its isolated config dir is
  /// deleted so removed extras don't pile up under ~/.wakieai/accounts/.
  void removeAccount(String id) {
    final configHome = _live[id]?.$1.configHome ??
        _store.extraAccounts
            .where((e) => e.id == id)
            .map((e) => e.configHome)
            .firstOrNull;
    _store.removeAccount(id);
    _live.remove(id);
    // Only ever delete inside the accounts sandbox root — never a path the
    // engine didn't create (the ambient default's configHome is null anyway).
    if (configHome != null &&
        configHome.startsWith(core.Store.defaultAccountsDir())) {
      _deleteDir(configHome);
    }
  }

  /// Starts adding an isolated account: registers it, then launches the
  /// provider's login (Claude/Codex open a browser silently; Antigravity
  /// needs a visible Terminal). The row shows as "signing in" until the login
  /// lands (see [checkPendingSignin]). Read-only for existing accounts.
  ///
  /// Returns null on success, or a human-readable error message — never
  /// throws, so a failure is always something the caller can show the user.
  Future<String?> addAccount(Provider uiProvider, String label) async {
    final provider = _coreProvider(uiProvider);

    // A previous, unfinished sign-in for this provider is treated as
    // abandoned: clear it (and its empty config dir) so this fresh attempt
    // supersedes it, rather than blocking the user with "already in progress".
    final stale = [
      for (final e in _live.values)
        if (e.$1.provider == provider &&
            e.$1.configHome != null &&
            !e.$2.isOk)
          e.$1.id,
    ];
    for (final staleId in stale) {
      removeAccount(staleId);
    }

    final safeLabel = label.trim().isEmpty ? 'extra' : label.trim();
    final id = '${provider.name}-${DateTime.now().millisecondsSinceEpoch}';
    final configHome = '${core.Store.defaultAccountsDir()}/$id';

    try {
      await _ensureDir(configHome);
      // Make the isolated home login-ready before launching the CLI: Claude
      // skips onboarding/trust; Antigravity gets its own login keychain so it
      // signs in as a separate account (no-op for Codex).
      await _prepareConfig(provider, configHome);
    } catch (e) {
      debugPrint('wakieai: addAccount could not create/prepare $configHome — $e');
      return "Couldn't create $configHome";
    }

    final extra = core.ExtraAccount(
      id: id,
      provider: provider,
      label: safeLabel,
      configHome: configHome,
      addedAt: DateTime.now(),
    );
    _store.addExtraAccount(extra);
    // Seed _live so a dedup / status poll can act on it before the next full
    // discovery, carrying a not-ok preflight (still signing in).
    _live[id] = (extra.toAccount(), const core.Preflight(core.PreflightState.notLoggedIn));

    try {
      switch (provider) {
        case core.Provider.claude:
          await _runHidden('CLAUDE_CONFIG_DIR="$configHome" claude auth login');
        case core.Provider.codex:
          await _runHidden('CODEX_HOME="$configHome" codex login');
        case core.Provider.antigravity:
          // agy is a TUI (no headless flow) so it needs a real Terminal. Its
          // sandbox already has its own isolated login keychain (prepared
          // above), so it signs in as a *separate* account.
          await _openTerminal('HOME="$configHome" agy');
      }
    } catch (e) {
      debugPrint('wakieai: addAccount could not launch login — $e');
      return 'Added, but the login could not be launched. Try Update on the '
          'row, or sign in manually.';
    }
    return null;
  }

  /// The account's auto-start (session-chaining) toggle — the user's
  /// explicit choice if they've set one, else the provider's R0-informed
  /// default (D1: Claude on, Codex/Antigravity off).
  bool autoStartEnabled(String id) {
    final entry = _live[id];
    return entry == null ? false : _autoStartFor(entry.$1);
  }

  void setAutoStart(String id, bool enabled) => _store.setAutoStart(id, enabled);

  int get morningAnchorHour => _store.morningAnchorHour;
  int get morningAnchorMinute => _store.morningAnchorMinute;
  void setMorningAnchor(int hour, int minute) =>
      _store.setMorningAnchor(hour, minute);

  /// Convenience for tests/one-shot callers: the final, fully-loaded rows.
  Future<List<Account>> load() => watch().last;

  core.ProviderStatus _cachedStatus(String id) {
    final cached = _store.statusFor(id);
    return cached == null
        ? core.ProviderStatus.unknown
        : core.ProviderStatus(session: cached.session, weekly: cached.weekly);
  }
}

Account _toRow(core.Account a, core.Preflight pf, core.ProviderStatus s,
    {required bool autoStart}) {
  final session = _meter(s.session, weekly: false);
  return Account(
    id: a.id,
    provider: _uiProvider(a.provider),
    name: _displayName(a),
    plan: pf.isOk
        ? _subtitle(pf,
            fallbackEmail: s.accountEmail, fallbackPlan: s.accountPlan)
        : 'signing in — complete it in your browser',
    session: session,
    weekly: _meter(s.weekly, weekly: true),
    last: pf.isOk ? 'just now' : '—',
    status: !pf.isOk
        ? RunStatus.signin
        : session.pct < 20
            ? RunStatus.low
            : RunStatus.ok,
    autoStart: autoStart,
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

/// Unifies every provider's reset wording to one absolute unit: a bare clock
/// time for the session window, a date + time for the weekly window —
/// regardless of how the provider reported it. Resolution to an absolute
/// instant lives in core ([core.resolveResetAt]) so the same logic is
/// available to the headless runner (alerts, auto-start chaining); this only
/// formats it for display. Falls back to the raw (timezone-stripped) label
/// when core can't resolve it (defensive — shouldn't happen for known
/// provider formats).
String _resetLabel(core.UsageWindow w, {required bool weekly}) {
  final at = core.resolveResetAt(w);
  if (at == null) return _shortReset(w.resetLabel);
  final local = at.toLocal();
  return weekly ? '${_fmtDate(local)} (${_fmtTime(local)})' : _fmtTime(local);
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

/// Account subtitle: "email · Plan", dropping the redundant provider name
/// (the row's icon + title already say the provider). Shows whichever halves
/// the provider exposes — email-only, plan-only, or "—" when neither.
/// [fallbackEmail]/[fallbackPlan] (from the usage panel) fill in when the
/// preflight lacks them, as for Antigravity where identity/tier only appear
/// in the scraped panel header.
String _subtitle(core.Preflight pf,
    {String? fallbackEmail, String? fallbackPlan}) {
  String? pick(String? a, String? b) =>
      (a != null && a.isNotEmpty) ? a : ((b != null && b.isNotEmpty) ? b : null);
  final email = pick(pf.email, fallbackEmail);
  final plan = pick(pf.plan, fallbackPlan);
  final parts = <String>[
    ?email,
    if (plan != null) plan[0].toUpperCase() + plan.substring(1),
  ];
  return parts.isEmpty ? '—' : parts.join(' · ');
}

String _displayName(core.Account a) {
  final base = _providerLabel(a.provider);
  return a.label == 'default' ? base : '$base · ${a.label}';
}

String _providerLabel(core.Provider p) => switch (p) {
      core.Provider.claude => 'Claude',
      core.Provider.codex => 'Codex',
      core.Provider.antigravity => 'Antigravity',
    };

Provider _uiProvider(core.Provider p) => switch (p) {
      core.Provider.claude => Provider.claude,
      core.Provider.codex => Provider.codex,
      core.Provider.antigravity => Provider.anti,
    };

core.Provider _coreProvider(Provider p) => switch (p) {
      Provider.claude => core.Provider.claude,
      Provider.codex => core.Provider.codex,
      Provider.anti => core.Provider.antigravity,
    };
