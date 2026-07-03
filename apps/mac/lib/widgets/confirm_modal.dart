import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Destructive confirm for removing an account — same surface language as the
/// Add account modal (solid, crisp), with a solid-red primary so the
/// irreversible action reads at a glance.
class ConfirmModal extends StatefulWidget {
  final String name;
  final VoidCallback onCancel;
  final VoidCallback onRemove;

  const ConfirmModal({
    super.key,
    required this.name,
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
    return Container(
      width: 400,
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
                    colors: [T.white(.055), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 26, 26, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0x1FFF7A85),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: const Color(0x3DFF7A85)),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      size: 21, color: T.crit),
                ),
                const SizedBox(height: 18),
                Text('Remove account?',
                    style: sans(19, weight: FontWeight.w700, color: T.t1)),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: widget.name,
                        style: sans(13, weight: FontWeight.w600, color: T.t1)),
                    TextSpan(
                        text: ' will be disconnected from WakieAI.',
                        style: sans(13, color: T.t2, height: 1.5)),
                  ]),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _DialogButton(
                        label: 'Cancel',
                        fg: T.t2,
                        bg: T.white(.04),
                        hoverBg: T.white(.08),
                        border: T.hair2,
                        onTap: widget.onCancel,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DialogButton(
                        label: 'Remove',
                        fg: const Color(0xFF2A0A0D),
                        bg: T.crit,
                        hoverBg: const Color(0xFFFF98A1),
                        border: Colors.transparent,
                        glow: T.crit,
                        bold: true,
                        onTap: widget.onRemove,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogButton extends StatefulWidget {
  final String label;
  final Color fg;
  final Color bg;
  final Color hoverBg;
  final Color border;
  final Color? glow;
  final bool bold;
  final VoidCallback onTap;
  const _DialogButton({
    required this.label,
    required this.fg,
    required this.bg,
    required this.hoverBg,
    required this.border,
    this.glow,
    this.bold = false,
    required this.onTap,
  });

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton> {
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
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hover ? widget.hoverBg : widget.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.border),
            boxShadow: widget.glow != null
                ? [
                    BoxShadow(
                      color: widget.glow!.withValues(alpha: _hover ? .32 : .2),
                      blurRadius: _hover ? 16 : 10,
                      offset: Offset(0, _hover ? 4 : 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            style: sans(14.5,
                weight: widget.bold ? FontWeight.w700 : FontWeight.w600,
                color: widget.fg),
          ),
        ),
      ),
    );
  }
}
