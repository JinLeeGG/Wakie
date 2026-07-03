import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:tray_manager/tray_manager.dart';

/// The three menu-bar-icon states (docs/design/menubar-icon.html):
///  - [idle]      : ring + amber core, calm — all accounts healthy.
///  - [working]   : dim ring + a sweeping amber arc — waking / refreshing.
///  - [attention] : ring + core + a red badge — an account ran low or expired.
enum TrayState { idle, working, attention }

/// The 12 pre-rendered rotation frames of the working arc.
const trayWorkFrames = 12;

/// Draws the WakieAI status-bar icon on a 100×100 canvas — used by the asset
/// generator (test/tools/gen_tray_icons.dart) to bake the PNGs the tray loads.
/// Colored (not a template) so the amber core survives; the ring is near-white
/// to sit with the system glyphs on a dark menu bar.
class TrayIconPainter extends CustomPainter {
  final TrayState state;
  final int frame;
  const TrayIconPainter(this.state, {this.frame = 0});

  static const _amber = Color(0xFFF6B23C);
  static const _crit = Color(0xFFFF7A85);
  static const _ringLit = Color(0xE0FFFFFF);
  // Bright enough to keep the working icon's full circular footprint on a dark
  // menu bar (0.28 vanished there and made it read small); the amber arc still
  // reads as the sweep on top.
  static const _ringDim = Color(0x8CFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100.0;
    final c = Offset(50 * s, 50 * s);
    final stroke = 7 * s;
    final ringR = 38 * s;
    final coreR = 21 * s;

    Paint ringPaint(Color col) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = col
      ..isAntiAlias = true;
    final core = Paint()
      ..color = _amber
      ..isAntiAlias = true;

    switch (state) {
      case TrayState.idle:
        canvas.drawCircle(c, ringR, ringPaint(_ringLit));
        canvas.drawCircle(c, coreR, core);
      case TrayState.working:
        canvas.drawCircle(c, ringR, ringPaint(_ringDim));
        final start = (frame / trayWorkFrames) * 2 * math.pi - math.pi / 2;
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: ringR),
          start,
          87 * math.pi / 180,
          false,
          ringPaint(_amber)..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(c, coreR, core);
      case TrayState.attention:
        final badge = Offset(76 * s, 24 * s);
        canvas.saveLayer(Offset.zero & size, Paint());
        canvas.drawCircle(c, ringR, ringPaint(_ringLit));
        canvas.drawCircle(c, coreR, core);
        // Punch a transparent gap so the badge reads clear of the ring.
        canvas.drawCircle(badge, 18 * s, Paint()..blendMode = BlendMode.clear);
        canvas.restore();
        canvas.drawCircle(
            badge, 13 * s, Paint()..color = _crit..isAntiAlias = true);
    }
  }

  @override
  bool shouldRepaint(TrayIconPainter old) =>
      old.state != state || old.frame != frame;
}

/// Drives the menu-bar icon from app state, cycling the pre-rendered working
/// frames while busy. Colored icons (isTemplate: false) so the amber core and
/// red badge keep their color.
class TrayIcon {
  TrayState? _state;
  Timer? _spin;
  int _frame = 0;

  Future<void> init() => set(TrayState.idle);

  Future<void> set(TrayState next) async {
    if (next == _state) return;
    _state = next;
    _spin?.cancel();
    _spin = null;
    if (next == TrayState.working) {
      _frame = 0;
      await _show('work_0');
      _spin = Timer.periodic(const Duration(milliseconds: 75), (_) {
        _frame = (_frame + 1) % trayWorkFrames;
        trayManager.setIcon('assets/tray/work_$_frame.png', isTemplate: false);
      });
    } else {
      await _show(next == TrayState.attention ? 'attention' : 'idle');
    }
  }

  Future<void> _show(String name) =>
      trayManager.setIcon('assets/tray/$name.png', isTemplate: false);

  void dispose() => _spin?.cancel();
}
