import 'package:flutter/material.dart';

import '../theme.dart';

class SummaryBar extends StatelessWidget {
  final int accountCount;
  final VoidCallback onAddAccount;

  const SummaryBar({
    super.key,
    required this.accountCount,
    required this.onAddAccount,
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
                      style: mono(20, weight: FontWeight.w600, color: T.t1)),
                  Text('+',
                      style: mono(24, weight: FontWeight.w400, color: T.t1)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: _Pill(
              label: 'Running low',
              value: Text('1',
                  style: mono(20, weight: FontWeight.w600, color: T.warn)),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: _Pill(
              label: 'Next reset',
              value: Text('4:30 AM',
                  style: mono(20, weight: FontWeight.w600, color: T.t1)),
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(child: _AutoRefreshPill()),
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

class _AutoRefreshPill extends StatefulWidget {
  const _AutoRefreshPill();

  @override
  State<_AutoRefreshPill> createState() => _AutoRefreshPillState();
}

class _AutoRefreshPillState extends State<_AutoRefreshPill> {
  static const _opts = ['Off', '3h', '4h', '5h', '6h'];
  final LayerLink _link = LayerLink();
  final GlobalKey _pillKey = GlobalKey();
  OverlayEntry? _menu;
  bool _hover = false;
  String _value = '4h';

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
                value: _value,
                options: _opts,
                onSelect: (v) {
                  setState(() => _value = v);
                  _close();
                },
              ),
            ),
          ),
        ]),
      );
    });
    Overlay.of(context).insert(_menu!);
    setState(() {});
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
                Text('AUTO-REFRESH',
                    style: mono(12.5, weight: FontWeight.w500, color: T.t2, letterSpacing: 1.3)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_value,
                        style:
                            mono(20, weight: FontWeight.w600, color: T.amber)),
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 160),
                      turns: _open ? 0.5 : 0,
                      child: Icon(Icons.keyboard_arrow_down,
                          size: 16, color: _open ? T.amber : T.t3),
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
  final String value;
  final List<String> options;
  final ValueChanged<String> onSelect;

  const _Menu({
    required this.value,
    required this.options,
    required this.onSelect,
  });

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
                padding: const EdgeInsets.fromLTRB(9, 6, 9, 7),
                child: Text('REFRESH EVERY',
                    style: mono(10.5, color: T.t3, letterSpacing: 1.4)),
              ),
              for (final o in widget.options)
                _Opt(o, o == widget.value, () => widget.onSelect(o)),
              Container(
                margin: const EdgeInsets.fromLTRB(3, 5, 3, 0),
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 3),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: T.hair)),
                ),
                child: Text(
                  'Your Mac wakes on this cadence to refresh status.',
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

class _Opt extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Opt(this.label, this.selected, this.onTap);

  @override
  State<_Opt> createState() => _OptState();
}

class _OptState extends State<_Opt> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: sel
                ? const Color(0x1AF6B23C)
                : (_hover ? T.white(.06) : Colors.transparent),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.label,
                  style: mono(14,
                      weight: FontWeight.w500,
                      color: sel ? T.amber : (_hover ? T.t1 : T.t2))),
              if (sel)
                Text('✓', style: mono(15, color: T.amber)),
            ],
          ),
        ),
      ),
    );
  }
}
