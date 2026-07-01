import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';

class _Stage {
  final String text;
  final double pct;
  final int dur;
  const _Stage(this.text, this.pct, this.dur);
}

/// Drives the footer running sequence (wake → session → refresh → done).
class FooterController extends ChangeNotifier {
  bool running = false;
  bool done = false;
  double fill = 0;
  String label = '';

  Timer? _timer;

  void runRefreshAll() => _run([
        const _Stage('Waking MacBook Air…', 22, 1100),
        const _Stage('Starting sessions…', 54, 1300),
        const _Stage('Refreshing status…', 92, 1500),
      ], 'All accounts up to date');

  void runUpdate(String name) => _run([
        const _Stage('Waking MacBook Air…', 28, 1000),
        _Stage('Starting $name…', 62, 1200),
        const _Stage('Refreshing status…', 92, 1300),
      ], '$name refreshed');

  void _run(List<_Stage> stages, String doneLabel) {
    if (running) return;
    running = true;
    done = false;
    fill = 0;
    notifyListeners();

    var i = 0;
    void next() {
      if (i < stages.length) {
        label = stages[i].text;
        fill = stages[i].pct;
        final dur = stages[i].dur;
        i++;
        notifyListeners();
        _timer = Timer(Duration(milliseconds: dur), next);
      } else {
        label = doneLabel;
        done = true;
        fill = 100;
        notifyListeners();
        _timer = Timer(const Duration(milliseconds: 1700), () {
          running = false;
          done = false;
          notifyListeners();
        });
      }
    }

    next();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class DashboardFooter extends StatefulWidget {
  final FooterController controller;
  final VoidCallback onRefreshAll;
  final VoidCallback onAddAccount;

  const DashboardFooter({
    super.key,
    required this.controller,
    required this.onRefreshAll,
    required this.onAddAccount,
  });

  @override
  State<DashboardFooter> createState() => _DashboardFooterState();
}

class _DashboardFooterState extends State<DashboardFooter> {
  bool _launchAtLogin = true;

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
                              colors: c.done
                                  ? [T.ok, const Color(0xFF8FE6BD)]
                                  : [T.amber, const Color(0xFFFFDF9E)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (c.done ? T.ok : T.amber)
                                    .withValues(alpha: .7),
                                blurRadius: 12,
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
                    _launchToggle(),
                    const SizedBox(width: 22),
                    Text.rich(TextSpan(children: [
                      TextSpan(
                          text: 'next wake ',
                          style: mono(13.5, color: T.t2)),
                      TextSpan(
                          text: '6:55 AM',
                          style: mono(13.5,
                              weight: FontWeight.w600, color: T.amber)),
                    ])),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
        if (c.done)
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
        Text(c.label,
            style: mono(12.5, color: c.done ? T.ok : T.t2)),
      ],
    );
  }

  Widget _launchToggle() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _launchAtLogin = !_launchAtLogin),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32,
              height: 18,
              decoration: BoxDecoration(
                color: _launchAtLogin ? T.amber : T.white(.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: _launchAtLogin
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
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
            Text('Launch at login', style: mono(11.5, color: T.t3)),
          ],
        ),
      ),
    );
  }
}
