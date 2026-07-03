import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'engine.dart' show SignInResult, SignInState, formatClock;
import 'models.dart';
import 'theme.dart';
import 'widgets/account_row.dart';
import 'widgets/add_account_modal.dart';
import 'widgets/confirm_modal.dart';
import 'widgets/footer.dart';
import 'widgets/summary.dart';

const _logoSvg =
    '<svg viewBox="0 0 100 100"><circle cx="50" cy="50" r="38" fill="none" stroke="#fff" stroke-width="6"/>'
    '<circle cx="50" cy="50" r="22" fill="#f6b23c"/></svg>';

class DashboardScreen extends StatefulWidget {
  /// Streams live account data (two-phase: accounts first, usage as it loads).
  /// When null (tests/goldens) the dashboard renders the static [mockAccounts]
  /// so widget/golden output stays deterministic.
  final Stream<List<Account>> Function()? source;

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
  final int morningAnchorHour;
  final int morningAnchorMinute;
  final void Function(int hour, int minute)? onSetMorningAnchor;

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

  late final List<Account> _accounts =
      widget.source == null ? List.of(mockAccounts) : <Account>[];
  bool _loading = false;
  StreamSubscription<List<Account>>? _sub;

  int _tagIdx = 0;
  bool _tagFaded = false;
  Timer? _tagTimer;

  Account? _pendingRemove;
  bool _addingAccount = false;

  // Footer run sequence.
  final FooterController _footer = FooterController();

  Timer? _signinPoll;
  bool _polling = false; // re-entrancy guard: never overlap sign-in polls

  Timer? _awakeTimer;
  bool _ticking = false; // re-entrancy guard for the awake tick

  // Morning anchor + launch-at-login mirrored into state so the footer's
  // "next wake" and toggle track edits live (widget values are initial only).
  late int _anchorHour = widget.morningAnchorHour;
  late int _anchorMinute = widget.morningAnchorMinute;
  late bool _launchAtLogin = widget.launchAtLogin;
  late bool _darkWake = widget.darkWake;

  @override
  void initState() {
    super.initState();
    if (widget.source != null) _reload();
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
        const Duration(seconds: 6), (_) => _pollPendingSignins());
    // While awake, watch for session windows lapsing so auto-start chains a
    // new one (D1) and alerts fire — the dark-wake runner covers the asleep
    // hours; this covers the Mac sitting open all day. Pure clock/store math
    // per tick; subprocesses only run when a window actually lapses.
    _awakeTimer =
        Timer.periodic(const Duration(seconds: 60), (_) => _awakeTick());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tagTimer?.cancel();
    _signinPoll?.cancel();
    _awakeTimer?.cancel();
    _winIn.dispose();
    _footer.dispose();
    super.dispose();
  }

  /// Earliest upcoming session reset across accounts, in the rows' clock
  /// format. Mock rows carry no instant, so goldens keep the mockup's value.
  String _nextResetLabel() {
    if (widget.source == null) return '4:30am'; // static mock (deterministic)
    final now = DateTime.now();
    DateTime? next;
    for (final a in _accounts) {
      final at = a.sessionResetAt;
      if (at == null || at.isBefore(now)) continue;
      if (next == null || at.isBefore(next)) next = at;
    }
    return next == null ? '—' : formatClock(next);
  }

  /// Next occurrence of the morning anchor (today if still ahead, else
  /// tomorrow) — what the footer's "next wake" promises.
  DateTime _nextWake() {
    final now = DateTime.now();
    var at = DateTime(now.year, now.month, now.day, _anchorHour, _anchorMinute);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    return at;
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
        setState(() => _accounts
          ..clear()
          ..addAll(accounts));
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
      },
    );
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
        if (i != -1) setState(() => _accounts[i] = fresh);
      }
      // A cold isolated home's very first scrape can miss (the engine
      // degrades it to unknown rather than throwing). Retry once before
      // reporting — and never claim "refreshed" over an empty read.
      final unknown = fresh != null &&
          fresh.session.reset == '…' &&
          fresh.weekly.reset == '…' &&
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
      setState(() => _accounts[i] = Account(
            id: a.id,
            provider: a.provider,
            name: a.name,
            plan: a.plan,
            session: a.session,
            weekly: a.weekly,
            last: a.last,
            status: a.status,
            autoStart: enabled,
          ));
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
              name: _pendingRemove!.name,
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
                nextReset: _nextResetLabel(),
                onAddAccount: () => setState(() => _addingAccount = true),
                morningAnchorHour: _anchorHour,
                morningAnchorMinute: _anchorMinute,
                onSetMorningAnchor: (h, m) {
                  setState(() {
                    _anchorHour = h;
                    _anchorMinute = m;
                  });
                  widget.onSetMorningAnchor?.call(h, m);
                },
              ),
              const _ColHead(),
              Expanded(
                child: _loading && _accounts.isEmpty
                    ? Center(
                        child: Text('Scanning accounts…',
                            style: mono(13, color: T.t2)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        itemCount: _accounts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 2),
                        itemBuilder: (context, i) => AccountRow(
                          account: _accounts[i],
                          animDelayMs: 70 + i * 60,
                          onRemove: () => _askRemove(_accounts[i]),
                          onUpdate: () => _update(_accounts[i]),
                          onAutoStartChanged: (enabled) =>
                              _setAutoStart(_accounts[i], enabled),
                        ),
                      ),
              ),
              DashboardFooter(
                controller: _footer,
                onRefreshAll: () {
                  _footer.start('Refreshing accounts…');
                  _reload(footer: true);
                },
                onAddAccount: () => setState(() => _addingAccount = true),
                nextWake: formatClock(_nextWake()),
                launchAtLogin: _launchAtLogin,
                onLaunchAtLogin: (on) {
                  setState(() => _launchAtLogin = on);
                  widget.onSetLaunchAtLogin?.call(on);
                },
                darkWake: _darkWake,
                onDarkWake: (on) async {
                  final handler = widget.onSetDarkWake;
                  if (handler == null) return null;
                  setState(() => _darkWake = on); // optimistic
                  // No progress bar here: the work is a blocking admin prompt,
                  // so a trickling bar just climbs while the user types their
                  // password. The toggle itself is the feedback; only a real
                  // failure surfaces (and snaps the toggle back).
                  final error = await handler(on);
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

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 16, 26, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // brand
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: SvgPicture.string(_logoSvg),
                      ),
                      const SizedBox(width: 9),
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: 'Wakie',
                            style: mono(13,
                                weight: FontWeight.w600, color: T.amber),
                          ),
                          TextSpan(
                            text: 'AI',
                            style: mono(13,
                                weight: FontWeight.w600, color: T.t1),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 6),
                      Text('1.0.0',
                          style: mono(10,
                              color: T.t3, letterSpacing: 0.4)),
                    ],
                  ),
                ),
                // tagline
                AnimatedOpacity(
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
                      style: sans(25, weight: FontWeight.w600, color: T.t1),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const _DevicePill(),
        ],
      ),
    );
  }
}

class _DevicePill extends StatelessWidget {
  const _DevicePill();

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
                BoxShadow(
                    color: T.ok.withValues(alpha: .7), blurRadius: 10),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('MacBook Air',
              style: mono(13, weight: FontWeight.w500, color: T.t1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text('·', style: mono(13, color: T.t3)),
          ),
          Text('awake', style: mono(13, color: T.t2)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text('·', style: mono(13, color: T.t3)),
          ),
          Text('2m ago', style: mono(13, color: T.t2)),
        ],
      ),
    );
  }
}

class _ColHead extends StatelessWidget {
  const _ColHead();

  @override
  Widget build(BuildContext context) {
    TextStyle s(String _) =>
        mono(12.5, weight: FontWeight.w500, color: T.t2, letterSpacing: 1.3);
    Widget label(String t, {TextAlign align = TextAlign.left}) => Text(
          t.toUpperCase(),
          textAlign: align,
          style: s(t),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 4, 28, 6),
      child: Row(
        children: [
          SizedBox(width: 252, child: label('Account')),
          const SizedBox(width: 16),
          Expanded(child: label('Session · 5h')),
          const SizedBox(width: 16),
          Expanded(child: label('Weekly')),
          const SizedBox(width: 16),
          SizedBox(
              width: 62,
              child: label('Last', align: TextAlign.right)),
          const SizedBox(width: 16),
          SizedBox(
              width: 190,
              child: label('Status', align: TextAlign.right)),
        ],
      ),
    );
  }
}
