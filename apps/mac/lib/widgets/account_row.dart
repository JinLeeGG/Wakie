import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'tiny_toggle_switch.dart';

class AccountRow extends StatefulWidget {
  final Account account;
  final int animDelayMs;
  final VoidCallback onRemove;
  final VoidCallback onUpdate;
  final ValueChanged<bool>? onAutoStartChanged;

  /// Hover enter (true) / exit (false) — lets the summary bar count down to
  /// this row's session reset while the cursor is over it.
  final ValueChanged<bool>? onHover;

  const AccountRow({
    super.key,
    required this.account,
    required this.animDelayMs,
    required this.onRemove,
    required this.onUpdate,
    this.onAutoStartChanged,
    this.onHover,
  });

  @override
  State<AccountRow> createState() => _AccountRowState();
}

class _AccountRowState extends State<AccountRow>
    with SingleTickerProviderStateMixin {
  bool _hover = false;
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.animDelayMs), () {
      if (mounted) _in.forward();
    });
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.account;
    return AnimatedBuilder(
      animation: _in,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_in.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 7),
            child: child,
          ),
        );
      },
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _hover = true);
          widget.onHover?.call(true);
        },
        onExit: (_) {
          setState(() => _hover = false);
          widget.onHover?.call(false);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _hover ? T.white(.055) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _hover ? T.hair : Colors.transparent),
          ),
          child: Row(
            children: [
              SizedBox(width: 272, child: _acct(a)),
              const SizedBox(width: 16),
              Expanded(child: _MeterView(a.session)),
              const SizedBox(width: 16),
              Expanded(child: _MeterView(a.weekly)),
              const SizedBox(width: 16),
              SizedBox(width: 190, child: _end(a)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _acct(Account a) {
    return Row(
      children: [
        Container(
          width: 35,
          height: 35,
          decoration: BoxDecoration(
            color: a.provider.badgeBg,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: T.hair2),
          ),
          // The real app icon, full-bleed — the badge IS the icon.
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(a.provider.icon,
                fit: BoxFit.cover, filterQuality: FilterQuality.medium),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: _identity(a)),
        if (widget.onAutoStartChanged != null)
          _AutoStartToggle(a: a, onChanged: widget.onAutoStartChanged!),
      ],
    );
  }

  /// Name + plan tier on the top line, email on its own line below — so the
  /// (often long) email gets the full column width instead of fighting the
  /// plan for space. `a.plan` arrives as "email · Plan" (or email-only / "—").
  Widget _identity(Account a) {
    final sep = a.plan.lastIndexOf(' · ');
    final email = sep == -1 ? a.plan : a.plan.substring(0, sep);
    final plan = sep == -1 ? '' : a.plan.substring(sep + 3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                a.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: sans(18, weight: FontWeight.w600, color: T.t1),
              ),
            ),
            if (plan.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  plan.toUpperCase(),
                  style: mono(
                    10.5,
                    weight: FontWeight.w600,
                    color: T.amber,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: mono(11.5, color: T.t3),
        ),
      ],
    );
  }

  Widget _end(Account a) {
    return SizedBox(
      height: 32,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: _hover ? 0 : 1,
            // OK is the quiet default — no pill. A label only appears when
            // something needs the eye (Fresh / Low / Sign in), so anything
            // in this column is worth reading.
            child: a.status == RunStatus.ok
                ? const SizedBox.shrink()
                : _StatusPill(a.status),
          ),
          IgnorePointer(
            ignoring: !_hover,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              opacity: _hover ? 1 : 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PillButton(
                    label: 'Remove',
                    fg: T.crit,
                    bg: const Color(0x14FF7A85),
                    hoverBg: const Color(0x29FF7A85),
                    border: const Color(0x40FF7A85),
                    onTap: widget.onRemove,
                  ),
                  const SizedBox(width: 8),
                  _PillButton(
                    label: 'Update ↵',
                    fg: const Color(0xFF1A1205),
                    bg: T.amber,
                    hoverBg: const Color(0xFFFFD07E),
                    border: const Color(0x99FFC465),
                    onTap: widget.onUpdate,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}

/// A hover-reactive action pill (the row's Remove / Update): the fill deepens
/// and it lifts a hair on hover, so it feels live like the app's other buttons.
class _PillButton extends StatefulWidget {
  final String label;
  final Color fg;
  final Color bg;
  final Color hoverBg;
  final Color border;
  final VoidCallback onTap;
  const _PillButton({
    required this.label,
    required this.fg,
    required this.bg,
    required this.hoverBg,
    required this.border,
    required this.onTap,
  });

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> {
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
          duration: const Duration(milliseconds: 130),
          transform: Matrix4.translationValues(0, _hover ? -1 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: _hover ? widget.hoverBg : widget.bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: widget.border),
          ),
          child: Text(
            widget.label,
            style: mono(12, weight: FontWeight.w600, color: widget.fg),
          ),
        ),
      ),
    );
  }
}

class _MeterView extends StatelessWidget {
  final Meter meter;
  const _MeterView(this.meter);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    if (meter.known) ...[
                      TextSpan(
                        text: '${meter.pct}%',
                        style: mono(
                          17,
                          weight: FontWeight.w600,
                          color: meter.tone.text,
                        ),
                      ),
                      TextSpan(
                        text: ' left',
                        style: mono(11, weight: FontWeight.w500, color: T.t3),
                      ),
                    ] else
                      // No data for this window (e.g. free plans have no 5h
                      // session) — never dress an unknown up as an empty 0%.
                      TextSpan(
                        text: '—',
                        style: mono(17, weight: FontWeight.w600, color: T.t3),
                      ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.clip,
                softWrap: false,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              meter.reset,
              maxLines: 1,
              overflow: TextOverflow.clip,
              softWrap: false,
              style: mono(13.5, color: T.t3),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _Bar(pct: meter.known ? meter.pct : 0, color: meter.tone.text),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  final int pct;
  final Color color;
  const _Bar({required this.pct, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Container(
        height: 5,
        color: T.white(.09),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct / 100),
            duration: const Duration(milliseconds: 1100),
            curve: const Cubic(.3, .9, .3, 1),
            builder: (context, v, _) => FractionallySizedBox(
              widthFactor: v,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: .5),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final RunStatus status;
  const _StatusPill(this.status);

  @override
  Widget build(BuildContext context) {
    final (Color c, String label, bool glow) = switch (status) {
      RunStatus.fresh => (T.ok, 'Fresh', true),
      RunStatus.ok => (T.t3, 'OK', false),
      RunStatus.low => (T.crit, 'Low', true),
      RunStatus.signin => (T.amber, 'Sign in', true),
    };
    final textColor = switch (status) {
      RunStatus.fresh => T.ok,
      RunStatus.ok => T.t2,
      RunStatus.low => T.crit,
      RunStatus.signin => T.amber,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: T.white(.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: T.hair),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              boxShadow: glow
                  ? [BoxShadow(color: c.withValues(alpha: .7), blurRadius: 8)]
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: mono(
              11.5,
              weight: FontWeight.w600,
              color: textColor,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Session-chaining toggle (D1 "token maxxing"): a fresh session starts the
/// moment this account's window resets. Off by default for Codex/Antigravity
/// (R0 🟡/🟠 — automation there is a less defensible ToS position); on by
/// default for Claude (🟢). Always visible, not hover-gated — this is a
/// standing setting the user should see at a glance, unlike Update/Remove.
class _AutoStartToggle extends StatelessWidget {
  final Account a;
  final ValueChanged<bool> onChanged;
  const _AutoStartToggle({required this.a, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final available = a.autoStartAvailable;
    final on = available && a.autoStart;
    return Tooltip(
      message: !available
          ? 'Auto-start is unavailable — this account has no current session reset window'
          : on
          ? 'Auto-start is on — a new session starts the moment this window resets'
          : 'Auto-start is off — this account only refreshes, never starts a session',
      child: Semantics(
        label: 'Auto-start',
        button: true,
        enabled: available,
        toggled: on,
        child: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: TinyToggleSwitch(
            value: on,
            enabled: available,
            onTap: () => onChanged(!on),
          ),
        ),
      ),
    );
  }
}
