import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';

// Screens
import '../screens/home_screen.dart';
import '../screens/dex_screen.dart';
import '../screens/scan_screen.dart';
import '../screens/map_screen.dart';
import '../screens/profile_screen.dart';

class BottomNavShell extends StatefulWidget {
  const BottomNavShell({super.key});

  /// Switch to a tab from anywhere without go_router.
  /// Usage: BottomNavShell.switchTab(context, 1); // 0=Home 1=Dex 2=Scan 3=Map 4=Profile
  static void switchTab(BuildContext context, int index) {
    context.findAncestorStateOfType<_BottomNavShellState>()?.switchTab(index);
  }

  @override
  State<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends State<BottomNavShell> {
  int _currentIndex = 0;

  void switchTab(int index) {
    if (index != _currentIndex) {
      setState(() => _currentIndex = index);
    }
  }

  // All screens are kept alive inside an IndexedStack — they are never
  // destroyed when switching tabs. This is critical for ScanScreen: using
  // go_router's context.go() rebuilds the destination from scratch on every
  // tap, which disposes and reinitialises the CameraController repeatedly
  // until the OS camera hardware locks up ("Could not start camera").
  static const _screens = [
    HomeScreen(),
    DexScreen(),
    ScanScreen(),
    MapScreen(),
    ProfileScreen(),
  ];

  static const _tabs = [
    (icon: Icons.home_outlined, label: 'Home'),
    (icon: Icons.menu_book_outlined, label: 'Dex'),
    (icon: Icons.camera_alt_outlined, label: 'Scan'),
    (icon: Icons.map_outlined, label: 'Map'),
    (icon: Icons.person_outline, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: surface,
          border: Border(top: BorderSide(color: borderColor, width: 1)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 56,
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final tab = _tabs[i];
                final selected = i == _currentIndex;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => switchTab(i),
                    behavior: HitTestBehavior.opaque,
                    child: i == 2
                        // ── Centre Scan tab — raised camera button ──────────
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: selected ? green600 : green500,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: green600.withOpacity(0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  tab.icon,
                                  size: 22,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )
                        // ── Regular tabs ────────────────────────────────────
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                tab.icon,
                                size: 22,
                                color: selected ? green600 : textMuted,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                tab.label,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 10,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: selected ? green600 : textMuted,
                                ),
                              ),
                            ],
                          ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
