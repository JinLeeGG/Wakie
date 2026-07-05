import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bakes the macOS app icon (AppIcon.appiconset) from the WakieAI orbit mark on
/// a dawn-gradient tile — the same brand as the tray icon and the landing page.
/// Not a `_test.dart` file, so it runs only when invoked directly:
///   flutter test test/tools/gen_app_icon.dart
/// Each size is painted at native resolution (crisp, not downscaled).
const _iconDir = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';

void _paint(Canvas canvas, double px) {
  // Rounded-rect tile with a margin, macOS corner ratio (~0.2237 of the tile).
  final margin = 88.0 * px / 1024;
  final tile = Rect.fromLTWH(margin, margin, px - margin * 2, px - margin * 2);
  final rr = RRect.fromRectAndRadius(
      tile, Radius.circular(tile.width * 0.2237));

  canvas.save();
  canvas.clipRRect(rr);
  // Dawn gradient: deep night up top → warm horizon at the bottom.
  canvas.drawRect(
    tile,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0B0C12), Color(0xFF15111C), Color(0xFF2A1806)],
        stops: [0.0, 0.55, 1.0],
      ).createShader(tile),
  );
  // Rising-sun amber glow, low-centre.
  final glowC = Offset(px / 2, px * 0.56);
  canvas.drawCircle(
    glowC,
    px * 0.36,
    Paint()
      ..shader = RadialGradient(
        colors: const [Color(0x70FFC465), Color(0x00FFC465)],
      ).createShader(Rect.fromCircle(center: glowC, radius: px * 0.36)),
  );
  canvas.restore();

  // Orbit mark, centred on the tile.
  final c = Offset(px / 2, px * 0.5);
  final coreR = px * 0.11;
  // core glow
  canvas.drawCircle(
    c,
    coreR,
    Paint()
      ..color = const Color(0xB0FFC465)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, px * 0.05),
  );
  // core
  canvas.drawCircle(c, coreR, Paint()..color = const Color(0xFFFFC465));
  // tilted orbit ring
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(-24 * math.pi / 180);
  canvas.drawOval(
    Rect.fromCenter(center: Offset.zero, width: px * 0.62, height: px * 0.30),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = px * 0.028
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xE6FFFFFF)
      ..isAntiAlias = true,
  );
  canvas.restore();
}

Future<void> _write(int px) async {
  final rec = PictureRecorder();
  _paint(Canvas(rec), px.toDouble());
  final img = await rec.endRecording().toImage(px, px);
  final bytes = await img.toByteData(format: ImageByteFormat.png);
  File('$_iconDir/app_icon_$px.png')
      .writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('generate app icon', () async {
    for (final px in [16, 32, 64, 128, 256, 512, 1024]) {
      await _write(px);
    }
  });
}
