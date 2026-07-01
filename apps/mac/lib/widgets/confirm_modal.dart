import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';

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
                filter: ImageFilter.blur(sigmaX: 8 * v, sigmaY: 8 * v),
                child: Container(
                  color: Colors.black.withValues(alpha: .5 * v),
                  alignment: Alignment.center,
                  child: Transform.scale(
                    scale: 0.93 + 0.07 * v,
                    child: GestureDetector(
                      onTap: () {},
                      child: child,
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
      width: 360,
      padding: const EdgeInsets.fromLTRB(26, 28, 26, 24),
      decoration: BoxDecoration(
        color: T.glass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: T.hair2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .8),
            blurRadius: 80,
            offset: const Offset(0, 40),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0x1AFF7A85),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x38FF7A85)),
            ),
            child: const Icon(Icons.delete_outline, size: 18, color: T.crit),
          ),
          const SizedBox(height: 18),
          Text('Remove account?',
              style: sans(18, weight: FontWeight.w700, color: T.t1)),
          const SizedBox(height: 7),
          Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: widget.name,
                  style: mono(12, weight: FontWeight.w500, color: T.t1)),
              TextSpan(
                  text: ' will be disconnected from WakieAI.',
                  style: mono(12, color: T.t2, height: 1.6)),
            ]),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _btn(
                  'Cancel',
                  bg: Colors.transparent,
                  fg: T.t2,
                  border: T.hair2,
                  bold: false,
                  onTap: widget.onCancel,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _btn(
                  'Remove',
                  bg: const Color(0x1FFF7A85),
                  fg: T.crit,
                  border: const Color(0x4DFF7A85),
                  bold: true,
                  onTap: widget.onRemove,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _btn(String label,
      {required Color bg,
      required Color fg,
      required Color border,
      required bool bold,
      required VoidCallback onTap}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Text(label,
              style: sans(13,
                  weight: bold ? FontWeight.w700 : FontWeight.w500, color: fg)),
        ),
      ),
    );
  }
}
