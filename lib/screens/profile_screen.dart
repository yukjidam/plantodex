import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.yard_outlined, size: 52, color: green200),
            const SizedBox(height: 14),
            Text('Your Profile',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                )),
            const SizedBox(height: 8),
            Text(
              'Trainer level, achievements, streaks,\nand your planting journey.',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                color: textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
