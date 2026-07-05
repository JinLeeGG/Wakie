# WakieAI Brand — Logo & Wordmark v2

Captured 2026-07-04 from the landing page (`apps/web/src/components/Hero.tsx`),
saved here so the Mac app can adopt the same design. Supersedes the v1 marks
(`logo-orbit.svg` concentric version, and the old "Wakie amber / AI white" rule).

## Assets

| File | What |
| --- | --- |
| `logo-orbit-glow.svg` | Orbit mark v2 — tilted ring + glowing amber core (dark bg) |
| `wordmark-wakie.svg` | "Wakie" wordmark, alternating letter colors (needs Instrument Sans) |

## Orbit mark (logo)

24×24 viewBox, transparent field, for dark backgrounds:

- **Ring:** ellipse rx `10.5` / ry `5`, rotated **−24°**, stroke `#ffffff` @ 55%, width `1.3`
- **Core:** circle r `4.4`, fill `#ffc465` (amber)
- **Glow:** duplicate core underneath, 50% opacity, gaussian blur ~`1.5` (SVG) / `3px` (CSS)

## Wordmark

**"Wakie"** — no "AI" suffix. Alternating letter colors:

| W | a | k | i | e |
| --- | --- | --- | --- | --- |
| amber | white | amber | white | amber |
| `#ffc465` | `#f3f4f7` | `#ffc465` | `#f3f4f7` | `#ffc465` |

- **Font:** Instrument Sans, weight **600 (semibold)**
- **Tracking:** tight, `-0.025em`
- **Colors:** amber = `T.amber` `#ffc465` · white = `T.t1` `#f3f4f7` (theme.dart tokens)

## Lockup (mark + wordmark)

- Mark height = **1.2×** wordmark font size
- Gap between mark and wordmark = **0.3×** font size
- Reference sizes on the landing page: nav = 17px text / 24px mark; hero = 0.3× headline

## Flutter snippets

```dart
// Wordmark — alternating amber/white (Instrument Sans is already bundled)
const amber = Color(0xFFFFC465);
const t1 = Color(0xFFF3F4F7);

Text.rich(TextSpan(
  style: TextStyle(
    fontFamily: 'InstrumentSans',
    fontWeight: FontWeight.w600,
    fontSize: 17,
    letterSpacing: 17 * -0.025,
  ),
  children: [
    TextSpan(text: 'W', style: TextStyle(color: amber)),
    TextSpan(text: 'a', style: TextStyle(color: t1)),
    TextSpan(text: 'k', style: TextStyle(color: amber)),
    TextSpan(text: 'i', style: TextStyle(color: t1)),
    TextSpan(text: 'e', style: TextStyle(color: amber)),
  ],
));
```

```dart
// Orbit mark — CustomPainter (no flutter_svg needed). size = square edge.
class OrbitMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24; // design space is 24×24
    final c = Offset(size.width / 2, size.height / 2);

    // glow under the core
    canvas.drawCircle(
      c,
      4.4 * s,
      Paint()
        ..color = const Color(0x80FFC465)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5 * s),
    );
    // core
    canvas.drawCircle(c, 4.4 * s, Paint()..color = const Color(0xFFFFC465));

    // tilted orbit ring
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-24 * math.pi / 180);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 21 * s, height: 10 * s),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3 * s
        ..color = const Color(0x8CFFFFFF), // white @ 55%
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```
