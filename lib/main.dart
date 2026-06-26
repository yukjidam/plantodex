import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';
import 'navigation/router.dart';
import 'theme/theme.dart';
import 'database/app_database.dart';
import 'providers/home_provider.dart';

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  await dotenv.load(fileName: '.env');
  await AppDatabase.getInstance();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  FlutterNativeSplash.remove();
  runApp(const PlantoDexApp());
}

class PlantoDexApp extends StatelessWidget {
  const PlantoDexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeProvider()),
      ],
      child: MaterialApp(
        title: 'PlantoDex',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const AnimatedSplashScreen(),
      ),
    );
  }
}

// ─── Leaf particle data ───────────────────────────────────────────────────────

class _Leaf {
  final double angle; // spawn direction (radians)
  final double distance; // how far from center it travels
  final double size;
  final double rotationSpeed; // radians per unit progress
  final double delay; // 0..1 — when in the timeline it starts
  final Color color;
  final int shape; // 0 = oval leaf, 1 = round leaf, 2 = small petal

  const _Leaf({
    required this.angle,
    required this.distance,
    required this.size,
    required this.rotationSpeed,
    required this.delay,
    required this.color,
    required this.shape,
  });
}

List<_Leaf> _buildLeaves(int count) {
  final rng = Random(42);
  final colors = [
    const Color(0xFF4CAF50),
    const Color(0xFF66BB6A),
    const Color(0xFF81C784),
    const Color(0xFF388E3C),
    const Color(0xFF2E7D32),
    const Color(0xFFA5D6A7),
    const Color(0xFF558B2F),
  ];
  return List.generate(count, (i) {
    return _Leaf(
      angle: rng.nextDouble() * 2 * pi,
      distance: 80 + rng.nextDouble() * 110,
      size: 8 + rng.nextDouble() * 14,
      rotationSpeed: (rng.nextBool() ? 1 : -1) * (1.5 + rng.nextDouble() * 3),
      delay: rng.nextDouble() * 0.4,
      color: colors[rng.nextInt(colors.length)],
      shape: rng.nextInt(3),
    );
  });
}

// ─── Painter ─────────────────────────────────────────────────────────────────

class _LeafPainter extends CustomPainter {
  final List<_Leaf> leaves;
  final double progress; // 0..1

  _LeafPainter(this.leaves, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    for (final leaf in leaves) {
      // Each leaf has its own delayed progress
      final t = ((progress - leaf.delay) / (1 - leaf.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;

      // Ease out cubic
      final eased = 1 - pow(1 - t, 3).toDouble();

      final dist = eased * leaf.distance;
      final dx = cos(leaf.angle) * dist;
      final dy = sin(leaf.angle) * dist;

      // Fade in fast, fade out near end
      final opacity = t < 0.2
          ? t / 0.2
          : t > 0.75
              ? (1 - t) / 0.25
              : 1.0;

      final paint = Paint()
        ..color = leaf.color.withOpacity(opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(cx + dx, cy + dy);
      canvas.rotate(leaf.rotationSpeed * eased * pi);

      _drawLeafShape(canvas, paint, leaf);

      canvas.restore();
    }
  }

  void _drawLeafShape(Canvas canvas, Paint paint, _Leaf leaf) {
    final s = leaf.size;
    switch (leaf.shape) {
      case 0: // pointed oval leaf
        final path = Path()
          ..moveTo(0, -s)
          ..cubicTo(s * 0.6, -s * 0.4, s * 0.6, s * 0.4, 0, s)
          ..cubicTo(-s * 0.6, s * 0.4, -s * 0.6, -s * 0.4, 0, -s)
          ..close();
        canvas.drawPath(path, paint);
        break;
      case 1: // round leaf
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset.zero, width: s * 1.1, height: s * 0.75),
          paint,
        );
        break;
      case 2: // tiny circle petal
        canvas.drawCircle(Offset.zero, s * 0.5, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(_LeafPainter old) => old.progress != progress;
}

// ─── Splash screen ────────────────────────────────────────────────────────────

class AnimatedSplashScreen extends StatefulWidget {
  const AnimatedSplashScreen({super.key});

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _mainCtrl;
  late final AnimationController _exitCtrl;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _titleFade;
  late final Animation<double> _titleSlide;
  late final Animation<double> _leafProgress;
  late final Animation<double> _exitFade;

  final _leaves = _buildLeaves(28);

  @override
  void initState() {
    super.initState();

    // Main animation: 2 seconds
    _mainCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Exit fade: 400ms
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Logo slams in with overshoot
    _logoScale = TweenSequence([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.15)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 35),
      TweenSequenceItem(
          tween: Tween(begin: 1.15, end: 0.95)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 15),
      TweenSequenceItem(
          tween: Tween(begin: 0.95, end: 1.0)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
    ]).animate(_mainCtrl);

    _logoFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _mainCtrl,
          curve: const Interval(0.0, 0.25, curve: Curves.easeIn)),
    );

    // Leaves burst out from 15%–85%
    _leafProgress = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _mainCtrl,
          curve: const Interval(0.15, 0.85, curve: Curves.easeInOut)),
    );

    // Title fades + slides up from 50%–80%
    _titleFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _mainCtrl,
          curve: const Interval(0.50, 0.80, curve: Curves.easeOut)),
    );
    _titleSlide = Tween(begin: 18.0, end: 0.0).animate(
      CurvedAnimation(
          parent: _mainCtrl,
          curve: const Interval(0.50, 0.80, curve: Curves.easeOut)),
    );

    _exitFade = Tween(begin: 1.0, end: 0.0).animate(_exitCtrl);

    _mainCtrl.forward().then((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
      await _exitCtrl.forward();
      if (mounted) _goToApp();
    });
  }

  void _goToApp() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const RouterScreen(),
        transitionDuration: Duration.zero,
      ),
    );
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _exitFade,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: AnimatedBuilder(
            animation: _mainCtrl,
            builder: (context, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Leaf particles
                  CustomPaint(
                    painter: _LeafPainter(_leaves, _leafProgress.value),
                    size: Size(
                      MediaQuery.of(context).size.width,
                      MediaQuery.of(context).size.height,
                    ),
                  ),

                  // Logo + title
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      FadeTransition(
                        opacity: _logoFade,
                        child: ScaleTransition(
                          scale: _logoScale,
                          child: Image.asset(
                            'assets/plantodex.png',
                            width: 130,
                            height: 130,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // App name
                      Opacity(
                        opacity: _titleFade.value,
                        child: Transform.translate(
                          offset: Offset(0, _titleSlide.value),
                          child: const Text(
                            'PlantoDex',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2E7D32),
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Router wrapper ───────────────────────────────────────────────────────────

class RouterScreen extends StatelessWidget {
  const RouterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PlantoDex',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: router,
    );
  }
}
