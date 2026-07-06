import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';

/// Per-provider install guidance: how the CLI is installed and where its
/// official page lives. Antigravity has no standalone CLI package — `agy`
/// ships inside the Antigravity app — so it has no copyable command.
({String name, String? command, String url}) _guide(Provider p) => switch (p) {
      Provider.claude => (
          name: 'Claude Code',
          command: 'npm install -g @anthropic-ai/claude-code',
          url: 'https://claude.com/claude-code',
        ),
      Provider.codex => (
          name: 'Codex CLI',
          command: 'npm install -g @openai/codex',
          url: 'https://developers.openai.com/codex/cli',
        ),
      Provider.anti => (
          name: 'Antigravity',
          command: null,
          url: 'https://antigravity.google',
        ),
    };

/// Shown when the user tries to add an account whose provider CLI isn't
/// installed: Wakie reads usage through the official CLI, so the login
/// can't even start. Quiet and actionable — the install command (copyable)
/// and a button to the official install page, in the ConfirmModal style.
class InstallCliModal extends StatefulWidget {
  final Provider provider;
  final VoidCallback onClose;

  /// Opens the install page. Injectable so widget tests don't spawn `open`.
  final void Function(String url)? onOpenUrl;

  const InstallCliModal({
    super.key,
    required this.provider,
    required this.onClose,
    this.onOpenUrl,
  });

  @override
  State<InstallCliModal> createState() => _InstallCliModalState();
}

class _InstallCliModalState extends State<InstallCliModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..forward();
  bool _copied = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _openGuide(String url) {
    (widget.onOpenUrl ?? (u) => Process.run('open', [u]))(url);
    widget.onClose();
  }

  Future<void> _copy(String command) async {
    await Clipboard.setData(ClipboardData(text: command));
    if (!mounted) return;
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final v = Curves.easeOutCubic.transform(_c.value);
        return Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
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
    final g = _guide(widget.provider);
    return Container(
      width: 420,
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
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: widget.provider.badgeBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: T.hair2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.asset(widget.provider.icon,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text("${g.name} isn't installed",
                      style: sans(17, weight: FontWeight.w600, color: T.t1)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.provider == Provider.anti
                  ? 'Wakie reads usage through the official agy CLI, which '
                      'ships with the Antigravity app. Install it, then add '
                      'this account again.'
                  : 'Wakie reads usage through the official CLI. Install '
                      'it, then add this account again.',
              style: sans(12.5, color: T.t3, height: 1.5),
            ),
            if (g.command != null) ...[
              const SizedBox(height: 14),
              _commandRow(g.command!),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _Btn(
                  label: 'Close',
                  fg: T.t2,
                  bg: Colors.transparent,
                  hoverBg: T.white(.05),
                  onTap: widget.onClose,
                ),
                const SizedBox(width: 6),
                _Btn(
                  label: 'Open install page',
                  fg: T.amber,
                  bg: const Color(0x1FFFC465),
                  hoverBg: const Color(0x33FFC465),
                  onTap: () => _openGuide(g.url),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _commandRow(String command) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
      decoration: BoxDecoration(
        color: T.white(.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: T.hair),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(command,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: mono(11.5, color: T.t2)),
          ),
          const SizedBox(width: 8),
          _Btn(
            label: _copied ? 'Copied' : 'Copy',
            fg: _copied ? T.ok : T.t2,
            bg: T.white(.04),
            hoverBg: T.white(.08),
            onTap: () => _copy(command),
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
