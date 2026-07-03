import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// Bakes the glyph-only provider logos used by the dashboard, from the real
/// app icons in assets/icons/*_app.png (themselves extracted from each
/// installed app's .icns — see the git history of those files).
///
///  - claude_logo.png: the cream starburst lifted off the terracotta squircle.
///    Per-pixel unmix: estimate the background per row from a strip left of
///    the glyph, then alpha = the signed projection of (pixel − bg) onto
///    (cream − bg) — shadows project negative and drop out, anti-aliased
///    edges land in between.
///  - antigravity_logo.png: the rainbow arch lifted off the dark squircle by
///    saturation keying — the glyph's gradient runs along its path (red apex,
///    green left, blue legs), which SVG gradients can't express, while the
///    background (grid included) is pure grays; alpha = smoothstep over
///    saturation separates them cleanly. Anti-aliased edges keep a whisper of
///    the dark bg, invisible on the app's equally dark panels.
///  - Codex needs nothing: codex_app.png is already the cloud on transparency.
///
/// Not a `_test.dart` file, so it runs only when invoked directly:
///   flutter test test/tools/gen_provider_logos.dart
Future<ui.Image> _load(String path) async {
  final bytes = Uint8List.fromList(File(path).readAsBytesSync());
  final codec = await ui.instantiateImageCodec(bytes);
  return (await codec.getNextFrame()).image;
}

void main() {
  test('extract claude starburst', () async {
    final img = await _load('assets/icons/claude_app.png');
    final w = img.width, h = img.height;
    final px =
        (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!
            .buffer
            .asUint8List();
    int idx(int x, int y) => (y * w + x) * 4;

    // Anthropic ivory, the starburst's color.
    const cr = 243.0, cg = 240.0, cb = 232.0;

    final out = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      // Background terracotta for this row, from a strip inside the squircle
      // but left of the starburst.
      double br = 0, bg = 0, bb = 0;
      var n = 0;
      for (var x = (w * 0.09).round(); x < (w * 0.19).round(); x++) {
        final i = idx(x, y);
        if (px[i + 3] > 200) {
          br += px[i];
          bg += px[i + 1];
          bb += px[i + 2];
          n++;
        }
      }
      if (n < 8) continue; // squircle corner rows — no glyph there
      final rr = br / n, rg = bg / n, rb = bb / n;
      final dr = cr - rr, dg = cg - rg, db = cb - rb;
      final den = dr * dr + dg * dg + db * db;

      for (var x = 0; x < w; x++) {
        final i = idx(x, y);
        final a = px[i + 3];
        if (a < 10 || den == 0) continue;
        final t = (((px[i] - rr) * dr + (px[i + 1] - rg) * dg + (px[i + 2] - rb) * db) /
                den)
            .clamp(0.0, 1.0);
        final s = t * t * (3 - 2 * t); // smoothstep cleans the fringe
        out[i] = 243;
        out[i + 1] = 240;
        out[i + 2] = 232;
        out[i + 3] = (s * a).round();
      }
    }

    final buf = await ui.ImmutableBuffer.fromUint8List(out);
    final desc = ui.ImageDescriptor.raw(buf,
        width: w, height: h, pixelFormat: ui.PixelFormat.rgba8888);
    final logo = (await (await desc.instantiateCodec()).getNextFrame()).image;
    final png = await logo.toByteData(format: ui.ImageByteFormat.png);
    File('assets/icons/claude_logo.png')
        .writeAsBytesSync(png!.buffer.asUint8List());
  });

  test('extract antigravity arch', () async {
    final img = await _load('assets/icons/antigravity_app.png');
    final w = img.width, h = img.height;
    final px =
        (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!
            .buffer
            .asUint8List();

    final out = Uint8List(w * h * 4);
    for (var p = 0; p < w * h; p++) {
      final i = p * 4;
      final a = px[i + 3];
      if (a < 10) continue;
      final r = px[i], g = px[i + 1], b = px[i + 2];
      final mx = math.max(r, math.max(g, b));
      final mn = math.min(r, math.min(g, b));
      // Saturation key: the arch is vividly colored, the squircle (grid
      // lines included) is gray. Smoothstep keeps the anti-aliased edge soft.
      final t = ((mx - mn - 16) / (42.0 - 16.0)).clamp(0.0, 1.0);
      // Brightness rescue: the white specular streak on the arch is part of
      // the glyph but unsaturated — and the background is never this bright.
      final bright = ((mx - 140) / (190.0 - 140.0)).clamp(0.0, 1.0);
      final k = math.max(t, bright);
      final s = k * k * (3 - 2 * k);
      if (s == 0) continue;
      out[i] = r;
      out[i + 1] = g;
      out[i + 2] = b;
      out[i + 3] = (s * a).round();
    }

    final buf = await ui.ImmutableBuffer.fromUint8List(out);
    final desc = ui.ImageDescriptor.raw(buf,
        width: w, height: h, pixelFormat: ui.PixelFormat.rgba8888);
    final logo = (await (await desc.instantiateCodec()).getNextFrame()).image;
    final png = await logo.toByteData(format: ui.ImageByteFormat.png);
    File('assets/icons/antigravity_logo.png')
        .writeAsBytesSync(png!.buffer.asUint8List());
  });
}
