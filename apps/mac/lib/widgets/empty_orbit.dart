import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models.dart';
import '../theme.dart';

/// The empty-dashboard hero (docs/design/dashboard-empty.html): a tilted orrery
/// with the WakieAI star at the center and the three provider "planets" gliding
/// along elliptical orbits — nothing in orbit yet — over a "Add your first
/// account" call to action. Planets pass behind the star at the back of their
/// orbit and swell to the front, and the whole system pauses on hover so a
/// planet can be read and clicked.
class EmptyOrbit extends StatefulWidget {
  final VoidCallback onAdd;
  const EmptyOrbit({super.key, required this.onAdd});

  @override
  State<EmptyOrbit> createState() => _EmptyOrbitState();
}

// Design canvas for the orrery; the whole thing scales down to fit its slot.
const double _stageW = 520;
const double _stageH = 280;
const double _sphere = 40; // planet diameter at 1× depth
const double _sun = 66;

class _Orbit {
  final Provider provider;
  final String label;
  final double rx, ry, dur, phase;
  final List<Color> sphere; // radial gradient, light → mid → shadow
  final Color tint; // icon color on the sphere
  const _Orbit(this.provider, this.label, this.rx, this.ry, this.dur,
      this.phase, this.sphere, this.tint);
}

const _orbits = <_Orbit>[
  _Orbit(Provider.anti, 'Antigravity', 112, 38, 40, 0.15,
      [Color(0xFFD2DDFF), Color(0xFF8EA9F5), Color(0xFF485EC3)], Color(0xFFFFFFFF)),
  _Orbit(Provider.claude, 'Claude', 165, 56, 58, 0.55,
      [Color(0xFFF4BDA3), Color(0xFFD9835F), Color(0xFF8C4632)], Color(0xFFFFFFFF)),
  _Orbit(Provider.codex, 'Codex', 218, 75, 78, 0.83,
      [Color(0xFFF6F8FB), Color(0xFFC4C9D3), Color(0xFF6A6F78)], Color(0xFF2A2D35)),
];

class _EmptyOrbitState extends State<EmptyOrbit>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _clock = ValueNotifier(0);
  double _time = 0;
  Duration _last = Duration.zero;
  bool _paused = false;
  int? _hover; // hovered planet index → its name chip + system frozen

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = (elapsed - _last).inMicroseconds / 1e6;
      _last = elapsed;
      // Own accumulator (not raw elapsed) so a hover can freeze time cleanly and
      // resume without the planets jumping forward.
      if (!_paused) {
        _time += dt;
        _clock.value = _time;
      }
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  void _setPaused(bool v) {
    if (_paused != v) setState(() => _paused = v);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: MouseRegion(
              onEnter: (_) => _setPaused(true),
              onExit: (_) => _setPaused(false),
              child: SizedBox(
                width: _stageW,
                height: _stageH,
                child: AnimatedBuilder(
                  animation: _clock,
                  builder: (context, _) => _buildStage(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 26),
          _Cta(onTap: widget.onAdd),
        ],
      ),
    );
  }

  Widget _buildStage() {
    const center = Offset(_stageW / 2, _stageH / 2);
    final glowPulse = 0.5 + 0.5 * math.sin(_time / 6 * 2 * math.pi);

    final back = <Widget>[];
    final front = <Widget>[];
    final chips = <Widget>[];

    for (var i = 0; i < _orbits.length; i++) {
      final o = _orbits[i];
      final angle = 2 * math.pi * (_time / o.dur + o.phase);
      final pos = Offset(
        center.dx + o.rx * math.cos(angle),
        center.dy + o.ry * math.sin(angle),
      );
      final depth = math.sin(angle); // -1 far/behind … +1 near/front
      final f = (depth + 1) / 2;
      final scale = 0.8 + 0.35 * f;
      final opacity = 0.74 + 0.26 * f;

      final planet = _planet(o, i, pos, scale, opacity);
      (depth < 0 ? back : front).add(planet);

      if (_hover == i) {
        chips.add(_nameChip(o.label, pos, scale));
      }
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: CustomPaint(painter: _OrbitsPainter())),
        _sunGlow(center, glowPulse),
        ...back,
        _sunMark(center),
        ...front,
        ...chips,
      ],
    );
  }

  Widget _planet(_Orbit o, int i, Offset pos, double scale, double opacity) {
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
              child: _Sphere(orbit: o, lit: _hover == i),
            ),
          ),
        ),
      ),
    );
  }

  Widget _nameChip(String label, Offset pos, double scale) {
    return Positioned(
      left: pos.dx - 60,
      top: pos.dy + _sphere / 2 * scale + 6,
      width: 120,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xD10A0C12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: T.hair),
          ),
          child: Text(label,
              style: mono(10, color: T.t1, letterSpacing: 0.4)),
        ),
      ),
    );
  }

  Widget _sunGlow(Offset center, double pulse) {
    final size = _sun * (2.6 + 0.12 * pulse);
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      width: size,
      height: size,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              Color.fromRGBO(255, 190, 95, 0.13 + 0.10 * pulse),
              const Color(0x00FFBE5F),
            ], stops: const [0.0, 0.72]),
          ),
        ),
      ),
    );
  }

  Widget _sunMark(Offset center) {
    return Positioned(
      left: center.dx - _sun / 2,
      top: center.dy - _sun / 2,
      width: _sun,
      height: _sun,
      child: IgnorePointer(
        child: CustomPaint(painter: _SunPainter()),
      ),
    );
  }
}

/// Solid provider sphere: a shaded orb with the brand glyph, a drop shadow, and
/// an amber focus ring when hovered.
class _Sphere extends StatelessWidget {
  final _Orbit orbit;
  final bool lit;
  const _Sphere({required this.orbit, required this.lit});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.34, -0.46),
          radius: 0.95,
          colors: orbit.sphere,
          stops: const [0.0, 0.52, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x99000000),
            blurRadius: lit ? 24 : 15,
            spreadRadius: -5,
            offset: const Offset(0, 7),
          ),
          if (lit)
            const BoxShadow(
                color: Color(0x66FFC465), blurRadius: 0, spreadRadius: 3),
        ],
      ),
      child: Center(
        child: SvgPicture.asset(
          orbit.provider.icon,
          width: 21,
          height: 21,
          colorFilter: ColorFilter.mode(orbit.tint, BlendMode.srcIn),
        ),
      ),
    );
  }
}

/// The three faint HUD orbit ellipses.
class _OrbitsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const center = Offset(_stageW / 2, _stageH / 2);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x38FFE0B2) // rgba(255,224,178,.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
    for (final o in _orbits) {
      canvas.drawOval(
        Rect.fromCenter(center: center, width: o.rx * 2, height: o.ry * 2),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_OrbitsPainter old) => false;
}

/// The WakieAI star: white ring + amber radial core.
class _SunPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final ringR = size.width * 0.40;
    final coreR = size.width * 0.30;

    canvas.drawCircle(
      c,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.058
        ..color = const Color(0xFFFFFFFF)
        ..isAntiAlias = true,
    );
    canvas.drawCircle(
      c,
      coreR,
      Paint()
        ..isAntiAlias = true
        ..shader = const RadialGradient(
          center: Alignment(-0.24, -0.4),
          radius: 0.72,
          colors: [Color(0xFFFFE1A3), Color(0xFFF6B23C), Color(0xFFD1892A)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: coreR)),
    );
  }

  @override
  bool shouldRepaint(_SunPainter old) => false;
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
            color: T.amber,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(255, 196, 101, _hover ? 0.55 : 0.42),
                blurRadius: _hover ? 30 : 24,
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
