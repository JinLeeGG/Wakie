import 'package:flutter/widgets.dart';

/// Design tokens lifted directly from docs/design/dashboard-mockup.html (:root).
class T {
  // Text
  static const t1 = Color(0xFFF3F4F7);
  static const t2 = Color(0xFFA9AEB8);
  static const t3 = Color(0xFF6A7080);

  // Accent + semantic
  static const amber = Color(0xFFFFC465);
  static const amberDeep = Color(0xFFF6B23C); // logo core / selected accents
  static const ok = Color(0xFF5FD39A);
  static const warn = Color(0xFFFFBF5C);
  static const crit = Color(0xFFFF7A85);

  // Surfaces
  // Opaque enough (.80) to stay legible over white/bright windows behind the
  // panel — the hudWindow blur bleeds whatever is underneath through the tint.
  static const glass = Color(0xCC161820); // rgba(22,24,32,.80)
  static const hair = Color(0x17FFFFFF); // rgba(255,255,255,.09)
  static const hair2 = Color(0x24FFFFFF); // rgba(255,255,255,.14)

  static const sans = 'InstrumentSans';
  static const mono = 'JetBrainsMono';

  static Color white(double o) => Color.fromRGBO(255, 255, 255, o);
}

/// Convenience text style builders.
TextStyle sans(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = T.t1,
  double? letterSpacing,
  double? height,
}) =>
    TextStyle(
      fontFamily: T.sans,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );

TextStyle mono(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = T.t1,
  double? letterSpacing,
  double? height,
}) =>
    TextStyle(
      fontFamily: T.mono,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
