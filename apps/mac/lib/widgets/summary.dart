import 'package:flutter/material.dart';

import '../theme.dart';

class SummaryBar extends StatelessWidget {
  final int accountCount;
  final int runningLow;

  /// The Resets-in card's value — a countdown ("5h 12m") to the hovered row's
  /// session reset, or the soonest one. Animated on change by the card.
  final String nextReset;
  final VoidCallback onAddAccount;
  final int morningAnchorHour;
  final int morningAnchorMinute;
  final void Function(int hour, int minute)? onSetMorningAnchor;

  const SummaryBar({
    super.key,
    required this.accountCount,
    required this.runningLow,
    required this.nextReset,
    required this.onAddAccount,
    this.morningAnchorHour = 8,
    this.morningAnchorMinute = 0,
    this.onSetMorningAnchor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 0, 26, 14),
      child: Row(
        children: [
          Expanded(
            child: _Pill(
              label: 'Accounts',
              onTap: onAddAccount,
              value: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$accountCount',
                      style: mono(22, weight: FontWeight.w600, color: T.t1)),
                  const Icon(Icons.add_rounded, size: 20, color: T.t1),
                ],
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: _Pill(
              label: 'Running low',
              value: Text('$runningLow',
                  style: mono(22,
                      weight: FontWeight.w600,
                      color: runningLow > 0 ? T.warn : T.t1)),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: _Pill(
              label: 'Resets in',
              // Counts down to the hovered row (or the soonest reset). Matches
              // the app's motion — a short easeOutCubic cross-fade with the
              // faint downward drift of the tagline, not a hard slide.
              value: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeIn,
                layoutBuilder: (current, previous) =>
                    Stack(alignment: Alignment.centerLeft, children: [
                  ...previous,
                  ?current,
                ]),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position:
                        Tween(begin: const Offset(0, -0.18), end: Offset.zero)
                            .animate(anim),
                    child: child,
                  ),
                ),
                child: Text(nextReset,
                    key: ValueKey(nextReset),
                    style: mono(22, weight: FontWeight.w600, color: T.t1)),
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: _MorningAnchorPill(
              hour: morningAnchorHour,
              minute: morningAnchorMinute,
              onChanged: onSetMorningAnchor,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatefulWidget {
  final String label;
  final Widget value;
  final VoidCallback? onTap;
  const _Pill({required this.label, required this.value, this.onTap});

  @override
  State<_Pill> createState() => _PillState();
}

class _PillState extends State<_Pill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    final pill = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: const Cubic(.2, .8, .2, 1),
      transform:
          Matrix4.translationValues(0, interactive && _hover ? -2 : 0, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: interactive && _hover ? T.white(.075) : T.white(.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: interactive && _hover ? T.hair2 : T.hair),
        boxShadow: interactive && _hover
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .5),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.label.toUpperCase(),
              style: mono(12.5, weight: FontWeight.w500, color: T.t2, letterSpacing: 1.3)),
          const SizedBox(height: 6),
          widget.value,
        ],
      ),
    );
    if (!interactive) return pill;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(onTap: widget.onTap, child: pill),
    );
  }
}

/// Parses a wake time as the user types it: "7", "7:30", "7:30am", "12:10 AM",
/// "23:45". Bare hours are 24h ("14" → 2pm); am/pm uses clock convention
/// (12am → 0h, 12pm → 12h). Returns (hour, minute) or null if unparseable.
(int, int)? parseAnchorTime(String input) {
  final m = RegExp(r'^\s*(\d{1,2})(?::(\d{1,2}))?\s*(am|pm)?\s*$',
          caseSensitive: false)
      .firstMatch(input);
  if (m == null) return null;
  var hour = int.parse(m.group(1)!);
  final minute = int.parse(m.group(2) ?? '0');
  final ampm = m.group(3)?.toLowerCase();
  if (minute > 59) return null;
  if (ampm != null) {
    if (hour < 1 || hour > 12) return null;
    hour = hour % 12 + (ampm == 'pm' ? 12 : 0);
  } else if (hour > 23) {
    return null;
  }
  return (hour, minute);
}

String _fmtAnchor(int hour, int minute) {
  final ampm = hour < 12 ? 'am' : 'pm';
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  return '$h12:${minute.toString().padLeft(2, '0')}$ampm';
}

class _MorningAnchorPill extends StatefulWidget {
  final int hour;
  final int minute;
  final void Function(int hour, int minute)? onChanged;

  const _MorningAnchorPill({required this.hour, required this.minute, this.onChanged});

  @override
  State<_MorningAnchorPill> createState() => _MorningAnchorPillState();
}

class _MorningAnchorPillState extends State<_MorningAnchorPill> {
  final LayerLink _link = LayerLink();
  final GlobalKey _pillKey = GlobalKey();
  OverlayEntry? _menu;
  bool _hover = false;
  late int _hour = widget.hour;
  late int _minute = widget.minute;

  bool get _open => _menu != null;

  void _toggle() => _open ? _close() : _openMenu();

  void _openMenu() {
    // Match the menu width to the pill's own (design-space) width so the
    // follower — which inherits the FittedBox scale — lines up exactly.
    final menuWidth = _pillKey.currentContext?.size?.width ?? 220;
    _menu = OverlayEntry(builder: (context) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _close,
        child: Stack(children: [
          Positioned(
            width: menuWidth,
            child: CompositedTransformFollower(
              link: _link,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 9),
              child: _Menu(
                hour: _hour,
                minute: _minute,
                onSet: _pick,
              ),
            ),
          ),
        ]),
      );
    });
    Overlay.of(context).insert(_menu!);
    setState(() {});
  }

  void _pick(int hour, int minute) {
    setState(() {
      _hour = hour;
      _minute = minute;
    });
    widget.onChanged?.call(hour, minute);
    _close();
  }

  void _close() {
    _menu?.remove();
    _menu = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _menu?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: _toggle,
          child: AnimatedContainer(
            key: _pillKey,
            duration: const Duration(milliseconds: 160),
            transform: Matrix4.translationValues(0, _hover && !_open ? -2 : 0, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _open
                  ? const Color(0x0FF6B23C)
                  : (_hover ? T.white(.075) : T.white(.05)),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _open
                      ? const Color(0x73F6B23C)
                      : (_hover ? T.hair2 : T.hair)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('DAILY WAKE',
                    style: mono(12.5, weight: FontWeight.w500, color: T.t2, letterSpacing: 1.3)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmtAnchor(_hour, _minute),
                        style:
                            mono(22, weight: FontWeight.w600, color: T.amber)),
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 160),
                      turns: _open ? 0.5 : 0,
                      child: Icon(Icons.keyboard_arrow_down,
                          size: 20, color: _open ? T.amber : T.t3),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Menu extends StatefulWidget {
  final int hour;
  final int minute;
  final void Function(int hour, int minute) onSet;

  const _Menu({required this.hour, required this.minute, required this.onSet});

  @override
  State<_Menu> createState() => _MenuState();
}

class _MenuState extends State<_Menu> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final v = Curves.easeOutCubic.transform(_c.value);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * -6),
            child: Transform.scale(
              scale: 0.97 + 0.03 * v,
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xF212141C),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: T.hair2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .8),
                blurRadius: 64,
                offset: const Offset(0, 26),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(9, 6, 9, 8),
                child: Text('WAKE AT',
                    style: mono(10.5, color: T.t3, letterSpacing: 1.4)),
              ),
              _WheelPicker(
                hour: widget.hour,
                minute: widget.minute,
                onSet: widget.onSet,
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(3, 10, 3, 0),
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 3),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: T.hair)),
                ),
                child: Text(
                  'Your Mac wakes at this time each day to refresh status and start any due sessions.',
                  style: sans(11.5, color: T.t3, height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scroll-wheel time picker (hour : minute : AM·PM), styled to the menu: the
/// selected row rides an amber band, the rest dim away. Spinning only moves the
/// preview — the setter can raise an admin prompt, so nothing applies until Set.
class _WheelPicker extends StatefulWidget {
  final int hour; // 24h
  final int minute;
  final void Function(int hour, int minute) onSet;
  const _WheelPicker({
    required this.hour,
    required this.minute,
    required this.onSet,
  });

  @override
  State<_WheelPicker> createState() => _WheelPickerState();
}

class _WheelPickerState extends State<_WheelPicker> {
  static const _extent = 36.0;

  late int _hIdx = widget.hour % 12; // index 0 renders as "12"
  late int _minIdx = widget.minute;
  late int _pmIdx = widget.hour >= 12 ? 1 : 0;

  late final _hCtl = FixedExtentScrollController(initialItem: _hIdx);
  late final _minCtl = FixedExtentScrollController(initialItem: _minIdx);
  late final _pmCtl = FixedExtentScrollController(initialItem: _pmIdx);

  @override
  void dispose() {
    _hCtl.dispose();
    _minCtl.dispose();
    _pmCtl.dispose();
    super.dispose();
  }

  int get _hour24 => _hIdx + (_pmIdx == 1 ? 12 : 0);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: SizedBox(
            height: _extent * 5,
            child: Stack(
              children: [
                // The center row sits in this amber band.
                Positioned(
                  top: _extent * 2,
                  left: 0,
                  right: 0,
                  height: _extent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0x14F6B23C),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: const Color(0x33F6B23C)),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Row(
                    children: [
                      Expanded(
                        child: _wheel(
                          controller: _hCtl,
                          count: 12,
                          selected: _hIdx,
                          align: Alignment.centerRight,
                          pad: const EdgeInsets.only(right: 7),
                          label: (i) => i == 0 ? '12' : '$i',
                          onChanged: (i) => setState(() => _hIdx = i),
                        ),
                      ),
                      SizedBox(
                        width: 14,
                        child: Text(':',
                            textAlign: TextAlign.center,
                            style: mono(22,
                                weight: FontWeight.w600, color: T.t3)),
                      ),
                      Expanded(
                        child: _wheel(
                          controller: _minCtl,
                          count: 60,
                          selected: _minIdx,
                          align: Alignment.centerLeft,
                          pad: const EdgeInsets.only(left: 7),
                          label: (i) => i.toString().padLeft(2, '0'),
                          onChanged: (i) => setState(() => _minIdx = i),
                        ),
                      ),
                      Expanded(
                        child: _wheel(
                          controller: _pmCtl,
                          count: 2,
                          selected: _pmIdx,
                          align: Alignment.center,
                          pad: EdgeInsets.zero,
                          label: (i) => i == 0 ? 'AM' : 'PM',
                          onChanged: (i) => setState(() => _pmIdx = i),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _SetButton(
          label: 'Set ${_fmtAnchor(_hour24, _minIdx)}',
          onTap: () => widget.onSet(_hour24, _minIdx),
        ),
      ],
    );
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required int selected,
    required Alignment align,
    required EdgeInsets pad,
    required String Function(int) label,
    required ValueChanged<int> onChanged,
  }) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: _extent,
      physics: const FixedExtentScrollPhysics(),
      // Near-flat cylinder: the app is flat, so kill the 3D tilt that made
      // each column's items look angled against the others. Rows stay level.
      perspective: 0.001,
      diameterRatio: 100,
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: count,
        builder: (context, i) => Container(
          alignment: align,
          padding: pad,
          child: Text(
            label(i),
            style: mono(22,
                weight: FontWeight.w600,
                color: i == selected ? T.amber : T.white(.30)),
          ),
        ),
      ),
    );
  }
}

/// Amber commit button — matches the account row's Update pill so the menu's
/// one action reads the same as the rest of the app.
class _SetButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _SetButton({required this.label, required this.onTap});

  @override
  State<_SetButton> createState() => _SetButtonState();
}

class _SetButtonState extends State<_SetButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hover ? const Color(0xFFFFD07E) : T.amber,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x99FFC465)),
          ),
          child: Text(
            widget.label,
            style: mono(16,
                weight: FontWeight.w600, color: const Color(0xFF1A1205)),
          ),
        ),
      ),
    );
  }
}
