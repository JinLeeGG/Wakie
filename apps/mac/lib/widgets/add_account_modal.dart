import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models.dart';
import '../theme.dart';

/// Add-account flow (FR-UI-04): pick a provider + label, then hand off to
/// [onAdd] — the caller opens Terminal to run that provider's interactive
/// login, scoped to a fresh isolated config home, and registers the account.
/// This modal never sees or handles credentials itself (R0).
class AddAccountModal extends StatefulWidget {
  final VoidCallback onCancel;
  final void Function(Provider provider, String label) onAdd;

  const AddAccountModal({super.key, required this.onCancel, required this.onAdd});

  @override
  State<AddAccountModal> createState() => _AddAccountModalState();
}

class _AddAccountModalState extends State<AddAccountModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();
  final TextEditingController _label = TextEditingController();
  Provider _provider = Provider.claude;

  @override
  void dispose() {
    _c.dispose();
    _label.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onAdd(_provider, _label.text);
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
    return Container(
      width: 380,
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
          Text('Add account',
              style: sans(18, weight: FontWeight.w700, color: T.t1)),
          const SizedBox(height: 7),
          Text(
            'Opens Terminal to sign in — a fresh, isolated login for this provider.',
            style: mono(12, color: T.t2, height: 1.6),
          ),
          const SizedBox(height: 20),
          Text('PROVIDER',
              style: mono(11, weight: FontWeight.w500, color: T.t3, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final p in Provider.values) ...[
                if (p != Provider.values.first) const SizedBox(width: 8),
                Expanded(child: _ProviderOption(
                  provider: p,
                  selected: _provider == p,
                  onTap: () => setState(() => _provider = p),
                )),
              ],
            ],
          ),
          const SizedBox(height: 18),
          Text('LABEL',
              style: mono(11, weight: FontWeight.w500, color: T.t3, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          TextField(
            controller: _label,
            autofocus: true,
            style: mono(13.5, color: T.t1),
            cursorColor: T.amber,
            decoration: InputDecoration(
              hintText: 'e.g. work',
              hintStyle: mono(13.5, color: T.t3),
              filled: true,
              fillColor: T.white(.04),
              contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: T.hair2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: T.hair2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: T.amber),
              ),
            ),
            onSubmitted: (_) => _submit(),
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
                  'Add & sign in',
                  bg: const Color(0x33FFC465),
                  fg: T.amber,
                  border: const Color(0x66FFC465),
                  bold: true,
                  onTap: _submit,
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

class _ProviderOption extends StatelessWidget {
  final Provider provider;
  final bool selected;
  final VoidCallback onTap;
  const _ProviderOption(
      {required this.provider, required this.selected, required this.onTap});

  String get _label => switch (provider) {
        Provider.claude => 'Claude',
        Provider.codex => 'Codex',
        Provider.anti => 'Antigravity',
      };

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0x1AFFC465) : T.white(.03),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: selected ? const Color(0x66FFC465) : T.hair2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(provider.icon, width: 18, height: 18),
              const SizedBox(height: 6),
              Text(_label,
                  style: mono(11,
                      weight: FontWeight.w600,
                      color: selected ? T.amber : T.t2)),
            ],
          ),
        ),
      ),
    );
  }
}
