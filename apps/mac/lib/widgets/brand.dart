import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Wakie **orbit mark v2** — a tilted orbit ring around a glowing amber core
/// (docs/design/BRAND.md, captured from the landing page). The canonical brand
/// mark; supersedes the old concentric ring+core SVG. Design space is 24×24,
/// scaled to [size]. Built for dark surfaces (the ring is white @55%).
class OrbitMark extends StatelessWidget {
  final double size;
  const OrbitMark({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: const _OrbitPainter()),
      );
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24; // design space is 24×24
    final c = Offset(size.width / 2, size.height / 2);

    // soft glow under the core
    canvas.drawCircle(
      c,
      4.4 * s,
      Paint()
        ..color = const Color(0x80FFC465)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5 * s),
    );
    // amber core (BRAND.md: #ffc465 = T.amber, not the deeper logo-v1 amber)
    canvas.drawCircle(c, 4.4 * s, Paint()..color = T.amber);

    // tilted orbit ring
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-24 * math.pi / 180);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 21 * s, height: 10 * s),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3 * s
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x8CFFFFFF), // white @ 55%
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) => false;
}

/// The **"Wakie" wordmark v2** — alternating amber/white letters in Instrument
/// Sans semibold (BRAND.md). No "AI" suffix; the letters carry the brand.
/// W·k·e amber, a·i white.
class WakieWordmark extends StatelessWidget {
  final double fontSize;
  final FontWeight weight;
  const WakieWordmark({
    super.key,
    this.fontSize = 17,
    this.weight = FontWeight.w600,
  });

  @override
  Widget build(BuildContext context) {
    TextStyle base(Color color) => TextStyle(
          fontFamily: T.sans,
          fontWeight: weight,
          fontSize: fontSize,
          height: 1.0,
          letterSpacing: fontSize * -0.025,
          color: color,
        );
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: 'W', style: base(T.amber)),
        TextSpan(text: 'a', style: base(T.t1)),
        TextSpan(text: 'k', style: base(T.amber)),
        TextSpan(text: 'i', style: base(T.t1)),
        TextSpan(text: 'e', style: base(T.amber)),
      ]),
    );
  }
}
