import 'dart:math' as math;
import 'package:flutter/material.dart';

/// The "Around The World" brand mark — an orbit ring (one ellipse, rotated
/// -28°), a solid ball at the centre with a lightning bolt cut into it (the
/// app's Generate action), and a small "travelling" ball riding the ring.
/// Single-flat-colour variant, hand-painted with a `CustomPainter` (same
/// 100-unit design space and coordinates as `design/logo-kit/mark/logo-mark-
/// indigo.svg` / `logo-mark-white.svg` — no gradient, no external asset, no
/// new package dependency) for the spots in the app that show the brand
/// mark itself rather than the full gradient app-icon tile (`web/src/
/// components/Logo.tsx`'s `AppIcon` is the tile version, for comparison).
class BrandMark extends StatelessWidget {
  final double size;
  final Color markColor;
  final Color boltColor;
  final double ringOpacity;

  const BrandMark({
    super.key,
    this.size = 32,
    required this.markColor,
    required this.boltColor,
    this.ringOpacity = 0.62,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _BrandMarkPainter(markColor: markColor, boltColor: boltColor, ringOpacity: ringOpacity),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  final Color markColor;
  final Color boltColor;
  final double ringOpacity;

  _BrandMarkPainter({required this.markColor, required this.boltColor, required this.ringOpacity});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100;
    canvas.save();
    canvas.scale(scale);

    // Orbit ring: ellipse cx=50 cy=50 rx=44 ry=19, rotated -28°, stroke only.
    canvas.save();
    canvas.translate(50, 50);
    canvas.rotate(-28 * math.pi / 180);
    canvas.translate(-50, -50);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 50), width: 88, height: 38),
      Paint()
        ..color = markColor.withValues(alpha: ringOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.5,
    );
    canvas.restore();

    final ballPaint = Paint()..color = markColor;

    // Ball.
    canvas.drawCircle(const Offset(50, 50), 28, ballPaint);

    // Bolt: SVG path "M59 13L26 56h19l-4 31 33-44H54z", then
    // translate(50 50) scale(.56) translate(-50 -50) to centre/size it
    // inside the ball — straight-line segments only, no curves.
    final bolt = Path()
      ..moveTo(59, 13)
      ..lineTo(26, 56)
      ..lineTo(45, 56)
      ..lineTo(41, 87)
      ..lineTo(74, 43)
      ..lineTo(54, 43)
      ..close();
    canvas.save();
    canvas.translate(50, 50);
    canvas.scale(0.56);
    canvas.translate(-50, -50);
    canvas.drawPath(bolt, Paint()..color = boltColor);
    canvas.restore();

    // Travelling satellite ball, riding the ring.
    canvas.drawCircle(const Offset(88.85, 29.36), 9, ballPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BrandMarkPainter oldDelegate) =>
      oldDelegate.markColor != markColor ||
      oldDelegate.boltColor != boltColor ||
      oldDelegate.ringOpacity != ringOpacity;
}
