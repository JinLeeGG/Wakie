import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'models.dart';
import 'theme.dart';
import 'widgets/account_row.dart';
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

  const DashboardScreen({super.key, this.source});

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

  // Footer run sequence.
  final FooterController _footer = FooterController();

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
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tagTimer?.cancel();
    _winIn.dispose();
    _footer.dispose();
    super.dispose();
  }

  void _reload() {
    final source = widget.source;
    if (source == null || _loading) return;
    _sub?.cancel();
    setState(() => _loading = true);
    _sub = source().listen(
      (accounts) {
        if (!mounted) return;
        setState(() => _accounts
          ..clear()
          ..addAll(accounts));
      },
      onDone: () {
        if (mounted) setState(() => _loading = false);
      },
    );
  }

  void _askRemove(Account a) => setState(() => _pendingRemove = a);

  void _confirmRemove() {
    setState(() {
      if (_pendingRemove != null) _accounts.remove(_pendingRemove);
      _pendingRemove = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // The dashboard is designed on a fixed 900x640 canvas and scaled
          // up to fill the (larger) window, so type + spacing grow uniformly.
          // Positioned.fill forces tight constraints so FittedBox scales UP.
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: 900,
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
                onAddAccount: () {},
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
                          onUpdate: () => _footer.runUpdate(_accounts[i].name),
                        ),
                      ),
              ),
              DashboardFooter(
                controller: _footer,
                onRefreshAll: () {
                  _footer.runRefreshAll();
                  _reload();
                },
                onAddAccount: () {},
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
                                weight: FontWeight.w600, color: T.amber),
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
          SizedBox(width: 224, child: label('Account')),
          const SizedBox(width: 16),
          Expanded(child: label('Session · 5h')),
          const SizedBox(width: 16),
          Expanded(child: label('Weekly')),
          const SizedBox(width: 16),
          SizedBox(
              width: 62,
              child: label('Last', align: TextAlign.right)),
          const SizedBox(width: 16),
          const SizedBox(width: 190),
        ],
      ),
    );
  }
}
