import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models.dart';
import '../theme.dart';

const _logoSvg =
    '<svg viewBox="0 0 100 100"><circle cx="50" cy="50" r="38" fill="none" stroke="#fff" stroke-width="6"/>'
    '<circle cx="50" cy="50" r="22" fill="#f6b23c"/></svg>';

/// Add-account flow (FR-UI-04): pick a provider + label, then hand off to
/// [onAdd] — the caller opens that provider's interactive login, scoped to a
/// fresh isolated config home, and registers the account. This modal never
/// sees or handles credentials itself (R0). Ported 1:1 from
/// docs/design/add-account.html.
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

  void _submit() => widget.onAdd(_provider, _label.text);

  // Claude/Codex finish sign-in silently in the browser; Antigravity is a TUI,
  // so its login opens in Terminal. Say which, honestly, per provider.
  bool get _viaTerminal => _provider == Provider.anti;
  String get _where => _viaTerminal ? 'Terminal' : 'your browser';

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
      width: 452,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        // Near-opaque so the busy dashboard behind can't bleed through and
        // muddy the content — the modal reads as a solid, crisp surface.
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
          // top sheen
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [_header(), _body()],
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 16, 16),
      child: Row(
        children: [
          SizedBox(width: 20, height: 20, child: SvgPicture.string(_logoSvg)),
          const SizedBox(width: 11),
          Text('Add account', style: sans(17, weight: FontWeight.w600, color: T.t1)),
          const Spacer(),
          _CloseButton(onTap: widget.onCancel),
        ],
      ),
    );
  }

  Widget _body() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _label3('Provider', top: 16),
          for (final p in Provider.values) ...[
            if (p != Provider.values.first) const SizedBox(height: 11),
            _ProviderRow(
              provider: p,
              selected: _provider == p,
              onTap: () => setState(() => _provider = p),
            ),
          ],
          _label3('Label', top: 20),
          _labelField(),
          _info(),
          const SizedBox(height: 26),
          _PrimaryButton(
            label: 'Sign in with ${_viaTerminal ? 'Terminal' : 'browser'}',
            onTap: _submit,
          ),
          const SizedBox(height: 10),
          Center(
            child: _CancelButton(onTap: widget.onCancel),
          ),
        ],
      ),
    );
  }

  Widget _label3(String text, {required double top}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(2, top, 2, 11),
      child: Text(text.toUpperCase(),
          style: mono(9.5, weight: FontWeight.w500, color: T.t3, letterSpacing: 1.4)),
    );
  }

  Widget _labelField() {
    final key = _providerKey(_provider);
    final typed = _label.text.trim();
    final tag = typed.isEmpty ? key : '$key · $typed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      decoration: BoxDecoration(
        color: T.white(.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: T.hair),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _label,
              autofocus: true,
              style: sans(14.5, color: T.t1),
              cursorColor: T.amber,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
                hintText: 'e.g. Personal, Work, main',
                hintStyle: sans(14.5, color: T.t3),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(tag, style: mono(11, color: T.t3)),
        ],
      ),
    );
  }

  Widget _info() {
    TextSpan b(String t) =>
        TextSpan(text: t, style: sans(12, weight: FontWeight.w500, color: T.t1));
    TextSpan n(String t) => TextSpan(text: t);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text('🔒', style: TextStyle(fontSize: 12, color: T.t3)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: sans(12, color: T.t2, height: 1.5),
                children: [
                  n('Sign-in completes in '),
                  b('$_where on this Mac'),
                  n('. Each account gets an '),
                  b('isolated slot'),
                  n(', and credentials stay on this Mac only.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _providerKey(Provider p) => switch (p) {
      Provider.claude => 'claude',
      Provider.codex => 'codex',
      Provider.anti => 'antigravity',
    };

/// Provider display name + the mockup's service·plan hint line.
(String, String) _providerMeta(Provider p) => switch (p) {
      Provider.claude => ('Claude', 'claude.ai · plan'),
      Provider.codex => ('Codex', 'chatgpt · plan'),
      Provider.anti => ('Antigravity', 'gemini · plan'),
    };

class _ProviderRow extends StatefulWidget {
  final Provider provider;
  final bool selected;
  final VoidCallback onTap;
  const _ProviderRow(
      {required this.provider, required this.selected, required this.onTap});

  @override
  State<_ProviderRow> createState() => _ProviderRowState();
}

class _ProviderRowState extends State<_ProviderRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    final (name, hint) = _providerMeta(widget.provider);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            color: sel
                ? const Color(0x12FFC465)
                : (_hover ? T.white(.055) : T.white(.03)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: sel ? const Color(0x73FFC465) : T.hair),
          ),
          child: Row(
            children: [
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: widget.provider.badgeBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: SvgPicture.asset(widget.provider.icon,
                      width: 20, height: 20),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name,
                      style: sans(14.5, weight: FontWeight.w600, color: T.t1)),
                  const SizedBox(height: 2),
                  Text(hint, style: mono(10.5, color: T.t3)),
                ],
              ),
              const Spacer(),
              _Radio(selected: sel),
            ],
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  final bool selected;
  const _Radio({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: selected ? T.amber : T.hair2, width: 1.5),
      ),
      child: Center(
        child: AnimatedScale(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutBack,
          scale: selected ? 1 : 0,
          child: Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              color: T.amber,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatefulWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(Icons.close_rounded,
              size: 16, color: _hover ? T.t1 : T.t2),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
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
          padding: const EdgeInsets.symmetric(vertical: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: T.amber,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFC465)
                    .withValues(alpha: _hover ? .3 : .2),
                blurRadius: _hover ? 16 : 10,
                offset: Offset(0, _hover ? 4 : 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.label,
                  style: sans(14,
                      weight: FontWeight.w700, color: const Color(0xFF0A0C12))),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded,
                  size: 16, color: Color(0xFF0A0C12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CancelButton extends StatefulWidget {
  final VoidCallback onTap;
  const _CancelButton({required this.onTap});

  @override
  State<_CancelButton> createState() => _CancelButtonState();
}

class _CancelButtonState extends State<_CancelButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Text('Cancel',
              style: mono(12, color: _hover ? T.t2 : T.t3)),
        ),
      ),
    );
  }
}
