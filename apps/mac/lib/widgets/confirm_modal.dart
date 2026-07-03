import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models.dart';
import '../theme.dart';

/// Remove-account confirm. Rather than a generic "trash icon + question", it
/// shows the actual account about to be cut loose — its provider badge, name,
/// and email, framed as a system-voice DISCONNECT — so it reads as this app,
/// not a stock dialog. The destructive button stays outlined until hovered,
/// then arms solid red.
class ConfirmModal extends StatefulWidget {
  final Account account;
  final VoidCallback onCancel;
  final VoidCallback onRemove;

  const ConfirmModal({
    super.key,
    required this.account,
    required this.onCancel,
    required this.onRemove,
  });

  @override
  State<ConfirmModal> createState() => _ConfirmModalState();
}

class _ConfirmModalState extends State<ConfirmModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String get _providerName => switch (widget.account.provider) {
        Provider.claude => 'Claude',
        Provider.codex => 'Codex',
        Provider.anti => 'Antigravity',
      };

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final v = Curves.easeOutCubic.transform(_c.value);
        return Positioned.fill(
          child: GestureDetector(
            onTap: widget.onCancel,
            child: Opacity(
              opacity: v,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4 * v, sigmaY: 4 * v),
                child: Container(
                  color: Colors.black.withValues(alpha: .58 * v),
                  alignment: Alignment.center,
                  child: Transform.translate(
                    offset: Offset(0, (1 - v) * 14),
                    child: Transform.scale(
                      scale: 0.98 + 0.02 * v,
                      child: GestureDetector(onTap: () {}, child: child),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      child: _box(),
    );
  }

  Widget _box() {
    final a = widget.account;
    final sep = a.plan.lastIndexOf(' · ');
    final email = sep == -1 ? a.plan : a.plan.substring(0, sep);
    final tier = sep == -1 ? '' : a.plan.substring(sep + 3);

    return Container(
      width: 420,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xF5161820),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: T.hair2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .7),
            blurRadius: 100,
            offset: const Offset(0, 40),
          ),
        ],
      ),
      child: Stack(
        children: [
          // A faint red glow bleeds in from the corner — danger, quietly.
          Positioned(
            top: -50,
            left: -30,
            child: IgnorePointer(
              child: Container(
                width: 240,
                height: 190,
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Color(0x24FF7A85), Color(0x00FF7A85)],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.link_off_rounded, size: 15, color: T.crit),
                    const SizedBox(width: 9),
                    Text('DISCONNECT',
                        style: mono(11,
                            weight: FontWeight.w600,
                            color: T.crit,
                            letterSpacing: 2)),
                  ],
                ),
                const SizedBox(height: 15),
                _accountCard(a, email, tier),
                const SizedBox(height: 16),
                Text(
                  'WakieAI stops tracking this account and forgets its usage. '
                  'Your $_providerName login on this Mac is untouched.',
                  style: mono(12.5, color: T.t2, height: 1.55),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _GhostButton(label: 'Keep', onTap: widget.onCancel),
                    const SizedBox(width: 6),
                    _DangerButton(label: 'Disconnect', onTap: widget.onRemove),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountCard(Account a, String email, String tier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: T.white(.03),
        borderRadius: BorderRadius.circular(12),
        // Tinted red so it reads as the row marked for removal.
        border: Border.all(color: const Color(0x33FF7A85)),
      ),
      child: Row(
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: a.provider.badgeBg,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: T.hair2),
            ),
            child: Center(
              child: SvgPicture.asset(a.provider.icon, width: 20, height: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(a.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              sans(15.5, weight: FontWeight.w600, color: T.t1)),
                    ),
                    if (tier.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(tier.toUpperCase(),
                            style: mono(10,
                                weight: FontWeight.w600,
                                color: T.amber,
                                letterSpacing: 0.5)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mono(11.5, color: T.t3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Keep" — a quiet ghost, so the eye lands on Disconnect.
class _GhostButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _GhostButton({required this.label, required this.onTap});

  @override
  State<_GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<_GhostButton> {
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: _hover ? T.white(.05) : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(widget.label,
              style: sans(14,
                  weight: FontWeight.w600, color: _hover ? T.t1 : T.t2)),
        ),
      ),
    );
  }
}

/// "Disconnect" — outlined at rest, arms solid red on hover, so committing to
/// the destructive action is a deliberate beat.
class _DangerButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _DangerButton({required this.label, required this.onTap});

  @override
  State<_DangerButton> createState() => _DangerButtonState();
}

class _DangerButtonState extends State<_DangerButton> {
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
          transform: Matrix4.translationValues(0, _hover ? -1 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            color: _hover ? T.crit : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
                color: _hover ? T.crit : const Color(0x66FF7A85), width: 1.5),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: T.crit.withValues(alpha: .28),
                      blurRadius: 14,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(widget.label,
              style: sans(14,
                  weight: FontWeight.w700,
                  color: _hover ? const Color(0xFF2A0A0D) : T.crit)),
        ),
      ),
    );
  }
}
