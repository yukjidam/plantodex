import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';
import '../theme/rarity.dart';
import '../repositories/plant_repository.dart';

// Note: kept the class/file name as-is so router references (e.g. '/catch')
// don't break. Rename CatchSuccessScreen -> PickSuccessScreen (and update
// your router) if you'd like the rename to go all the way through.
class CatchSuccessScreen extends StatefulWidget {
  const CatchSuccessScreen({super.key, this.result});

  /// The identified plant passed via `context.push('/catch', extra: result)`.
  /// Nullable so the route still renders gracefully if extra is missing.
  final PlantResult? result;

  @override
  State<CatchSuccessScreen> createState() => _CatchSuccessScreenState();
}

class _CatchSuccessScreenState extends State<CatchSuccessScreen>
    with TickerProviderStateMixin {
  // Pot settle animation (a little bounce as the pot "lands")
  late final AnimationController _potCtrl;
  late final Animation<double> _potScale;
  late final Animation<double> _potBounce;

  // Sprout grow-up animation (plays after pot settles)
  late final AnimationController _sproutCtrl;
  late final Animation<double> _stemGrow;
  late final Animation<double> _leafGrow;
  late final Animation<double> _leafOpacity;

  // Gentle float loop
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatY;

  // Sparkle particles
  late final AnimationController _particleCtrl;

  @override
  void initState() {
    super.initState();

    // 1. Pot drops/settles in
    _potCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _potScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _potCtrl, curve: Curves.easeOutBack),
    );
    _potBounce = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _potCtrl, curve: Curves.elasticOut),
    );

    // 2. Sprout grows up out of the soil after the pot settles
    _sproutCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _stemGrow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _sproutCtrl,
          curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic)),
    );
    _leafGrow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _sproutCtrl,
          curve: const Interval(0.45, 1.0, curve: Curves.elasticOut)),
    );
    _leafOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _sproutCtrl,
          curve: const Interval(0.4, 0.7, curve: Curves.easeIn)),
    );

    // 3. Float loop
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _floatY = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    // 4. Sparkle particles
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Chain: pot settles → sprout grows + sparkles
    _potCtrl.forward().then((_) {
      _sproutCtrl.forward();
      _particleCtrl.forward();
    });
  }

  @override
  void dispose() {
    _potCtrl.dispose();
    _sproutCtrl.dispose();
    _floatCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Rarity _rarityFromConfidence(int pct) {
    if (pct >= 95) return Rarity.legendary;
    if (pct >= 80) return Rarity.epic;
    if (pct >= 60) return Rarity.rare;
    return Rarity.common;
  }

  static int _xpForRarity(Rarity r) => switch (r) {
        Rarity.common => 40,
        Rarity.rare => 120,
        Rarity.epic => 200,
        Rarity.legendary => 350,
      };

  @override
  Widget build(BuildContext context) {
    // ── Derive display values from result (with safe fallbacks) ────────────
    final id = widget.result?.identification;
    final commonName = id?.commonName ?? 'Unknown Plant';
    final scientificName = id?.scientificName ?? '';
    final rarity = _rarityFromConfidence(id?.confidencePercent ?? 0);
    final xp = _xpForRarity(rarity);

    return Scaffold(
      backgroundColor: green900,
      body: Stack(
        children: [
          // Soft radial glow
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 0.75,
                colors: [green700.withOpacity(0.18), Colors.transparent],
              ),
            ),
          ),

          // Sparkle particles
          AnimatedBuilder(
            animation: _particleCtrl,
            builder: (context, _) => CustomPaint(
              painter: _SparkleParticlePainter(_particleCtrl.value),
              child: const SizedBox.expand(),
            ),
          ),

          // Main content
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Pot with sprout grow animation
                  AnimatedBuilder(
                    animation:
                        Listenable.merge([_potCtrl, _sproutCtrl, _floatCtrl]),
                    builder: (context, _) {
                      return Transform.translate(
                        offset: Offset(0, _floatY.value),
                        child: Transform.scale(
                          scale: _potScale.value,
                          child: SizedBox(
                            width: 140,
                            height: 170,
                            child: Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                // Sprout growing up out of the soil
                                Positioned(
                                  bottom: 58,
                                  child: Opacity(
                                    opacity: _leafOpacity.value,
                                    child: _Sprout(
                                      stemGrow: _stemGrow.value,
                                      leafGrow: _leafGrow.value,
                                    ),
                                  ),
                                ),
                                // Pot (drawn on top so soil line hides stem base)
                                _Pot(bounce: _potBounce.value),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  Text(
                    'You picked a',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    commonName,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (scientificName.isNotEmpty)
                    Text(
                      scientificName,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.35),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Rarity label
                  Text(
                    rarity.label.toUpperCase(),
                    style: GoogleFonts.spaceMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: rarity.color,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Rarity dots — filled count driven by rarity.dots
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                        5,
                        (i) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: i < rarity.dots
                                      ? rarity.color
                                      : Colors.white.withOpacity(0.15),
                                ),
                              ),
                            )),
                  ),
                  const SizedBox(height: 24),

                  // XP badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                    decoration: BoxDecoration(
                      color: rarity.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: rarity.color.withOpacity(0.35)),
                    ),
                    child: Text(
                      '+$xp XP earned',
                      style: GoogleFonts.spaceMono(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: rarity.color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // View in Garden button
                  SizedBox(
                    width: 260,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => context.go('/dex'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: green300,
                        side: BorderSide(
                            color: green600.withOpacity(0.4), width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'View in Garden →',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: green300,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pot ────────────────────────────────────────────────────────────────────

class _Pot extends StatelessWidget {
  const _Pot({required this.bounce});
  final double bounce;

  @override
  Widget build(BuildContext context) {
    // tiny squash-and-stretch as it "settles"
    final squash = 1.0 - (math.sin(bounce * math.pi) * 0.04);
    return Transform.scale(
      scaleX: 1 / squash,
      scaleY: squash,
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: 100,
        height: 78,
        child: CustomPaint(painter: _PotPainter()),
      ),
    );
  }
}

class _PotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const terracotta = Color(0xFFC97A4A);
    const terracottaDark = Color(0xFFA85F36);
    const soilColor = Color(0xFF4A3324);
    const soilHighlight = Color(0xFF5E4530);
    const rimColor = Color(0xFFE0935E);

    final w = size.width;
    final h = size.height;

    // Pot body — trapezoid, narrower at the bottom
    final bodyPath = Path()
      ..moveTo(w * 0.08, h * 0.28)
      ..lineTo(w * 0.92, h * 0.28)
      ..lineTo(w * 0.78, h)
      ..lineTo(w * 0.22, h)
      ..close();

    final bodyPaint = Paint()..color = terracotta;
    canvas.drawPath(bodyPath, bodyPaint);

    // Shading on the right side of the pot
    final shadePath = Path()
      ..moveTo(w * 0.55, h * 0.28)
      ..lineTo(w * 0.92, h * 0.28)
      ..lineTo(w * 0.78, h)
      ..lineTo(w * 0.55, h)
      ..close();
    canvas.drawPath(
        shadePath, Paint()..color = terracottaDark.withOpacity(0.55));

    // Rim
    final rimRect = Rect.fromLTWH(0, h * 0.18, w, h * 0.16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rimRect, const Radius.circular(6)),
      Paint()..color = rimColor,
    );

    // Soil (ellipse at top of pot, inside the rim)
    final soilRect = Rect.fromLTWH(w * 0.14, h * 0.20, w * 0.72, h * 0.16);
    canvas.drawOval(soilRect, Paint()..color = soilColor);
    canvas.drawOval(
      Rect.fromLTWH(w * 0.14, h * 0.205, w * 0.72, h * 0.1),
      Paint()..color = soilHighlight.withOpacity(0.6),
    );

    // A couple of little soil crumbs for texture
    final crumbPaint = Paint()..color = soilHighlight;
    canvas.drawCircle(Offset(w * 0.32, h * 0.27), 1.6, crumbPaint);
    canvas.drawCircle(Offset(w * 0.6, h * 0.29), 1.4, crumbPaint);
    canvas.drawCircle(Offset(w * 0.48, h * 0.25), 1.2, crumbPaint);
  }

  @override
  bool shouldRepaint(_PotPainter old) => false;
}

// ── Sprout that grows up out of the soil ───────────────────────────────────

class _Sprout extends StatelessWidget {
  const _Sprout({required this.stemGrow, required this.leafGrow});
  final double stemGrow; // 0 -> 1, how tall the stem is
  final double leafGrow; // 0 -> 1, how unfurled the leaves are

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 90,
      child: CustomPaint(
        painter: _SproutPainter(stemGrow: stemGrow, leafGrow: leafGrow),
      ),
    );
  }
}

class _SproutPainter extends CustomPainter {
  _SproutPainter({required this.stemGrow, required this.leafGrow});
  final double stemGrow;
  final double leafGrow;

  @override
  void paint(Canvas canvas, Size size) {
    final stemPaint = Paint()
      ..color = green400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final baseY = size.height; // stem starts at the soil line
    final topY = size.height - (size.height * 0.75 * stemGrow);
    final midX = size.width / 2;

    // Stem grows upward
    canvas.drawLine(Offset(midX, baseY), Offset(midX, topY), stemPaint);

    if (leafGrow <= 0) return;

    // Leaves unfurl from the top of the stem, scaled by leafGrow
    canvas.save();
    canvas.translate(midX, topY);
    canvas.scale(leafGrow);

    // Left leaf
    final leftLeaf = Paint()
      ..color = green500
      ..style = PaintingStyle.fill;
    final leftPath = Path()
      ..moveTo(0, 8)
      ..quadraticBezierTo(
          -size.width * 0.42, -2, -size.width * 0.36, -size.height * 0.22)
      ..quadraticBezierTo(-size.width * 0.12, -size.height * 0.04, 0, 8)
      ..close();
    canvas.drawPath(leftPath, leftLeaf);

    // Right leaf
    final rightLeaf = Paint()
      ..color = green400
      ..style = PaintingStyle.fill;
    final rightPath = Path()
      ..moveTo(0, 2)
      ..quadraticBezierTo(size.width * 0.46, -size.height * 0.1,
          size.width * 0.4, -size.height * 0.3)
      ..quadraticBezierTo(size.width * 0.14, -size.height * 0.1, 0, 2)
      ..close();
    canvas.drawPath(rightPath, rightLeaf);

    // Top bud
    final budPaint = Paint()
      ..color = green300
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(0, -8), 6.5, budPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SproutPainter old) =>
      old.stemGrow != stemGrow || old.leafGrow != leafGrow;
}

// ── Sparkle particles celebrating the new sprout ────────────────────────────

class _SparkleParticlePainter extends CustomPainter {
  _SparkleParticlePainter(this.progress);
  final double progress;

  static final _particles = List.generate(10, (i) {
    final rng = math.Random(i * 42);
    return (
      angle: rng.nextDouble() * math.pi * 2,
      speed: 0.4 + rng.nextDouble() * 0.6,
      size: 2.5 + rng.nextDouble() * 3.5,
      startDelay: rng.nextDouble() * 0.3,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.38;

    for (final p in _particles) {
      final t =
          ((progress - p.startDelay) / (1 - p.startDelay)).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final dist = t * p.speed * 90;
      final x = cx + math.cos(p.angle) * dist;
      final y = cy + math.sin(p.angle) * dist - t * 30;
      final opacity = (1 - t).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = green300.withOpacity(opacity * 0.8)
        ..style = PaintingStyle.fill;

      // Draw a tiny 4-point sparkle/star
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * math.pi);
      final s = p.size;
      final star = Path()
        ..moveTo(0, -s)
        ..quadraticBezierTo(s * 0.2, -s * 0.2, s, 0)
        ..quadraticBezierTo(s * 0.2, s * 0.2, 0, s)
        ..quadraticBezierTo(-s * 0.2, s * 0.2, -s, 0)
        ..quadraticBezierTo(-s * 0.2, -s * 0.2, 0, -s)
        ..close();
      canvas.drawPath(star, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SparkleParticlePainter old) => old.progress != progress;
}
