import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models.dart';
import '../theme.dart';

/// The empty-dashboard hero (docs/design/dashboard-empty.html): a tilted orrery
/// with the WakieAI star at the center and the three provider "planets" gliding
/// along elliptical orbits, over a "Add your first account" call to action.
///
/// The planets are lit as real spheres: the star is the light source, so each
/// planet's bright side faces the star and its terminator sweeps as it orbits.
/// They swell to the front, slip behind the star at the back, twinkle over a
/// faint starfield, and the whole system pauses on hover to be read and clicked.
class EmptyOrbit extends StatefulWidget {
  final VoidCallback onAdd;
  const EmptyOrbit({super.key, required this.onAdd});

  @override
  State<EmptyOrbit> createState() => _EmptyOrbitState();
}

// Design canvas for the orrery; the whole thing scales down to fit its slot.
const double _stageW = 520;
const double _stageH = 290;
const double _sphere = 52; // planet diameter at 1× depth
const double _sun = 62;
const Offset _center = Offset(_stageW / 2, _stageH / 2);

Color _c(int hex, [int? a]) =>
    Color(a == null ? hex : ((a << 24) | (hex & 0xFFFFFF)));

class _Orbit {
  final Provider provider;
  final String label;
  final double rx, ry, dur, phase;
  final int hi, mid, shadow, atmo; // sphere tones, 0xFFRRGGBB
  final Color tint; // brand glyph color on the sphere
  const _Orbit(this.provider, this.label, this.rx, this.ry, this.dur,
      this.phase, this.hi, this.mid, this.shadow, this.atmo, this.tint);
}

const _orbits = <_Orbit>[
  _Orbit(Provider.anti, 'Antigravity', 112, 38, 40, 0.15, //
      0xFFE4ECFF, 0xFF7E9BF2, 0xFF243073, 0xFF6E8BF5, Color(0xFFFFFFFF)),
  _Orbit(Provider.claude, 'Claude', 166, 56, 58, 0.55, //
      0xFFF9CBAE, 0xFFD9835F, 0xFF4A2214, 0xFFE08A55, Color(0xFFFFFFFF)),
  _Orbit(Provider.codex, 'Codex', 220, 76, 78, 0.83, //
      0xFFFFFFFF, 0xFFBFC4CE, 0xFF34383F, 0xFFD8DEE8, Color(0xFF2A2D35)),
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
    _stars = List.generate(52, (_) {
      return _Star(
        rng.nextDouble() * _stageW,
        rng.nextDouble() * _stageH,
        0.5 + rng.nextDouble() * 1.1,
        0.10 + rng.nextDouble() * 0.35,
        0.3 + rng.nextDouble() * 0.7,
        rng.nextDouble() * math.pi * 2,
      );
    });
    // Free-running clock — the system orbits continuously, hover never stops it.
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: _stageW,
              height: _stageH,
              child: AnimatedBuilder(
                animation: _clock,
                builder: (context, _) => _buildStage(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _Cta(onTap: widget.onAdd),
        ],
      ),
    );
  }

  Widget _buildStage() {
    final t = _clock.value;
    final pulse = 0.5 + 0.5 * math.sin(t / 5 * 2 * math.pi);

    final back = <Widget>[];
    final front = <Widget>[];
    final chips = <Widget>[];

    for (var i = 0; i < _orbits.length; i++) {
      final o = _orbits[i];
      final angle = 2 * math.pi * (t / o.dur + o.phase);
      final pos = Offset(
        _center.dx + o.rx * math.cos(angle),
        _center.dy + o.ry * math.sin(angle),
      );
      final depth = math.sin(angle); // -1 far/behind … +1 near/front
      final f = (depth + 1) / 2;
      // Depth reads through scale; keep the floor high so the far planet stays
      // a legible sphere instead of a dim speck.
      final scale = 0.84 + 0.34 * f;
      final opacity = 0.88 + 0.12 * f;
      // Light comes from the star; the lit hemisphere faces it.
      final toStar = _center - pos;
      final len = toStar.distance;
      final light =
          len == 0 ? Alignment.center : Alignment(toStar.dx / len, toStar.dy / len);

      final planet = _planet(o, i, pos, scale, opacity, light);
      (depth < 0 ? back : front).add(planet);
      if (_hover == i) chips.add(_nameChip(o.label, pos, scale));
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
            child: CustomPaint(painter: _BackdropPainter(_stars, t))),
        _sunGlow(pulse),
        ...back,
        _sunMark(pulse),
        ...front,
        ...chips,
      ],
    );
  }

  Widget _planet(_Orbit o, int i, Offset pos, double scale, double opacity,
      Alignment light) {
    return Positioned(
      left: pos.dx - _sphere / 2,
      top: pos.dy - _sphere / 2,
      width: _sphere,
      height: _sphere,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = i),
        onExit: (_) => setState(() => _hover = null),
        child: GestureDetector(
          onTap: widget.onAdd,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: _Planet(orbit: o, light: light, lit: _hover == i),
            ),
          ),
        ),
      ),
    );
  }

  Widget _nameChip(String label, Offset pos, double scale) {
    return Positioned(
      left: pos.dx - 60,
      top: pos.dy + _sphere / 2 * scale + 7,
      width: 120,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: _c(0x0A0C12, 0xD8),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: T.hair),
          ),
          child: Text(label, style: mono(10, color: T.t1, letterSpacing: 0.4)),
        ),
      ),
    );
  }

  Widget _sunGlow(double pulse) {
    final size = _sun * (3.1 + 0.18 * pulse);
    return Positioned(
      left: _center.dx - size / 2,
      top: _center.dy - size / 2,
      width: size,
      height: size,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              _c(0xFFC46A, (0x2E + (0x22 * pulse)).round()),
              _c(0xFF9A3C, 0x12),
              _c(0xFF9A3C, 0x00),
            ], stops: const [0.0, 0.42, 0.75]),
          ),
        ),
      ),
    );
  }

  Widget _sunMark(double pulse) {
    const box = 156.0;
    return Positioned(
      left: _center.dx - box / 2,
      top: _center.dy - box / 2,
      width: box,
      height: box,
      child: IgnorePointer(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(child: CustomPaint(painter: _CoronaPainter(pulse))),
            _wordmark(pulse),
          ],
        ),
      ),
    );
  }

  /// The glowing WakieAI wordmark at the heart of the system — the "star".
  /// Brand rule: "Wakie" amber, "AI" white.
  Widget _wordmark(double pulse) {
    final glow = 8.0 + 4.0 * pulse;
    TextStyle base(Color color, double g) => TextStyle(
          fontFamily: T.mono,
          fontWeight: FontWeight.w700,
          fontSize: 20,
          height: 1.0,
          letterSpacing: 0.2,
          color: color,
          // Double glow: a tight hot core plus a wide soft halo, so the
          // letters read as the thing emitting the light.
          shadows: [
            Shadow(color: color, blurRadius: g * 0.5),
            Shadow(color: color.withValues(alpha: 0.55), blurRadius: g * 2.2),
          ],
        );
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: 'Wakie', style: base(T.amberDeep, glow)),
        TextSpan(text: 'AI', style: base(const Color(0xFFFFFFFF), glow * 0.85)),
      ]),
    );
  }
}

/// A provider planet rendered as a lit sphere: shaded base + specular under the
/// brand glyph, then the terminator and limb darkening over it so the glyph
/// sits on the surface. A soft atmosphere ring and ambient shadow ground it.
class _Planet extends StatelessWidget {
  final _Orbit orbit;
  final Alignment light;
  final bool lit;
  const _Planet({required this.orbit, required this.light, required this.lit});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Ambient occlusion into space + faint atmosphere on the lit limb.
        Positioned.fill(
          child: CustomPaint(painter: _AtmoPainter(orbit, light, lit)),
        ),
        ClipOval(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                  child: CustomPaint(painter: _SphereLoPainter(orbit, light))),
              SvgPicture.asset(
                orbit.provider.icon,
                width: _sphere * 0.46,
                height: _sphere * 0.46,
                colorFilter: ColorFilter.mode(orbit.tint, BlendMode.srcIn),
              ),
              Positioned.fill(
                  child: CustomPaint(painter: _SphereHiPainter(orbit, light))),
            ],
          ),
        ),
      ],
    );
  }
}

/// Base + lit hemisphere + specular (behind the glyph).
class _SphereLoPainter extends CustomPainter {
  final _Orbit o;
  final Alignment light;
  _SphereLoPainter(this.o, this.light);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final rect = Offset.zero & size;

    // Base body.
    canvas.drawCircle(c, r, Paint()..color = _c(o.mid));

    // Sunlit hemisphere — highlight fades toward the terminator.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(light.x * 0.6, light.y * 0.6),
          radius: 0.95,
          colors: [_c(o.hi), _c(o.hi, 0x00)],
          stops: const [0.0, 0.62],
        ).createShader(rect),
    );

    // Tight specular glint, just off the sub-solar point toward the viewer.
    final sp = c + Offset(light.x, light.y) * r * 0.52;
    canvas.drawCircle(
      sp,
      r * 0.30,
      Paint()
        ..shader = RadialGradient(colors: [
          _c(0xFFFFFF, 0xD0),
          _c(0xFFFFFF, 0x00),
        ]).createShader(Rect.fromCircle(center: sp, radius: r * 0.30))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6),
    );
  }

  @override
  bool shouldRepaint(_SphereLoPainter old) => old.light != light;
}

/// Terminator (dark side) + limb darkening (over the glyph).
class _SphereHiPainter extends CustomPainter {
  final _Orbit o;
  final Alignment light;
  _SphereHiPainter(this.o, this.light);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final rect = Offset.zero & size;

    // Night side, opposite the star — soft, with ambient bounce so the dark
    // hemisphere still reads as a sphere, not a black bite.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(-light.x * 0.55, -light.y * 0.55),
          radius: 1.05,
          colors: [_c(o.shadow, 0xA6), _c(o.shadow, 0x46), _c(o.shadow, 0x00)],
          stops: const [0.0, 0.48, 0.9],
        ).createShader(rect),
    );

    // Limb darkening — a thin dark rim all around reads as curvature.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [_c(0x000000, 0x00), _c(0x000000, 0x00), _c(0x000000, 0x5C)],
          stops: const [0.0, 0.74, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SphereHiPainter old) => old.light != light;
}

/// Ambient shadow into space + a Fresnel atmosphere crescent on the lit limb.
class _AtmoPainter extends CustomPainter {
  final _Orbit o;
  final Alignment light;
  final bool lit;
  _AtmoPainter(this.o, this.light, this.lit);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;

    // Soft dark halo so the sphere separates from the backdrop (no hard,
    // un-physical drop shadow — planets float in space).
    canvas.drawCircle(
      c,
      r * 1.16,
      Paint()
        ..color = _c(0x000000, 0x40)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // Atmosphere: a faint colored glow, brightest on the star-facing limb.
    final ap = c + Offset(light.x, light.y) * r * 0.55;
    canvas.drawCircle(
      ap,
      r * 1.28,
      Paint()
        ..shader = RadialGradient(
          colors: [_c(o.atmo, lit ? 0x5A : 0x38), _c(o.atmo, 0x00)],
          stops: const [0.55, 1.0],
        ).createShader(Rect.fromCircle(center: ap, radius: r * 1.28))
        ..blendMode = BlendMode.screen,
    );

    if (lit) {
      canvas.drawCircle(
        c,
        r + 1.2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = _c(0xFFC465, 0x99)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
      );
    }
  }

  @override
  bool shouldRepaint(_AtmoPainter old) => old.light != light || old.lit != lit;
}

/// The warm luminous halo behind the WakieAI wordmark — the "starlight" that
/// lights the planets. Bright enough to read as a light source, soft enough to
/// keep the wordmark legible; no solid disc so the letters stay the focal point.
class _CoronaPainter extends CustomPainter {
  final double pulse;
  _CoronaPainter(this.pulse);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.48 * (1 + 0.045 * pulse);

    // Inner hot heart right behind the letters, then the wide warm falloff —
    // two stacked radials read as a genuine light source, not a tinted haze.
    canvas.drawCircle(
      c,
      r * 0.46,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _c(0xFFF3CE, (0x6E + 0x24 * pulse).round().clamp(0, 255)),
            _c(0xFFD98A, 0x38),
            _c(0xFFD98A, 0x00),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r * 0.46))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _c(0xFFDf9A, (0x46 + 0x1A * pulse).round().clamp(0, 255)),
            _c(0xF6A83C, 0x24),
            _c(0xF6A83C, 0x00),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // Anamorphic bloom streak — a cinematic "bright source" cue.
    final w = size.width * 1.2;
    canvas.drawRect(
      Rect.fromCenter(center: c, width: w, height: 2.6),
      Paint()
        ..shader = const LinearGradient(colors: [
          Color(0x00FFE9A8),
          Color(0x7AFFF2C8),
          Color(0x00FFE9A8),
        ]).createShader(Rect.fromCenter(center: c, width: w, height: 2.6))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8),
    );
  }

  @override
  bool shouldRepaint(_CoronaPainter old) => old.pulse != pulse;
}

/// Starfield (twinkling) + depth-shaded orbit ellipses + warm ambient glow.
class _BackdropPainter extends CustomPainter {
  final List<_Star> stars;
  final double time;
  _BackdropPainter(this.stars, this.time);

  @override
  void paint(Canvas canvas, Size size) {
    // Warm ambient wash around the system — ties the stage to the app's amber
    // mood instead of leaving the orrery on a cold void.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.95,
          colors: [_c(0xFFB45C, 0x14), _c(0xFFB45C, 0x05), _c(0xFFB45C, 0x00)],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Offset.zero & size),
    );

    // Twinkling starfield.
    final star = Paint();
    for (final s in stars) {
      final tw = 0.6 + 0.4 * math.sin(time * s.twinkle + s.phase);
      star.color = _c(0xFFFFFF, (s.base * tw * 255).round().clamp(0, 255));
      canvas.drawCircle(Offset(s.x, s.y), s.r, star);
    }

    // Orbit ellipses — brighter on the near (front/bottom) arc, dim at the back.
    for (final o in _orbits) {
      final rect = Rect.fromCenter(
          center: _center, width: o.rx * 2, height: o.ry * 2);
      canvas.drawArc(
        rect,
        math.pi, // back (top) half
        math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = _c(0xFFE0B2, 0x28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8),
      );
      canvas.drawArc(
        rect,
        0, // front (bottom) half
        math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = _c(0xFFE9C79A, 0x52)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0),
      );
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.time != time;
}

/// Amber primary action — "Add your first account".
class _Cta extends StatefulWidget {
  final VoidCallback onTap;
  const _Cta({required this.onTap});

  @override
  State<_Cta> createState() => _CtaState();
}

class _CtaState extends State<_Cta> {
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
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hover ? -1 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFD07A), Color(0xFFF6B23C)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _c(0xFFC465, _hover ? 0x8C : 0x6A),
                blurRadius: _hover ? 32 : 24,
                spreadRadius: -10,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add your first account',
                  style: sans(16,
                      weight: FontWeight.w700, color: const Color(0xFF0A0C12))),
              const SizedBox(width: 9),
              const Icon(Icons.arrow_forward,
                  size: 18, color: Color(0xFF0A0C12)),
            ],
          ),
        ),
      ),
    );
  }
}
