import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bakes the README hero wordmark — the same "Wakie" wordmark v2 as the landing
/// page (W·k·e amber, a·i near-white, Instrument Sans 600) sitting on a dark
/// glass chip, so it reads on GitHub's light *and* dark themes (a bare wordmark
/// with near-white letters would vanish on the light-theme white page). SVG
/// can't be used because GitHub won't load the Instrument Sans webfont — this
/// bakes the glyphs into a PNG.
///
/// Not a `_test.dart` file, so it runs only when invoked directly:
///   flutter test test/tools/gen_readme_wordmark.dart
const _out = '../../docs/design/readme-wordmark.png';

const _amber = Color(0xFFFFC465); // T.amber
const _near = Color(0xFFF3F4F7); // T.t1

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  test('generate README wordmark', () async {
    // Load the bundled Instrument Sans so the baked glyphs match the app/site.
    final bytes = File('assets/fonts/InstrumentSans.ttf').readAsBytesSync();
    final loader = FontLoader('InstrumentSans')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();

    await binding.runAsync(() async {
      const f = 132.0; // render font size (high-res, scaled down in README)
      TextStyle style(Color c) => TextStyle(
            fontFamily: 'InstrumentSans',
            fontWeight: FontWeight.w600,
            fontSize: f,
            height: 1.0,
            letterSpacing: f * -0.025,
            color: c,
          );
      final tp = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(children: [
          TextSpan(text: 'W', style: style(_amber)),
          TextSpan(text: 'a', style: style(_near)),
          TextSpan(text: 'k', style: style(_amber)),
          TextSpan(text: 'i', style: style(_near)),
          TextSpan(text: 'e', style: style(_amber)),
        ]),
      )..layout();

      const padX = 84.0, padY = 60.0;
      final w = (tp.width + padX * 2).ceilToDouble();
      final h = (tp.height + padY * 2).ceilToDouble();
      final r = Rect.fromLTWH(0, 0, w, h);
      final chip = RRect.fromRectAndRadius(r, Radius.circular(h * 0.32));

      final rec = PictureRecorder();
      final canvas = Canvas(rec);
      canvas.clipRRect(chip);

      // Dark glass fill — deep-night vertical gradient like the app panel.
      canvas.drawRect(
        r,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF141621), Color(0xFF0B0C12)],
          ).createShader(r),
      );
      // Warm amber glow, low-centre (the "dawn" motif).
      final glowC = Offset(w / 2, h * 0.72);
      canvas.drawCircle(
        glowC,
        h * 0.7,
        Paint()
          ..shader = RadialGradient(
            colors: const [Color(0x2EFFC465), Color(0x00FFC465)],
          ).createShader(Rect.fromCircle(center: glowC, radius: h * 0.7)),
      );
      // Hairline glass edge.
      canvas.drawRRect(
        chip.deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0x14FFFFFF),
      );

      tp.paint(canvas, Offset(padX, (h - tp.height) / 2));

      final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
      final png = await img.toByteData(format: ImageByteFormat.png);
      File(_out).writeAsBytesSync(png!.buffer.asUint8List());
      // ignore: avoid_print
      print('wrote $_out  (${w.toInt()}×${h.toInt()})');
    });
  });
}
