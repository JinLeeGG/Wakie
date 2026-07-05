import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:tray_manager/tray_manager.dart';

/// The three menu-bar-icon states (docs/design/menubar-icon.html):
///  - [idle]      : ring + amber core, calm — all accounts healthy.
///  - [working]   : dim ring + a sweeping amber arc — waking / refreshing.
///  - [attention] : ring + core + a red badge — an account ran low or expired.
enum TrayState { idle, working, attention }

/// Pre-rendered rotation frames of the working arc — enough (15° steps) that
/// the spin reads smooth rather than stepping.
const trayWorkFrames = 24;

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
    // Larger ring/core = less dead padding, so the glyph fills more of the
    // menu-bar slot and reads bigger next to the system icons.
    final ringR = 42 * s;
    final coreR = 23 * s;

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
          // Bright white sweep over the dim white ring; the amber stays the core.
          false,
          ringPaint(const Color(0xFFFFFFFF))..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(c, coreR, core);
      case TrayState.attention:
        final badge = Offset(78 * s, 22 * s);
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

  // tray_manager's own channel. Its setIcon() re-loads the asset from the
  // bundle and base64-encodes it on *every* call — cheap once, but the working
  // spinner ran that (plus a channel hop and a native NSImage decode) 25×/s.
  // We pre-encode the frames once and push the cached base64 straight to the
  // plugin's native handler, so a per-frame swap costs only the channel hop and
  // one decode — no asset read or re-encode.
  static const _tray = MethodChannel('tray_manager');
  List<String>? _workB64;

  Future<void> init() async {
    await _preloadWorkFrames();
    await set(TrayState.idle);
  }

  /// Base64-encode the working-arc frames up front. @2x (36px) art, matching
  /// [_show] — tray_manager forces an 18pt NSImage, so a 36px bitmap renders
  /// crisp 1:1 on a Retina menu bar.
  Future<void> _preloadWorkFrames() async {
    final frames = <String>[];
    for (var i = 0; i < trayWorkFrames; i++) {
      final data = await rootBundle.load('assets/tray/work_$i@2x.png');
      frames.add(base64Encode(data.buffer.asUint8List()));
    }
    _workB64 = frames;
  }

  Future<void> set(TrayState next) async {
    if (next == _state) return;
    _state = next;
    _spin?.cancel();
    _spin = null;
    if (next == TrayState.working) {
      _frame = 0;
      await _showFrame(0);
      // 10 fps: still reads smooth for a small glyph, but a fifth of the icon
      // swaps the old 40ms loop did (each swap costs a native NSImage decode).
      _spin = Timer.periodic(const Duration(milliseconds: 100), (_) {
        _frame = (_frame + 1) % trayWorkFrames;
        _showFrame(_frame);
      });
    } else {
      await _show(next == TrayState.attention ? 'attention' : 'idle');
    }
  }

  /// Push a pre-encoded working frame straight to the tray plugin — no asset
  /// load or base64 per frame. Falls back to the path API only if preload
  /// hasn't finished (init awaits it, so this is belt-and-suspenders).
  Future<void> _showFrame(int frame) {
    final cached = _workB64;
    if (cached == null) {
      return trayManager.setIcon('assets/tray/work_$frame@2x.png',
          isTemplate: false);
    }
    return _tray.invokeMethod('setIcon', <String, dynamic>{
      'base64Icon': cached[frame],
      'isTemplate': false,
      'iconPosition': 'left',
      'iconSize': 18,
    });
  }

  // Load the @2x (36px) art, not the 18px base: tray_manager forces the
  // NSImage to an 18pt logical size, so an 18px bitmap gets upscaled 2× on a
  // Retina menu bar (blurry). A 36px bitmap at 18pt is a crisp 1:1 @2x render.
  Future<void> _show(String name) =>
      trayManager.setIcon('assets/tray/$name@2x.png', isTemplate: false);

  void dispose() => _spin?.cancel();
}
