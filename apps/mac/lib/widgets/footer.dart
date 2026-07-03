import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';

const _logoSvg =
    '<svg viewBox="0 0 100 100"><circle cx="50" cy="50" r="38" fill="none" stroke="#fff" stroke-width="6"/>'
    '<circle cx="50" cy="50" r="22" fill="#f6b23c"/></svg>';

/// Drives the footer progress bar off *real* work, not a canned timeline.
///
/// [start] shows the bar and lets it trickle so there's visible life during
/// I/O we can't measure; [progress] snaps it forward to a measured fraction
/// (e.g. accounts loaded / total); [finish] only fires when the real work
/// actually completes — so the bar reaches 100% at true loading speed.
class FooterController extends ChangeNotifier {
  bool running = false;
  bool done = false;
  bool failed = false;
  double fill = 0;
  String label = '';

  // Ceiling the trickle eases toward while waiting on unmeasured I/O; real
  // [progress] and [finish] are what carry the bar the rest of the way.
  static const _trickleCap = 80.0;

  Timer? _trickle;
  Timer? _hide;

  void start(String label) {
    _trickle?.cancel();
    _hide?.cancel();
    running = true;
    done = false;
    failed = false;
    fill = 6;
    this.label = label;
    notifyListeners();
    _trickle = Timer.periodic(const Duration(milliseconds: 380), (_) {
      if (fill < _trickleCap) {
        fill += (_trickleCap - fill) * 0.12;
        notifyListeners();
      }
    });
  }

  /// Report measured progress in [0,1]. Forward-only so the bar never recedes.
  void progress(double frac, {String? label}) {
    final pct = (frac.clamp(0.0, 1.0)) * 100;
    if (pct <= fill && label == null) return;
    if (pct > fill) fill = pct;
    if (label != null) this.label = label;
    notifyListeners();
  }

  void finish(String doneLabel) {
    _trickle?.cancel();
    _hide?.cancel();
    running = true; // self-starting: a result must render even without start()
    label = doneLabel;
    done = true;
    failed = false;
    fill = 100;
    notifyListeners();
    _hide = Timer(const Duration(milliseconds: 1500), () {
      running = false;
      done = false;
      notifyListeners();
    });
  }

  /// Like [finish], but shown as a failure (red, longer-lived) instead of
  /// silently succeeding or vanishing — an action that failed with no
  /// visible reaction is worse than one that failed loudly.
  void fail(String message) {
    _trickle?.cancel();
    _hide?.cancel();
    running = true; // self-starting: a failure must render even without start()
    label = message;
    done = false;
    failed = true;
    fill = 100;
    notifyListeners();
    _hide = Timer(const Duration(milliseconds: 3500), () {
      running = false;
      failed = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _trickle?.cancel();
    _hide?.cancel();
    super.dispose();
  }
}

class DashboardFooter extends StatefulWidget {
  final FooterController controller;
  final VoidCallback onRefreshAll;
  final VoidCallback onAddAccount;

  final bool launchAtLogin;
  final ValueChanged<bool>? onLaunchAtLogin;

  /// "Wake from sleep" — whether the daily hardware wake is programmed, and
  /// the toggle handler (admin prompt). onChanged returns an error message to
  /// surface, or null on success. Null handler in tests/goldens.
  final bool darkWake;
  final Future<String?> Function(bool)? onDarkWake;

  const DashboardFooter({
    super.key,
    required this.controller,
    required this.onRefreshAll,
    required this.onAddAccount,
    this.launchAtLogin = false,
    this.onLaunchAtLogin,
    this.darkWake = false,
    this.onDarkWake,
  });

  @override
  State<DashboardFooter> createState() => _DashboardFooterState();
}

class _DashboardFooterState extends State<DashboardFooter> {

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        return Container(
          decoration: const BoxDecoration(
            color: Color(0x05FFFFFF),
            border: Border(top: BorderSide(color: T.hair)),
          ),
          child: Stack(
            children: [
              // run progress bar spanning the top edge
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: c.running ? 1 : 0,
                  child: Container(
                    height: 2,
                    color: T.white(.05),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: LayoutBuilder(builder: (context, box) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: const Cubic(.4, 0, .2, 1),
                          width: box.maxWidth * (c.fill / 100),
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: c.failed
                                  ? [T.crit, const Color(0xFFFFA8AE)]
                                  : c.done
                                      ? [T.ok, const Color(0xFF8FE6BD)]
                                      : [T.amber, const Color(0xFFFFDF9E)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (c.failed
                                        ? T.crit
                                        : (c.done ? T.ok : T.amber))
                                    .withValues(alpha: .28),
                                blurRadius: 5,
                              )
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
                child: Row(
                  children: [
                    Expanded(
                        child: c.running ? _runStatus(c) : _keys()),
                    _darkWakeToggle(),
                    const SizedBox(width: 18),
                    _launchToggle(),
                    const SizedBox(width: 22),
                    _brand(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // App identity, demoted from the header to sign off the panel quietly.
  Widget _brand() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 15,
          height: 15,
          child: SvgPicture.string(_logoSvg),
        ),
        const SizedBox(width: 7),
        Text.rich(TextSpan(children: [
          TextSpan(
              text: 'Wakie',
              style: mono(12.5, weight: FontWeight.w600, color: T.amber)),
          TextSpan(
              text: 'AI',
              style: mono(12.5, weight: FontWeight.w600, color: T.t1)),
          TextSpan(
              text: '  1.0.0',
              style: mono(10, color: T.t3, letterSpacing: 0.4)),
        ])),
      ],
    );
  }

  Widget _keys() {
    return Row(
      children: [
        _key('↵', 'Update'),
        const SizedBox(width: 18),
        _key('⌘R', 'Refresh all', onTap: widget.onRefreshAll),
        const SizedBox(width: 18),
        _key('⌘N', 'Add account', onTap: widget.onAddAccount),
      ],
    );
  }

  Widget _key(String kbd, String label, {VoidCallback? onTap}) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: T.white(.05),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: T.hair),
          ),
          child: Text(kbd, style: mono(11.5, color: T.t2)),
        ),
        Text(label, style: mono(12, color: T.t3)),
      ],
    );
    if (onTap == null) return content;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: content),
    );
  }

  Widget _runStatus(FooterController c) {
    return Row(
      children: [
        if (c.failed)
          const Icon(Icons.error_outline, size: 14, color: T.crit)
        else if (c.done)
          const Icon(Icons.check, size: 14, color: T.ok)
        else
          const SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(T.amber),
              backgroundColor: Color(0x38FFC465),
            ),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(c.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mono(12.5, color: c.failed ? T.crit : (c.done ? T.ok : T.t2))),
        ),
      ],
    );
  }

  Widget _launchToggle() => _toggle(
        value: widget.launchAtLogin,
        label: 'Launch at login',
        onTap: () => widget.onLaunchAtLogin?.call(!widget.launchAtLogin),
      );

  Widget _darkWakeToggle() => _toggle(
        value: widget.darkWake,
        label: 'Wake from sleep',
        onTap: () => widget.onDarkWake?.call(!widget.darkWake),
      );

  Widget _toggle({
    required bool value,
    required String label,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32,
              height: 18,
              decoration: BoxDecoration(
                color: value ? T.amber : T.white(.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment:
                    value ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .35),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(label, style: mono(11.5, color: T.t3)),
          ],
        ),
      ),
    );
  }
}
