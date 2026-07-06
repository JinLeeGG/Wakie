import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:wakie/tray_icon.dart';

/// Bakes the menu-bar icon PNGs the tray loads at runtime, from
/// [TrayIconPainter]. Not a `_test.dart` file, so it runs only when invoked
/// directly: `flutter test test/tools/gen_tray_icons.dart`. Deterministic —
/// re-running produces identical bytes, so it won't dirty the tree.
Future<void> _write(String name, TrayIconPainter painter, int px) async {
  final recorder = PictureRecorder();
  painter.paint(Canvas(recorder), Size(px.toDouble(), px.toDouble()));
  final image = await recorder.endRecording().toImage(px, px);
  final bytes = await image.toByteData(format: ImageByteFormat.png);
  File('assets/tray/$name').writeAsBytesSync(bytes!.buffer.asUint8List());
}

Future<void> _state(String name, TrayIconPainter painter) async {
  await _write('$name.png', painter, 18);
  await _write('$name@2x.png', painter, 36);
}

void main() {
  test('generate tray icons', () async {
    Directory('assets/tray').createSync(recursive: true);
    await _state('idle', const TrayIconPainter(TrayState.idle));
    await _state('attention', const TrayIconPainter(TrayState.attention));
    for (var f = 0; f < trayWorkFrames; f++) {
      await _state('work_$f', TrayIconPainter(TrayState.working, frame: f));
    }
  });
}
