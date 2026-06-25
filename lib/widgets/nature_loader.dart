import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// A cute, fully code-drawn "growing sprout" loader with a little face
/// and blooming petals.
///
/// No image assets required — everything is painted with Flutter shapes
/// and animated with a single ticker. Used on scanning / fetching screens
/// for a friendlier, nature-themed feel.
class NatureLoader extends StatefulWidget {
  const NatureLoader({super.key, this.size = 96});
  final double size;

  @override
  State<NatureLoader> createState() => _NatureLoaderState();
}

class _NatureLoaderState extends State<NatureLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return CustomPaint(
            painter: _SproutPainter(progress: _ctrl.value),
          );
        },
      ),
    );
  }
}

class _SproutPainter extends CustomPainter {
  _SproutPainter({required this.progress});

  /// 0.0 → 1.0, looping continuously.
  final double progress;

  // Blink happens in a short window near the end of each loop.
  bool get _isBlinking => progress > 0.92 && progress < 0.97;

  /// Petals are always fully open — no bloom animation.
  double get _petalBloom => 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.80);
    // Gentle pendulum swing: full left-right sway using a smooth sine
    final swing = sin(progress * 2 * pi) * 0.18; // radians, ±~10°

    canvas.save();
    // Pivot at the base of the stem so it swings naturally
    canvas.translate(center.dx, center.dy);
    canvas.rotate(swing);
    canvas.translate(-center.dx, -center.dy);

    _drawShadow(canvas, center, size);
    _drawStem(canvas, center, size);

    final headCenter = Offset(center.dx, center.dy - size.height * 0.42);

    _drawLeaf(
      canvas,
      origin: Offset(center.dx, center.dy - size.height * 0.20),
      angle: -0.9 + sin(progress * 2 * pi) * 0.18,
      length: size.width * 0.30,
      flip: false,
    );
    _drawLeaf(
      canvas,
      origin: Offset(center.dx, center.dy - size.height * 0.27),
      angle: 0.9 + sin(progress * 2 * pi + pi) * 0.18,
      length: size.width * 0.27,
      flip: true,
    );

    // Petals are drawn behind the face so the head sits on top.
    _drawPetals(canvas, headCenter, size);
    _drawFace(canvas, headCenter, size);
    _drawSparkles(canvas, center, size);
    _drawButterfly(canvas, center, size);

    canvas.restore();
  }

  // ── Petals ──────────────────────────────────────────────────────────────────

  /// Six petals arranged radially around the sprout head.
  /// They bloom open (scale + fade in) and close back down each loop.
  void _drawPetals(Canvas canvas, Offset headCenter, Size size) {
    final bloom = _petalBloom;
    if (bloom <= 0) return;

    final r = size.width * 0.135; // head radius
    const numPetals = 6;
    final petalLength = r * 1.7; // was 1.1 — bigger petals
    final petalWidth = r * 0.70; // was 0.48 — wider too
    // Orbit distance: centre of each petal sits just outside the head.
    final orbit = r * 1.25; // was 1.05 — pushed out to match bigger size

    // Gentle wobble — petals sway slightly as the plant bobs.
    final wobble = sin(progress * 2 * pi) * 0.12;

    // Petal colour pairs: outer fill, inner highlight.
    const outerColors = [
      Color(0xFFFF8FAB),
      Color(0xFFFFB3C6),
      Color(0xFFFFC8DD),
      Color(0xFFFF85A1),
      Color(0xFFFFA3B5),
      Color(0xFFFFCCD5),
    ];
    const innerColors = [
      Color(0xFFFFF0F3),
      Color(0xFFFFE4EC),
      Color(0xFFFFD6E5),
      Color(0xFFFFECF0),
      Color(0xFFFFE8F0),
      Color(0xFFFFF5F7),
    ];

    for (int i = 0; i < numPetals; i++) {
      final baseAngle = (i / numPetals) * 2 * pi - pi / 2;
      final angle = baseAngle + wobble;

      // Petal centre along the orbit.
      final px = headCenter.dx + cos(angle) * orbit;
      final py = headCenter.dy + sin(angle) * orbit;

      canvas.save();
      canvas.translate(px, py);
      // Rotate so the petal always points outward from centre.
      canvas.rotate(angle + pi / 2);
      // Scale the petal in and out with bloom value.
      canvas.scale(bloom, bloom);

      // Outer petal (ellipse).
      final outerPaint = Paint()
        ..color = outerColors[i % outerColors.length].withOpacity(bloom)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: petalWidth,
          height: petalLength,
        ),
        outerPaint,
      );

      // Inner highlight (smaller ellipse, offset toward tip).
      final innerPaint = Paint()
        ..color = innerColors[i % innerColors.length].withOpacity(0.65 * bloom)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, petalLength * 0.18),
          width: petalWidth * 0.45,
          height: petalLength * 0.52,
        ),
        innerPaint,
      );

      canvas.restore();
    }

    // Yellow centre disc — visible only when petals are open.
    if (bloom > 0) {
      final centerPaint = Paint()
        ..color = const Color(0xFFFFD600).withOpacity(bloom)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(headCenter, r * 0.38, centerPaint);

      // Highlight on centre disc.
      canvas.drawCircle(
        headCenter.translate(-r * 0.10, -r * 0.10),
        r * 0.16,
        Paint()..color = const Color(0xFFFFF176).withOpacity(0.75 * bloom),
      );
    }
  }

  // ── Everything below is unchanged from the original ──────────────────────

  void _drawShadow(Canvas canvas, Offset center, Size size) {
    final shadowPaint = Paint()
      ..color = green600.withOpacity(0.10)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + 6),
        width: size.width * 0.5,
        height: 8,
      ),
      shadowPaint,
    );
  }

  void _drawStem(Canvas canvas, Offset center, Size size) {
    final stemPaint = Paint()
      ..color = green600
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final stemTop = Offset(center.dx, center.dy - size.height * 0.42);
    canvas.drawLine(center, stemTop, stemPaint);
  }

  void _drawLeaf(
    Canvas canvas, {
    required Offset origin,
    required double angle,
    required double length,
    required bool flip,
  }) {
    final path = Path();
    final dir = flip ? -1.0 : 1.0;

    final tip =
        origin + Offset(cos(angle) * length * dir, -sin(angle).abs() * length);
    final ctrl1 = origin + Offset(cos(angle) * length * 0.3 * dir, -4);
    final ctrl2 = tip + Offset(-cos(angle) * length * 0.25 * dir, 6);

    path.moveTo(origin.dx, origin.dy);
    path.quadraticBezierTo(ctrl1.dx, ctrl1.dy, tip.dx, tip.dy);
    path.quadraticBezierTo(ctrl2.dx, ctrl2.dy, origin.dx, origin.dy);
    path.close();

    final leafGradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [green600, green400],
      ).createShader(Rect.fromPoints(origin, tip))
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, leafGradient);

    final veinPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(origin, tip, veinPaint);
  }

  void _drawFace(Canvas canvas, Offset headCenter, Size size) {
    final r = size.width * 0.135;

    // ── Head (bud) ────────────────────────────────────────────────────
    final headGradient = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        radius: 1.1,
        colors: [green400, green600],
      ).createShader(Rect.fromCircle(center: headCenter, radius: r));
    canvas.drawCircle(headCenter, r, headGradient);

    // Soft top highlight
    canvas.drawCircle(
      headCenter.translate(-r * 0.3, -r * 0.35),
      r * 0.28,
      Paint()..color = Colors.white.withOpacity(0.22),
    );

    // ── Cheeks (blush) ───────────────────────────────────────────────
    final blushPaint = Paint()
      ..color = const Color(0xFFFFB3C1).withOpacity(0.55);
    canvas.drawCircle(
        headCenter + Offset(-r * 0.62, r * 0.18), r * 0.18, blushPaint);
    canvas.drawCircle(
        headCenter + Offset(r * 0.62, r * 0.18), r * 0.18, blushPaint);

    // ── Eyes ──────────────────────────────────────────────────────────
    final eyePaint = Paint()..color = const Color(0xFF2B3A2E);
    final eyeOffset = Offset(r * 0.34, -r * 0.06);

    if (_isBlinking) {
      final blinkPaint = Paint()
        ..color = const Color(0xFF2B3A2E)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        headCenter - eyeOffset + const Offset(-2.5, 0),
        headCenter - eyeOffset + const Offset(2.5, 0),
        blinkPaint,
      );
      canvas.drawLine(
        headCenter + eyeOffset + const Offset(-2.5, 0),
        headCenter + eyeOffset + const Offset(2.5, 0),
        blinkPaint,
      );
    } else {
      canvas.drawCircle(headCenter - eyeOffset, r * 0.10, eyePaint);
      canvas.drawCircle(headCenter + eyeOffset, r * 0.10, eyePaint);
      // tiny eye sparkle
      final sparkle = Paint()..color = Colors.white.withOpacity(0.9);
      canvas.drawCircle(
        headCenter - eyeOffset + Offset(-r * 0.03, -r * 0.03),
        r * 0.03,
        sparkle,
      );
      canvas.drawCircle(
        headCenter + eyeOffset + Offset(-r * 0.03, -r * 0.03),
        r * 0.03,
        sparkle,
      );
    }

    // ── Smile ─────────────────────────────────────────────────────────
    final smilePaint = Paint()
      ..color = const Color(0xFF2B3A2E)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final smileRect = Rect.fromCenter(
      center: headCenter + Offset(0, r * 0.22),
      width: r * 0.55,
      height: r * 0.45,
    );
    canvas.drawArc(smileRect, 0.25, pi - 0.5, false, smilePaint);
  }

  void _drawSparkles(Canvas canvas, Offset center, Size size) {
    final sparklePaint = Paint();
    for (int i = 0; i < 3; i++) {
      final t = (progress + i / 3) % 1.0;
      final dx = (i - 1) * size.width * 0.34;
      final dy = size.height * 0.55 - t * size.height * 0.55;
      final opacity = (sin(t * pi)).clamp(0.0, 1.0);
      sparklePaint.color = const Color(0xFFFFD66B).withOpacity(0.7 * opacity);
      _drawStar(
        canvas,
        Offset(center.dx + dx, center.dy + dy - size.height * 0.15),
        2.2 + opacity,
        sparklePaint,
      );
    }
  }

  void _drawStar(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 4; i++) {
      final angle = (pi / 2) * i;
      final outer = c + Offset(cos(angle) * r, sin(angle) * r);
      final midAngle = angle + pi / 4;
      final inner =
          c + Offset(cos(midAngle) * r * 0.35, sin(midAngle) * r * 0.35);
      if (i == 0) {
        path.moveTo(outer.dx, outer.dy);
      } else {
        path.lineTo(outer.dx, outer.dy);
      }
      path.lineTo(inner.dx, inner.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawButterfly(Canvas canvas, Offset center, Size size) {
    // Orbits loosely around the sprout, fluttering wings.
    final orbitT = progress * 2 * pi;
    final bx = center.dx + cos(orbitT) * size.width * 0.46;
    final by =
        center.dy - size.height * 0.55 + sin(orbitT * 1.3) * size.height * 0.10;
    final flap = sin(progress * 2 * pi * 6).abs(); // fast wing flutter

    final wingPaint = Paint()..color = const Color(0xFFFFA8C9).withOpacity(0.9);
    final wingPaint2 = Paint()
      ..color = const Color(0xFFFFD6E6).withOpacity(0.9);

    canvas.save();
    canvas.translate(bx, by);

    // Left wing
    canvas.save();
    canvas.scale(0.6 + flap * 0.4, 1);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-3, 0), width: 7, height: 5),
      wingPaint,
    );
    canvas.restore();

    // Right wing
    canvas.save();
    canvas.scale(0.6 + flap * 0.4, 1);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(3, 0), width: 7, height: 5),
      wingPaint2,
    );
    canvas.restore();

    // Body
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 2, height: 5),
      Paint()..color = const Color(0xFF8A5A44),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SproutPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
