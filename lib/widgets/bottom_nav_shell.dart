import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';

const _tabs = [
  (path: '/scan',    icon: Icons.camera_alt_outlined,  label: 'Scan'),
  (path: '/dex',     icon: Icons.menu_book_outlined,    label: 'Dex'),
  (path: '/map',     icon: Icons.map_outlined,          label: 'Map'),
  (path: '/profile', icon: Icons.person_outline,        label: 'Profile'),
];

class BottomNavShell extends StatelessWidget {
  const BottomNavShell({
    super.key,
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  int get _currentIndex =>
      _tabs.indexWhere((t) => location.startsWith(t.path)).clamp(0, 3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
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
                    onTap: () => context.go(tab.path),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
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
