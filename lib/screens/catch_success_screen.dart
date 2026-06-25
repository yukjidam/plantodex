import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';
import '../theme/rarity.dart';
import '../repositories/plant_repository.dart';
import 'catch_success_args.dart';

class CatchSuccessScreen extends StatefulWidget {
  const CatchSuccessScreen({super.key, this.args});

  /// Pass a [CatchSuccessArgs] via `context.push('/catch', extra: args)`.
  /// Accepts the old [PlantResult]-only extra for backwards compatibility.
  final Object? args;

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

  // Sparkle / ambient particles
  late final AnimationController _particleCtrl;

  // Legendary-only: golden rays rotating behind the pot
  late final AnimationController _rayCtrl;

  // Epic-only: shimmer pulse
  late final AnimationController _shimmerCtrl;

  // Rare-only: ripple rings expanding outward
  late final AnimationController _rippleCtrl;

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

    // 5. Legendary rays — slow rotation loop
    _rayCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();

    // 6. Epic shimmer pulse loop
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // 7. Rare ripple — repeating outward rings
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

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
    _rayCtrl.dispose();
    _shimmerCtrl.dispose();
    _rippleCtrl.dispose();
    super.dispose();
  }

  // ── Unpack args ────────────────────────────────────────────────────────────

  PlantResult? get _result {
    if (widget.args is CatchSuccessArgs)
      return (widget.args as CatchSuccessArgs).result;
    if (widget.args is PlantResult) return widget.args as PlantResult;
    return null;
  }

  Rarity get _rarity {
    if (widget.args is CatchSuccessArgs)
      return (widget.args as CatchSuccessArgs).rarity;
    // Fallback: derive from confidence (kept for backwards compat)
    final pct = _result?.identification.confidencePercent ?? 0;
    if (pct >= 95) return Rarity.legendary;
    if (pct >= 80) return Rarity.epic;
    if (pct >= 60) return Rarity.rare;
    return Rarity.common;
  }

  // ── Rarity-driven theme ────────────────────────────────────────────────────

  static int _xpForRarity(Rarity r) => switch (r) {
        Rarity.common => 40,
        Rarity.rare => 120,
        Rarity.epic => 200,
        Rarity.legendary => 350,
      };

  /// Background gradient colors per rarity.
  static List<Color> _bgGradient(Rarity r) => switch (r) {
        Rarity.common => [const Color(0xFF0D1F0D), const Color(0xFF0A1A10)],
        Rarity.rare => [const Color(0xFF0A1428), const Color(0xFF081020)],
        Rarity.epic => [const Color(0xFF18082E), const Color(0xFF100522)],
        Rarity.legendary => [const Color(0xFF1C1100), const Color(0xFF110900)],
      };

  /// Radial glow overlay color per rarity.
  static Color _glowColor(Rarity r) => switch (r) {
        Rarity.common => green700,
        Rarity.rare => blue,
        Rarity.epic => purple,
        Rarity.legendary => amber,
      };

  /// Headline copy per rarity — same voice as detect screen.
  static String _headline(Rarity r) => switch (r) {
        Rarity.common => 'You picked a',
        Rarity.rare => 'Rare find! You picked a',
        Rarity.epic => 'Incredible! You caught an',
        Rarity.legendary => '✨ Legendary discovery!',
      };

  /// Sub-label shown below the plant name.
  static String _subLabel(Rarity r) => switch (r) {
        Rarity.common => 'Added to your Dex.',
        Rarity.rare => 'Not many trainers have this one.',
        Rarity.epic => 'Only the sharpest eyes find these.',
        Rarity.legendary => 'One of the rarest plants on the planet.',
      };

  // ── Sprout color per rarity ────────────────────────────────────────────────

  static Color _stemColor(Rarity r) => switch (r) {
        Rarity.common => green400,
        Rarity.rare => blue,
        Rarity.epic => purple,
        Rarity.legendary => amber,
      };

  static Color _leafColor(Rarity r) => switch (r) {
        Rarity.common => green500,
        Rarity.rare => const Color(0xFF4A90D9),
        Rarity.epic => const Color(0xFF9B59E8),
        Rarity.legendary => const Color(0xFFE8A020),
      };

  static Color _budColor(Rarity r) => switch (r) {
        Rarity.common => green300,
        Rarity.rare => const Color(0xFF7AB8F5),
        Rarity.epic => const Color(0xFFBD8AF8),
        Rarity.legendary => const Color(0xFFFFD060),
      };

  @override
  Widget build(BuildContext context) {
    final id = _result?.identification;
    final commonName = id?.commonName ?? 'Unknown Plant';
    final scientificName = id?.scientificName ?? '';
    final rarity = _rarity;
    final xp = _xpForRarity(rarity);
    final bgColors = _bgGradient(rarity);
    final glowColor = _glowColor(rarity);

    return Scaffold(
      backgroundColor: Color(bgColors[0].value),
      body: Stack(
        children: [
          // ── Background gradient ──────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: bgColors,
              ),
            ),
          ),

          // ── Soft radial glow ────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 0.75,
                colors: [glowColor.withOpacity(0.18), Colors.transparent],
              ),
            ),
          ),

          // ── Legendary: rotating golden rays ─────────────────────────────
          if (rarity == Rarity.legendary)
            AnimatedBuilder(
              animation: _rayCtrl,
              builder: (_, __) => CustomPaint(
                painter: _RayPainter(_rayCtrl.value, amber),
                child: const SizedBox.expand(),
              ),
            ),

          // ── Epic: shimmer pulse rings ────────────────────────────────────
          if (rarity == Rarity.epic)
            AnimatedBuilder(
              animation: _shimmerCtrl,
              builder: (_, __) => CustomPaint(
                painter: _ShimmerRingPainter(_shimmerCtrl.value, purple),
                child: const SizedBox.expand(),
              ),
            ),

          // ── Rare: expanding ripple rings ────────────────────────────────
          if (rarity == Rarity.rare)
            AnimatedBuilder(
              animation: _rippleCtrl,
              builder: (_, __) => CustomPaint(
                painter: _RipplePainter(_rippleCtrl.value, blue),
                child: const SizedBox.expand(),
              ),
            ),

          // ── Sparkle particles (color matches rarity) ────────────────────
          AnimatedBuilder(
            animation: _particleCtrl,
            builder: (context, _) => CustomPaint(
              painter: _SparkleParticlePainter(
                _particleCtrl.value,
                rarity.color,
                count: rarity == Rarity.legendary
                    ? 18
                    : rarity == Rarity.epic
                        ? 14
                        : 10,
              ),
              child: const SizedBox.expand(),
            ),
          ),

          // ── Main content ─────────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Pot with rarity-tinted sprout ──────────────────────
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
                                      stemColor: _stemColor(rarity),
                                      leafColor: _leafColor(rarity),
                                      budColor: _budColor(rarity),
                                    ),
                                  ),
                                ),
                                // Pot on top so soil line hides stem base
                                _Pot(bounce: _potBounce.value),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // ── Headline ───────────────────────────────────────────
                  Text(
                    _headline(rarity),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: rarity == Rarity.legendary ? 16 : 14,
                      fontWeight: rarity == Rarity.legendary
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: rarity == Rarity.legendary
                          ? amber
                          : Colors.white.withOpacity(0.5),
                    ),
                  ),

                  // For legendary the headline is self-contained; plant name
                  // still appears right below in larger text.
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

                  // ── Rarity label ────────────────────────────────────────
                  Text(
                    rarity.label.toUpperCase(),
                    style: GoogleFonts.spaceMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: rarity.color,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Sub-label ────────────────────────────────────────────
                  Text(
                    _subLabel(rarity),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.40),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── Rarity dots ─────────────────────────────────────────
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

                  // ── XP badge ────────────────────────────────────────────
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

                  // ── View in Garden button ────────────────────────────────
                  SizedBox(
                    width: 260,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => context.go('/dex'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: rarity.color,
                        side: BorderSide(
                            color: rarity.color.withOpacity(0.4), width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'View in Garden →',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: rarity.color,
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

    final bodyPath = Path()
      ..moveTo(w * 0.08, h * 0.28)
      ..lineTo(w * 0.92, h * 0.28)
      ..lineTo(w * 0.78, h)
      ..lineTo(w * 0.22, h)
      ..close();
    canvas.drawPath(bodyPath, Paint()..color = terracotta);

    final shadePath = Path()
      ..moveTo(w * 0.55, h * 0.28)
      ..lineTo(w * 0.92, h * 0.28)
      ..lineTo(w * 0.78, h)
      ..lineTo(w * 0.55, h)
      ..close();
    canvas.drawPath(
        shadePath, Paint()..color = terracottaDark.withOpacity(0.55));

    final rimRect = Rect.fromLTWH(0, h * 0.18, w, h * 0.16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rimRect, const Radius.circular(6)),
      Paint()..color = rimColor,
    );

    final soilRect = Rect.fromLTWH(w * 0.14, h * 0.20, w * 0.72, h * 0.16);
    canvas.drawOval(soilRect, Paint()..color = soilColor);
    canvas.drawOval(
      Rect.fromLTWH(w * 0.14, h * 0.205, w * 0.72, h * 0.1),
      Paint()..color = soilHighlight.withOpacity(0.6),
    );

    final crumbPaint = Paint()..color = soilHighlight;
    canvas.drawCircle(Offset(w * 0.32, h * 0.27), 1.6, crumbPaint);
    canvas.drawCircle(Offset(w * 0.6, h * 0.29), 1.4, crumbPaint);
    canvas.drawCircle(Offset(w * 0.48, h * 0.25), 1.2, crumbPaint);
  }

  @override
  bool shouldRepaint(_PotPainter old) => false;
}

// ── Sprout ─────────────────────────────────────────────────────────────────

class _Sprout extends StatelessWidget {
  const _Sprout({
    required this.stemGrow,
    required this.leafGrow,
    required this.stemColor,
    required this.leafColor,
    required this.budColor,
  });
  final double stemGrow;
  final double leafGrow;
  final Color stemColor;
  final Color leafColor;
  final Color budColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 90,
      child: CustomPaint(
        painter: _SproutPainter(
          stemGrow: stemGrow,
          leafGrow: leafGrow,
          stemColor: stemColor,
          leafColor: leafColor,
          budColor: budColor,
        ),
      ),
    );
  }
}

class _SproutPainter extends CustomPainter {
  _SproutPainter({
    required this.stemGrow,
    required this.leafGrow,
    required this.stemColor,
    required this.leafColor,
    required this.budColor,
  });

  final double stemGrow;
  final double leafGrow;
  final Color stemColor;
  final Color leafColor;
  final Color budColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stemPaint = Paint()
      ..color = stemColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final baseY = size.height;
    final topY = size.height - (size.height * 0.75 * stemGrow);
    final midX = size.width / 2;

    canvas.drawLine(Offset(midX, baseY), Offset(midX, topY), stemPaint);

    if (leafGrow <= 0) return;

    canvas.save();
    canvas.translate(midX, topY);
    canvas.scale(leafGrow);

    final darkLeaf = Paint()
      ..color = leafColor.withOpacity(0.85)
      ..style = PaintingStyle.fill;
    final leftPath = Path()
      ..moveTo(0, 8)
      ..quadraticBezierTo(
          -size.width * 0.42, -2, -size.width * 0.36, -size.height * 0.22)
      ..quadraticBezierTo(-size.width * 0.12, -size.height * 0.04, 0, 8)
      ..close();
    canvas.drawPath(leftPath, darkLeaf);

    final lightLeaf = Paint()
      ..color = leafColor
      ..style = PaintingStyle.fill;
    final rightPath = Path()
      ..moveTo(0, 2)
      ..quadraticBezierTo(size.width * 0.46, -size.height * 0.1,
          size.width * 0.4, -size.height * 0.3)
      ..quadraticBezierTo(size.width * 0.14, -size.height * 0.1, 0, 2)
      ..close();
    canvas.drawPath(rightPath, lightLeaf);

    canvas.drawCircle(
        const Offset(0, -8),
        6.5,
        Paint()
          ..color = budColor
          ..style = PaintingStyle.fill);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SproutPainter old) =>
      old.stemGrow != stemGrow || old.leafGrow != leafGrow;
}

// ── Sparkle particles (rarity-tinted) ──────────────────────────────────────

class _SparkleParticlePainter extends CustomPainter {
  _SparkleParticlePainter(this.progress, this.color, {this.count = 10});

  final double progress;
  final Color color;
  final int count;

  late final List<
          ({double angle, double speed, double size, double startDelay})>
      _particles = List.generate(count, (i) {
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
        ..color = color.withOpacity(opacity * 0.85)
        ..style = PaintingStyle.fill;

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
  bool shouldRepaint(_SparkleParticlePainter old) =>
      old.progress != progress || old.color != color;
}

// ── Legendary: rotating golden rays ─────────────────────────────────────────

class _RayPainter extends CustomPainter {
  _RayPainter(this.progress, this.color);
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.38;
    const rayCount = 12;
    const halfAngle = math.pi / rayCount / 1.6;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(progress * math.pi * 2);

    final paint = Paint()
      ..color = color.withOpacity(0.07)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < rayCount; i++) {
      final angle = (i / rayCount) * math.pi * 2;
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(math.cos(angle - halfAngle) * 300,
            math.sin(angle - halfAngle) * 300)
        ..lineTo(math.cos(angle + halfAngle) * 300,
            math.sin(angle + halfAngle) * 300)
        ..close();
      canvas.drawPath(path, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_RayPainter old) => old.progress != progress;
}

// ── Epic: shimmer ring pulse ──────────────────────────────────────────────────

class _ShimmerRingPainter extends CustomPainter {
  _ShimmerRingPainter(this.progress, this.color);
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.38;
    // Two staggered rings
    for (int i = 0; i < 2; i++) {
      final t = ((progress + i * 0.5) % 1.0);
      final radius = 60 + t * 120;
      final opacity = (1 - t) * 0.14;
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..color = color.withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }
  }

  @override
  bool shouldRepaint(_ShimmerRingPainter old) => old.progress != progress;
}

// ── Rare: ripple rings ────────────────────────────────────────────────────────

class _RipplePainter extends CustomPainter {
  _RipplePainter(this.progress, this.color);
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.38;
    // Three staggered ripple rings
    for (int i = 0; i < 3; i++) {
      final t = ((progress + i / 3.0) % 1.0);
      final radius = 40 + t * 160;
      final opacity = (1 - t) * 0.18;
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..color = color.withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.progress != progress;
}
