import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models.dart';
import '../theme.dart';

/// The empty-dashboard hero: three provider planets floating quietly over a
/// faint starfield — no orbits, no sun — with the WakieAI wordmark as a soft
/// watermark below. Each planet drifts a few pixels on its own slow rhythm;
/// hovering lifts it with a warm glow and names it, clicking opens Add
/// Account. Calm on purpose: this screen idles on screen, so nothing here
/// should demand attention.
class EmptyOrbit extends StatefulWidget {
  final VoidCallback onAdd;
  const EmptyOrbit({super.key, required this.onAdd});

  @override
  State<EmptyOrbit> createState() => _EmptyOrbitState();
}

// Design canvas; the whole thing scales down to fit its slot.
const double _stageW = 520;
const double _stageH = 240;

Color _c(int hex, [int? a]) =>
    Color(a == null ? hex : ((a << 24) | (hex & 0xFFFFFF)));

class _Planet {
  final Provider provider;
  final String label;
  final Offset pos; // resting center on the stage
  final double d; // diameter
  final double bobPeriod, bobPhase; // slow vertical drift
  final int hi, mid, shadow; // sphere tones, 0xFFRRGGBB
  final Color tint; // brand glyph color on the sphere
  const _Planet(this.provider, this.label, this.pos, this.d, this.bobPeriod,
      this.bobPhase, this.hi, this.mid, this.shadow, this.tint);
}

// Asymmetric, breathing-room arrangement: left mid, center high, right low.
const _planets = <_Planet>[
  _Planet(Provider.anti, 'Antigravity', Offset(104, 122), 84, 7.2, 0.0, //
      0xFFE4ECFF, 0xFF8EA9F5, 0xFF3A4A9E, Color(0xFFFFFFFF)),
  _Planet(Provider.claude, 'Claude', Offset(260, 80), 92, 8.6, 2.1, //
      0xFFF9CBAE, 0xFFD9835F, 0xFF6E3620, Color(0xFFFFFFFF)),
  _Planet(Provider.codex, 'Codex', Offset(414, 140), 84, 7.9, 4.4, //
      0xFFFFFFFF, 0xFFC4C9D3, 0xFF4A4E56, Color(0xFF2A2D35)),
];

class _Star {
  final double x, y, r, base, twinkle, phase;
  const _Star(this.x, this.y, this.r, this.base, this.twinkle, this.phase);
}

class _EmptyOrbitState extends State<EmptyOrbit>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _clock = ValueNotifier(0);
  int? _hover;
  late final List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(7);
    _stars = List.generate(38, (_) {
      return _Star(
        rng.nextDouble() * _stageW,
        rng.nextDouble() * _stageH,
        0.5 + rng.nextDouble() * 1.0,
        0.08 + rng.nextDouble() * 0.26,
        0.25 + rng.nextDouble() * 0.5,
        rng.nextDouble() * math.pi * 2,
      );
    });
    _ticker = createTicker((elapsed) {
      _clock.value = elapsed.inMicroseconds / 1e6;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // One FittedBox around stage + watermark, so a short slot scales the whole
    // scene down together instead of the column overflowing.
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: _stageW,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: _stageW,
                height: _stageH,
                child: AnimatedBuilder(
                  animation: _clock,
                  builder: (context, _) => _buildStage(),
                ),
              ),
              const SizedBox(height: 22),
              _watermark(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStage() {
    final t = _clock.value;
    // Live centers (resting position + drift) — shared by the planets, their
    // name chips, and the constellation lines, so everything moves as one.
    final centers = [
      for (final p in _planets)
        Offset(p.pos.dx,
            p.pos.dy + 4.0 * math.sin(2 * math.pi * (t / p.bobPeriod) + p.bobPhase)),
    ];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
            child: CustomPaint(painter: _StarfieldPainter(_stars, t))),
        // Hairlines joining the three — your AI constellation, drifting with it.
        Positioned.fill(
            child: CustomPaint(painter: _ConstellationPainter(centers))),
        for (var i = 0; i < _planets.length; i++) _planet(i, centers[i]),
        for (var i = 0; i < _planets.length; i++) _chip(i, centers[i]),
      ],
    );
  }

  Widget _planet(int i, Offset center) {
    final p = _planets[i];
    final hovered = _hover == i;
    return Positioned(
      left: center.dx - p.d / 2,
      top: center.dy - p.d / 2,
      width: p.d,
      height: p.d,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = i),
        onExit: (_) => setState(() => _hover = null),
        child: GestureDetector(
          onTap: widget.onAdd,
          child: AnimatedScale(
            scale: hovered ? 1.06 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  // Grounding shadow into space, warming up on hover.
                  BoxShadow(
                    color: _c(0x000000, 0x30),
                    blurRadius: 18,
                    spreadRadius: -4,
                    offset: const Offset(0, 8),
                  ),
                  if (hovered)
                    BoxShadow(
                      color: _c(0xFFC465, 0x38),
                      blurRadius: 28,
                      spreadRadius: -2,
                    ),
                ],
              ),
              child: ClipOval(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                        child: CustomPaint(painter: _SpherePainter(p))),
                    SvgPicture.asset(
                      p.provider.icon,
                      width: p.d * 0.40,
                      height: p.d * 0.40,
                      colorFilter: ColorFilter.mode(p.tint, BlendMode.srcIn),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The name label under a planet — its own stage layer (not stacked inside
  /// the planet's box, which is what overflowed), fading in on hover.
  Widget _chip(int i, Offset center) {
    final p = _planets[i];
    return Positioned(
      left: center.dx - 60,
      top: center.dy + p.d / 2 + 10,
      width: 120,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _hover == i ? 1 : 0,
          duration: const Duration(milliseconds: 160),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _c(0x0A0C12, 0xD8),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: T.hair),
              ),
              child: Text(p.label,
                  style: mono(10, color: T.t1, letterSpacing: 0.4)),
            ),
          ),
        ),
      ),
    );
  }

  /// The WakieAI wordmark where the CTA used to live — a quiet watermark.
  /// Brand rule: "Wakie" amber, "AI" white.
  Widget _watermark() {
    TextStyle base(Color color) => TextStyle(
          fontFamily: T.mono,
          fontWeight: FontWeight.w700,
          fontSize: 19,
          height: 1.0,
          letterSpacing: 0.4,
          color: color,
        );
    return Opacity(
      opacity: 0.6,
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: 'Wakie', style: base(T.amberDeep)),
          TextSpan(text: 'AI', style: base(const Color(0xFFFFFFFF))),
        ]),
      ),
    );
  }
}

/// A softly lit sphere under a fixed top-left key light: base tone, a broad
/// highlight, a gentle lower-right shade, limb darkening for curvature, and a
/// small specular — restrained, so the brand glyph stays the subject.
class _SpherePainter extends CustomPainter {
  final _Planet p;
  _SpherePainter(this.p);

  static const _light = Alignment(-0.35, -0.5);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final rect = Offset.zero & size;

    canvas.drawCircle(c, r, Paint()..color = _c(p.mid));

    // Key-light highlight.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: _light,
          radius: 1.0,
          colors: [_c(p.hi, 0xE6), _c(p.hi, 0x00)],
          stops: const [0.0, 0.68],
        ).createShader(rect),
    );

    // Soft shade opposite the light.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.45, 0.6),
          radius: 1.05,
          colors: [_c(p.shadow, 0x6E), _c(p.shadow, 0x00)],
          stops: const [0.0, 0.75],
        ).createShader(rect),
    );

    // Limb darkening — the thin rim that sells the curvature.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [_c(0x000000, 0x00), _c(0x000000, 0x00), _c(0x000000, 0x4A)],
          stops: const [0.0, 0.76, 1.0],
        ).createShader(rect),
    );

    // Small specular near the light.
    final sp = c + Offset(_light.x, _light.y) * r * 0.5;
    canvas.drawCircle(
      sp,
      r * 0.2,
      Paint()
        ..shader = RadialGradient(colors: [
          _c(0xFFFFFF, 0x8C),
          _c(0xFFFFFF, 0x00),
        ]).createShader(Rect.fromCircle(center: sp, radius: r * 0.2))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8),
    );
  }

  @override
  bool shouldRepaint(_SpherePainter old) => false;
}

/// Hairlines linking the three planets into a constellation — drawn edge to
/// edge with a small gap off each sphere, so they read as a star chart, not
/// wires. They drift with the planets' bobbing, which keeps the scene alive.
class _ConstellationPainter extends CustomPainter {
  final List<Offset> centers;
  _ConstellationPainter(this.centers);

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _c(0xFFFFFF, 0x16);
    for (var i = 0; i < centers.length - 1; i++) {
      final a = centers[i], b = centers[i + 1];
      final delta = b - a;
      final dir = delta / delta.distance;
      final ra = _planets[i].d / 2 + 14;
      final rb = _planets[i + 1].d / 2 + 14;
      canvas.drawLine(a + dir * ra, b - dir * rb, line);
    }
  }

  @override
  bool shouldRepaint(_ConstellationPainter old) => true; // drifts every frame
}

/// A faint, slowly twinkling starfield — just enough atmosphere to keep the
/// space mood without competing with the planets.
class _StarfieldPainter extends CustomPainter {
  final List<_Star> stars;
  final double time;
  _StarfieldPainter(this.stars, this.time);

  @override
  void paint(Canvas canvas, Size size) {
    final star = Paint();
    for (final s in stars) {
      final tw = 0.65 + 0.35 * math.sin(time * s.twinkle + s.phase);
      star.color = _c(0xFFFFFF, (s.base * tw * 255).round().clamp(0, 255));
      canvas.drawCircle(Offset(s.x, s.y), s.r, star);
    }
  }

  @override
  bool shouldRepaint(_StarfieldPainter old) => old.time != time;
}
