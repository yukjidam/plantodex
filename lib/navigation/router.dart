import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/detect_result_screen.dart';
import '../screens/catch_success_screen.dart';
import '../screens/plant_detail_screen.dart';
import '../models/caught_plant.dart';
import '../widgets/bottom_nav_shell.dart';
import '../screens/catch_success_args.dart';

final _rootKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/home',
  routes: [
    // ── Bottom-nav shell ─────────────────────────────────────────────────────
    // Single persistent route — IndexedStack inside handles tab switching.
    // All full-screen routes are nested here so go_router can push them
    // on top of the shell without destroying it.
    GoRoute(
      path: '/home',
      builder: (context, state) => const BottomNavShell(),
      routes: [
        GoRoute(
          parentNavigatorKey: _rootKey,
          path: 'detect',
          builder: (context, state) {
            final file = state.extra as File;
            return DetectResultScreen(photo: file);
          },
          routes: [
            GoRoute(
              parentNavigatorKey: _rootKey,
              path: 'catch',
              builder: (context, state) => CatchSuccessScreen(
                args: state.extra,
              ),
            ),
          ],
        ),
        GoRoute(
          parentNavigatorKey: _rootKey,
          path: 'dex/detail',
          builder: (context, state) {
            final plant = state.extra as CaughtPlant;
            return PlantDetailScreen(plant: plant);
          },
        ),
      ],
    ),
  ],
);
