import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'engine.dart' show SignInResult, SignInState;
import 'models.dart';
import 'theme.dart';
import 'tray_icon.dart';
import 'widgets/account_row.dart';
import 'widgets/add_account_modal.dart';
import 'widgets/confirm_modal.dart';
import 'widgets/footer.dart';
import 'widgets/summary.dart';

/// Lets the app ask the dashboard to run a full refresh — e.g. the moment the
/// window is opened from the menu bar, so you always see current data.
class DashboardController extends ChangeNotifier {
  void refreshAll() => notifyListeners();
}

class DashboardScreen extends StatefulWidget {
  /// Streams live account data (two-phase: accounts first, usage as it loads).
  /// When null (tests/goldens) the dashboard renders the static [mockAccounts]
  /// so widget/golden output stays deterministic.
  final Stream<List<Account>> Function()? source;

  /// Reports the menu-bar icon state (working while busy, attention when an
  /// account needs action, else idle) so the tray reflects it. Null in tests.
  final void Function(TrayState state)? onTrayState;

  /// Fires a full refresh when notified (the window opening from the tray).
  final DashboardController? controller;

  /// Re-reads one account's usage live (per-account Update). Returns the
  /// refreshed row, or null if it can't be resolved. Null in tests/goldens.
  final Future<Account?> Function(Account)? onUpdateAccount;

  /// Persists a Remove action so the account doesn't resurface on the next
  /// discovery/refresh. Null in tests/goldens (removal stays in-memory only).
  final void Function(Account)? onRemoveAccount;

  /// Persists the auto-start (session-chaining) toggle for one account
  /// (D1). Null in tests/goldens.
  final void Function(Account, bool enabled)? onSetAutoStart;

  /// Launches the new account's login and registers it (FR-UI-04). Returns
  /// null on success or an error message to show. Null in tests/goldens — the
  /// Add Account modal still opens, it just has nothing to submit to.
  final Future<String?> Function(Provider, String label)? onCreateAccount;

  /// Polls all in-flight sign-ins once, returning the ones that resolved
  /// (ready with a live row, or a rejected duplicate). Pending accounts never
  /// appear as rows — they surface only once signed in and confirmed unique,
  /// so nothing flashes into the list and back out. Null in tests/goldens.
  final Future<List<SignInResult>> Function()? onPollSignins;

  /// The daily dark-wake time shown/edited in the summary bar (PRD §9.2).
  /// The setter reprograms an enabled dark wake to match; it returns an error
  /// to surface (anchor reverted) or null on success.
  final int morningAnchorHour;
  final int morningAnchorMinute;
  final Future<String?> Function(int hour, int minute)? onSetMorningAnchor;

  /// One awake-cycle pass (auto-start lapsed windows + alerts) — run
  /// periodically while the app is open. Returns the refreshed rows to swap
  /// in. Null in tests/goldens.
  final Future<List<Account>> Function()? onAwakeTick;

  /// "Launch at login" — current state + toggle handler (installs/removes the
  /// login item). Null handler in tests/goldens.
  final bool launchAtLogin;
  final Future<void> Function(bool)? onSetLaunchAtLogin;

  /// "Wake from sleep" — current state + toggle handler (programs/cancels the
  /// daily hardware wake via an admin prompt; returns an error to surface or
  /// null on success). Null handler in tests/goldens.
  final bool darkWake;
  final Future<String?> Function(bool)? onSetDarkWake;

  const DashboardScreen({
    super.key,
    this.source,
    this.onTrayState,
    this.controller,
    this.onUpdateAccount,
    this.onRemoveAccount,
    this.onSetAutoStart,
    this.onCreateAccount,
    this.onPollSignins,
    this.morningAnchorHour = 8,
    this.morningAnchorMinute = 0,
    this.onSetMorningAnchor,
    this.onAwakeTick,
    this.launchAtLogin = false,
    this.onSetLaunchAtLogin,
    this.darkWake = false,
    this.onSetDarkWake,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late final AnimationController _winIn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  late final List<Account> _accounts = widget.source == null
      ? List.of(mockAccounts)
      : <Account>[];
  bool _loading = false;
  StreamSubscription<List<Account>>? _sub;

  int _tagIdx = 0;
  bool _tagFaded = false;
  Timer? _tagTimer;

  // When usage was last read — drives the header's "Updated Xm ago". The tag
  // timer's 7s setState already re-renders the header, so the label re-ages
  // without a timer of its own.
  DateTime? _lastRefresh;

  // Row currently under the cursor — the Resets-in card counts down to this
  // account's session reset instead of the soonest one.
  String? _hoveredId;

  Account? _pendingRemove;
  bool _addingAccount = false;

  // Footer run sequence.
  final FooterController _footer = FooterController();

  Timer? _signinPoll;
  bool _polling = false; // re-entrancy guard: never overlap sign-in polls

  Timer? _awakeTimer;
  bool _ticking = false; // re-entrancy guard for the awake tick

  // Morning anchor + launch-at-login mirrored into state so the summary
  // bar and toggles track edits live (widget values are initial only).
  late int _anchorHour = widget.morningAnchorHour;
  late int _anchorMinute = widget.morningAnchorMinute;
  late bool _launchAtLogin = widget.launchAtLogin;
  late bool _darkWake = widget.darkWake;
  bool _darkWakeBusy = false; // one configure (admin prompt) at a time

  TrayState? _lastTray;

  @override
  void initState() {
    super.initState();
    // Go through the footer (progress bar) even on the first scan, so the tray
    // "working" spinner and the footer bar always show together.
    if (widget.source != null) _refreshAll();
    // The footer's running flag drives the "working" tray state; account/
    // loading changes are picked up by the post-frame report in build().
    _footer.addListener(_reportTray);
    // Refresh everything when the app asks (window opened from the menu bar).
    widget.controller?.addListener(_refreshAll);
    _tagTimer = Timer.periodic(const Duration(seconds: 7), (_) async {
      setState(() => _tagFaded = true);
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() {
        _tagIdx = (_tagIdx + 1) % taglines.length;
        _tagFaded = false;
      });
    });
    // While any account is waiting on its sign-in, quietly re-check it so the
    // row flips to live usage the moment login completes — no manual Refresh
    // needed. No-op when nothing is pending; guarded so a slow check can't
    // stack up overlapping polls.
    _signinPoll = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _pollPendingSignins(),
    );
    // While awake, watch for session windows lapsing so auto-start chains a
    // new one (D1) and alerts fire — the dark-wake runner covers the asleep
    // hours; this covers the Mac sitting open all day. Pure clock/store math
    // per tick; subprocesses only run when a window actually lapses.
    _awakeTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _awakeTick(),
    );
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_refreshAll);
    _sub?.cancel();
    _tagTimer?.cancel();
    _signinPoll?.cancel();
    _awakeTimer?.cancel();
    _winIn.dispose();
    _footer.dispose();
    super.dispose();
  }

  /// Earliest upcoming session reset across accounts. Mock rows carry no
  /// instant (null), so goldens stay deterministic and the card's tooltip
  /// stays off there.
  DateTime? _nextResetAt() {
    final now = DateTime.now();
    DateTime? next;
    for (final a in _accounts) {
      final at = a.sessionResetAt;
      if (at == null || at.isBefore(now)) continue;
      if (next == null || at.isBefore(next)) next = at;
    }
    return next;
  }

  /// Maps the dashboard's live state to a menu-bar icon state and reports it
  /// (de-duped): busy → working, any account low/awaiting-signin → attention,
  /// else idle.
  void _reportTray() {
    final report = widget.onTrayState;
    if (report == null) return;
    final TrayState s;
    if (_loading || _footer.running) {
      s = TrayState.working;
    } else if (_accounts.any((a) =>
        a.status == RunStatus.low || a.status == RunStatus.signin)) {
      s = TrayState.attention;
    } else {
      s = TrayState.idle;
    }
    if (s != _lastTray) {
      _lastTray = s;
      report(s);
    }
  }

  void _setHovered(String id, bool hovering) {
    final next = hovering ? id : (_hoveredId == id ? null : _hoveredId);
    if (next == _hoveredId) return;
    setState(() => _hoveredId = next);
  }

  /// The Resets-in card's value: a countdown to the hovered row's session
  /// reset, or — with nothing hovered — to the soonest reset across accounts.
  /// "—" for a hovered account with no session window (free plans), and a
  /// fixed value under the static mock so goldens stay deterministic.
  String _resetCardValue() {
    final id = _hoveredId;
    if (id != null) {
      final i = _accounts.indexWhere((a) => a.id == id);
      if (i != -1) {
        final at = _accounts[i].sessionResetAt;
        return at == null ? '—' : untilLabel(at);
      }
    }
    final soonest = _nextResetAt();
    if (soonest != null) return untilLabel(soonest);
    return widget.source == null ? '4h 30m' : '—';
  }

  Future<void> _awakeTick() async {
    if (_ticking) return;
    final tick = widget.onAwakeTick;
    if (tick == null) return;
    _ticking = true;
    try {
      // The tick returns fully-built rows from the status it just cached —
      // swap them in as-is. (Re-reading them live here would double the
      // scrape and overwrite the engine's failure backoff.)
      final rows = await tick();
      if (!mounted || rows.isEmpty) return;
      setState(() {
        for (final row in rows) {
          final i = _accounts.indexWhere((a) => a.id == row.id);
          if (i != -1) _accounts[i] = row;
        }
        _lastRefresh = DateTime.now();
      });
    } finally {
      _ticking = false;
    }
  }

  Future<void> _pollPendingSignins() async {
    if (_polling) return; // a previous poll is still running
    final poll = widget.onPollSignins;
    if (poll == null) return;
    _polling = true;
    try {
      final results = await poll();
      if (!mounted) return;
      for (final r in results) {
        switch (r.state) {
          case SignInState.pending:
            break; // pending accounts are never shown
          case SignInState.ready:
            final row = r.row!;
            setState(() {
              final i = _accounts.indexWhere((x) => x.id == row.id);
              if (i == -1) {
                _accounts.add(row);
              } else {
                _accounts[i] = row;
              }
            });
            _footer.finish('${row.name} signed in');
            // The ready row carries only cached usage (it appears instantly);
            // pull its live usage now, which also fills in an isolated
            // account's email from the scraped panel.
            _update(row);
          case SignInState.duplicate:
            _footer.fail(r.message ?? 'Already added.');
          case SignInState.expired:
            _footer.fail(r.message ?? 'Sign-in timed out.');
        }
      }
    } finally {
      _polling = false;
    }
  }

  void _reload({bool footer = false}) {
    final source = widget.source;
    if (source == null || _loading) return;
    _sub?.cancel();
    setState(() => _loading = true);
    // watch() emits the account list first (usage still loading), then re-emits
    // once per account as its live /usage read completes — so emissions after
    // the first map directly onto real loading progress.
    var total = 0;
    var loaded = 0;
    var first = true;
    _sub = source().listen(
      (accounts) {
        if (!mounted) return;
        setState(() {
          _accounts
            ..clear()
            ..addAll(accounts);
          _lastRefresh = DateTime.now();
        });
        if (!footer) return;
        if (first) {
          first = false;
          total = accounts.length;
        } else if (total > 0) {
          loaded++;
          _footer.progress(loaded / total);
        }
      },
      onDone: () {
        if (mounted) setState(() => _loading = false);
        if (footer) _footer.finish('All accounts up to date');
        _retryUnknowns();
      },
    );
  }

  /// Re-reads accounts that came back with no data at all (both windows "—") —
  /// the fragile Claude/Antigravity TUI scrape occasionally returns an empty
  /// panel. Only when it's a *partial* miss (others read fine), so a genuine
  /// offline state isn't hammered; _update carries its own single retry.
  void _retryUnknowns() {
    final unknowns = _accounts
        .where((a) =>
            a.id.isNotEmpty &&
            !a.session.known &&
            !a.weekly.known &&
            a.status != RunStatus.signin)
        .toList();
    if (unknowns.isEmpty || unknowns.length == _accounts.length) return;
    for (final a in unknowns) {
      _update(a);
    }
  }

  /// Per-account Update: show the footer bar and, if wired, re-read just this
  /// account live — the bar completes when the real read returns, swapping the
  /// row in. (Mock mode has no real read, so it finishes on a short delay.)
  void _update(Account a, {bool retried = false}) {
    _footer.start('Refreshing ${a.name}…');
    final updater = widget.onUpdateAccount;
    if (updater == null) {
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (mounted) _footer.finish('${a.name} refreshed');
      });
      return;
    }
    updater(a).then((fresh) {
      if (!mounted) return;
      if (fresh != null) {
        final i = _accounts.indexWhere((x) => x.id == a.id);
        if (i != -1) {
          setState(() {
            _accounts[i] = fresh;
            _lastRefresh = DateTime.now();
          });
        }
      }
      // A cold isolated home's very first scrape can miss (the engine
      // degrades it to unknown rather than throwing). Retry once before
      // reporting — and never claim "refreshed" over an empty read.
      final unknown =
          fresh != null &&
          !fresh.session.known &&
          !fresh.weekly.known &&
          fresh.status != RunStatus.signin;
      if (unknown && !retried) {
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) _update(a, retried: true);
        });
        return; // keep the bar running through the retry
      }
      if (unknown) {
        _footer.fail('${a.name}: couldn\'t read usage — try Update');
      } else {
        _footer.finish('${a.name} refreshed');
      }
    });
  }

  void _askRemove(Account a) => setState(() => _pendingRemove = a);

  void _confirmRemove() {
    final removed = _pendingRemove;
    setState(() {
      if (removed != null) _accounts.remove(removed);
      _pendingRemove = null;
    });
    if (removed != null) widget.onRemoveAccount?.call(removed);
  }

  void _setAutoStart(Account a, bool enabled) {
    final i = _accounts.indexWhere((x) => x.id == a.id);
    if (i != -1) {
      setState(
        () => _accounts[i] = Account(
          id: a.id,
          provider: a.provider,
          name: a.name,
          plan: a.plan,
          session: a.session,
          weekly: a.weekly,
          status: a.status,
          autoStart: enabled,
          autoStartAvailable: a.autoStartAvailable,
          sessionResetAt: a.sessionResetAt,
        ),
      );
    }
    widget.onSetAutoStart?.call(a, enabled);
  }

  Future<void> _createAccount(Provider provider, String label) async {
    setState(() => _addingAccount = false);
    final creator = widget.onCreateAccount;
    if (creator == null) return;
    final displayLabel = label.trim().isEmpty ? provider.name : label.trim();
    _footer.start('Adding $displayLabel…');
    final error = await creator(provider, label);
    if (!mounted) return;
    if (error != null) {
      _footer.fail(error);
    } else {
      _footer.finish('$displayLabel — finish signing in in your browser');
    }
    // No rescan: the account stays invisible until its login lands, at which
    // point the sign-in poll adds it as a row (or drops it if it's a
    // duplicate) — so nothing ever flashes into the list and back out.
  }

  @override
  Widget build(BuildContext context) {
    // Re-derive the tray state after each build so account/loading changes
    // reach the menu bar (de-duped inside _reportTray).
    if (widget.onTrayState != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reportTray();
      });
    }
    // The footer advertises ⌘R / ⌘N — wire them for real (autofocus so the
    // panel catches the keys the moment it opens). Per-account Update stays a
    // row action; there's no focused "current row" for a global ↵ to target.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): _refreshAll,
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
            () => setState(() => _addingAccount = true),
      },
      child: Focus(
        autofocus: true,
        child: _scaffold(),
      ),
    );
  }

  void _refreshAll() {
    // Already scanning — ignore repeat triggers (⌘R, the button, or a
    // window-open signal) so they can't restart the progress bar over a run
    // that's already going.
    if (_loading) return;
    _footer.start('Refreshing accounts…');
    _reload(footer: true);
  }

  Widget _scaffold() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // The dashboard is designed on a fixed 1000x640 canvas and scaled
          // up to fill the window, so type + spacing grow uniformly.
          // BoxFit.contain keeps the scale UNIFORM (never stretches type) — the
          // window is sized to this exact aspect in MainFlutterWindow.swift, so
          // it fills edge-to-edge; any residual mismatch shows a hairline margin
          // instead of squishing the text. Must match designWidth/designHeight.
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: 1000,
                height: 640,
                child: AnimatedBuilder(
                  animation: _winIn,
                  builder: (context, child) {
                    final t = Curves.easeOutCubic.transform(_winIn.value);
                    return Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(0, (1 - t) * 10),
                        child: Transform.scale(
                          scale: 0.985 + 0.015 * t,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: _panel(),
                ),
              ),
            ),
          ),
          if (_pendingRemove != null)
            ConfirmModal(
              account: _pendingRemove!,
              onCancel: () => setState(() => _pendingRemove = null),
              onRemove: _confirmRemove,
            ),
          if (_addingAccount)
            AddAccountModal(
              onCancel: () => setState(() => _addingAccount = false),
              onAdd: _createAccount,
            ),
        ],
      ),
    );
  }

  Widget _panel() {
    final accounts = _orderedAccounts();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: T.glass,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: T.hair2),
      ),
      child: Stack(
        children: [
          // top sheen
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [T.white(.06), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          Column(
            children: [
              _header(),
              SummaryBar(
                accountCount: _accounts.length,
                runningLow: _accounts
                    .where((a) => a.status == RunStatus.low)
                    .length,
                nextReset: _resetCardValue(),
                onAddAccount: () => setState(() => _addingAccount = true),
                morningAnchorHour: _anchorHour,
                morningAnchorMinute: _anchorMinute,
                onSetMorningAnchor: (h, m) async {
                  final prevH = _anchorHour, prevM = _anchorMinute;
                  setState(() {
                    _anchorHour = h;
                    _anchorMinute = m;
                  });
                  // With dark wake enabled this reprograms the schedule (an
                  // admin prompt); a cancelled/failed reprogram reverts the
                  // anchor so the UI never promises a wake the hardware
                  // won't honor.
                  final error = await widget.onSetMorningAnchor?.call(h, m);
                  if (!mounted || error == null) return;
                  setState(() {
                    _anchorHour = prevH;
                    _anchorMinute = prevM;
                  });
                  _footer.fail(error);
                },
              ),
              const _ColHead(),
              Expanded(
                child: _loading && _accounts.isEmpty
                    ? Center(
                        child: Text(
                          'Scanning accounts…',
                          style: mono(13, color: T.t2),
                        ),
                      )
                    : _TopListFade(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                          itemCount: accounts.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 2),
                          itemBuilder: (context, i) {
                            final account = accounts[i];
                            return AccountRow(
                              key: ValueKey(
                                account.id.isEmpty
                                    ? '${account.provider.name}:${account.name}:${account.plan}'
                                    : account.id,
                              ),
                              account: account,
                              animDelayMs: 70 + i * 60,
                              onRemove: () => _askRemove(account),
                              onUpdate: () => _update(account),
                              onHover: (h) => _setHovered(account.id, h),
                              onAutoStartChanged: (enabled) =>
                                  _setAutoStart(account, enabled),
                            );
                          },
                        ),
                      ),
              ),
              DashboardFooter(
                controller: _footer,
                onRefreshAll: _refreshAll,
                onAddAccount: () => setState(() => _addingAccount = true),
                launchAtLogin: _launchAtLogin,
                onLaunchAtLogin: (on) {
                  setState(() => _launchAtLogin = on);
                  widget.onSetLaunchAtLogin?.call(on);
                },
                darkWake: _darkWake,
                onDarkWake: (on) async {
                  // One configure at a time: a second tap while the admin
                  // prompt is up would race a second osascript against the
                  // same plist/pmset state.
                  if (_darkWakeBusy) return null;
                  setState(() => _darkWake = on); // optimistic
                  final handler = widget.onSetDarkWake;
                  if (handler == null) return null; // mock/goldens: just flip
                  // No progress bar here: the work is a blocking admin prompt,
                  // so a trickling bar just climbs while the user types their
                  // password. The toggle itself is the feedback; only a real
                  // failure surfaces (and snaps the toggle back).
                  _darkWakeBusy = true;
                  String? error;
                  try {
                    error = await handler(on);
                  } catch (e) {
                    error = '$e'; // sync IO / launchctl can throw, not return
                  } finally {
                    _darkWakeBusy = false;
                  }
                  if (!mounted) return error;
                  if (error != null) {
                    setState(() => _darkWake = !on); // snap back on failure
                    _footer.fail(error);
                  }
                  return error;
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Account> _orderedAccounts() {
    final indexed = <({int index, Account account})>[];
    for (var i = 0; i < _accounts.length; i++) {
      indexed.add((index: i, account: _accounts[i]));
    }
    indexed.sort((a, b) {
      final provider = _providerOrder(
        a.account.provider,
      ).compareTo(_providerOrder(b.account.provider));
      if (provider != 0) return provider;
      return a.index.compareTo(b.index);
    });
    return [for (final entry in indexed) entry.account];
  }

  int _providerOrder(Provider provider) => switch (provider) {
    Provider.claude => 0,
    Provider.codex => 1,
    Provider.anti => 2,
  };

  /// How long since usage was last read, in words. Empty until the first
  /// read lands (the pill shows "Syncing…" then).
  String _freshnessLabel() {
    final at = _lastRefresh;
    if (at == null) return '';
    final d = DateTime.now().difference(at);
    if (d.inSeconds < 45) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  // The brand lives in the footer now — up here the rotating tagline IS the
  // header, full-size, with the freshness pill riding its centerline.
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 20, 26, 14),
      child: Row(
        children: [
          Expanded(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 500),
              opacity: _tagFaded ? 0 : 1,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 500),
                offset: _tagFaded ? const Offset(0, -0.25) : Offset.zero,
                child: Text(
                  taglines[_tagIdx],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: sans(31, weight: FontWeight.w600, color: T.t1),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          _FreshnessPill(label: _freshnessLabel()),
        ],
      ),
    );
  }
}

/// Data-freshness readout: how long since the last successful usage read. The
/// only load-bearing part of the old device pill — the device name and power
/// state were Phase-1 noise (always "this Mac", always "awake") and wait for
/// the multi-device Phase 2. The dot is a quiet "live" cue.
class _FreshnessPill extends StatelessWidget {
  final String label;
  const _FreshnessPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: T.white(.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: T.hair),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: T.ok,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: T.ok.withValues(alpha: .7), blurRadius: 10),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label.isEmpty ? 'Syncing…' : 'Updated $label',
            style: mono(13, color: T.t2),
          ),
        ],
      ),
    );
  }
}

class _TopListFade extends StatelessWidget {
  final Widget child;
  const _TopListFade({required this.child});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.white, Colors.white],
        stops: [0, .065, 1],
      ).createShader(bounds),
      child: child,
    );
  }
}

class _ColHead extends StatelessWidget {
  const _ColHead();

  @override
  Widget build(BuildContext context) {
    final style =
        mono(12.5, weight: FontWeight.w500, color: T.t2, letterSpacing: 1.3);
    // Each header explains itself on hover — the columns are terse by design.
    Widget label(String t, String tip, {TextAlign align = TextAlign.left}) =>
        Tooltip(
          message: tip,
          waitDuration: const Duration(milliseconds: 250),
          child: MouseRegion(
            cursor: SystemMouseCursors.help,
            child: Text(t.toUpperCase(), textAlign: align, style: style),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 4, 28, 6),
      child: Row(
        children: [
          // AUTO sits over the switches at the account cell's right edge,
          // naming the column so the toggle reads as a setting, not a badge.
          // Terse now that the header explains itself on hover.
          SizedBox(
            width: 272,
            child: Row(
              children: [
                label('Account', 'Your logged-in AI accounts.'),
                const Spacer(),
                label('Auto', 'Auto-starts a session when this window resets.'),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: label(
                'Current', '5-hour session window — % left and reset time.'),
          ),
          const SizedBox(width: 16),
          Expanded(
            child:
                label('Weekly', 'Weekly quota — % left and reset time.'),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 190,
            child: label('Status', 'Shown only when an account needs attention.',
                align: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
