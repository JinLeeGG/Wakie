import 'dart:ui';

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// Remove-account confirm. Quiet and specific: it shows the actual account
/// (badge, name, email) so you see what you're cutting, one line of
/// reassurance, and Cancel / Remove. No drama.
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
    duration: const Duration(milliseconds: 200),
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
                    offset: Offset(0, (1 - v) * 10),
                    child: GestureDetector(onTap: () {}, child: child),
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
      width: 380,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xF5161820),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: T.hair2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .6),
            blurRadius: 80,
            offset: const Offset(0, 32),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Remove account?',
                style: sans(17, weight: FontWeight.w600, color: T.t1)),
            const SizedBox(height: 14),
            _accountCard(a, email, tier),
            const SizedBox(height: 12),
            Text('Your login on this Mac stays — only tracking stops.',
                style: sans(12.5, color: T.t3, height: 1.5)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _Btn(
                  label: 'Cancel',
                  fg: T.t2,
                  bg: Colors.transparent,
                  hoverBg: T.white(.05),
                  onTap: widget.onCancel,
                ),
                const SizedBox(width: 6),
                _Btn(
                  label: 'Remove',
                  fg: T.crit,
                  bg: const Color(0x1FFF7A85),
                  hoverBg: const Color(0x33FF7A85),
                  onTap: widget.onRemove,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountCard(Account a, String email, String tier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: T.white(.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: T.hair),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: a.provider.badgeBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: T.hair2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset(a.provider.icon,
                  fit: BoxFit.cover, filterQuality: FilterQuality.medium),
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
                              sans(15, weight: FontWeight.w600, color: T.t1)),
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

class _Btn extends StatefulWidget {
  final String label;
  final Color fg;
  final Color bg;
  final Color hoverBg;
  final VoidCallback onTap;
  const _Btn({
    required this.label,
    required this.fg,
    required this.bg,
    required this.hoverBg,
    required this.onTap,
  });

  @override
  State<_Btn> createState() => _BtnState();
}

class _BtnState extends State<_Btn> {
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
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: _hover ? widget.hoverBg : widget.bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(widget.label,
              style: sans(13.5, weight: FontWeight.w600, color: widget.fg)),
        ),
      ),
    );
  }
}
