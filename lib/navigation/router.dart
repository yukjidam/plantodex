import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/scan_screen.dart';
import '../screens/detect_result_screen.dart';
import '../screens/catch_success_screen.dart';
import '../screens/dex_screen.dart';
import '../screens/map_screen.dart';
import '../screens/profile_screen.dart';
import '../repositories/plant_repository.dart';
import '../widgets/bottom_nav_shell.dart';

final _shellKey = GlobalKey<NavigatorState>();
final _rootKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/scan',
  routes: [
    // Full-screen routes (no bottom nav)
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: '/detect',
      builder: (context, state) {
        // ScanScreen pushes: context.push('/detect', extra: file)
        final file = state.extra as File;
        return DetectResultScreen(photo: file);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: '/catch',
      builder: (context, state) => CatchSuccessScreen(
        args: state.extra,
      ),
    ),

    // Bottom-nav shell
    ShellRoute(
      navigatorKey: _shellKey,
      builder: (context, state, child) =>
          BottomNavShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: '/scan',
          builder: (context, state) => const ScanScreen(),
        ),
        GoRoute(
          path: '/dex',
          builder: (context, state) => const DexScreen(),
        ),
        GoRoute(
          path: '/map',
          builder: (context, state) => const MapScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),
  ],
);
