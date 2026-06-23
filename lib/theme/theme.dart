import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

ThemeData buildTheme() {
  final base = ThemeData.light(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: surface,
    colorScheme: const ColorScheme.light(
      primary: green600,
      onPrimary: surface,
      primaryContainer: green100,
      secondary: green400,
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: surface2,
      outline: borderColor,
    ),
    textTheme: GoogleFonts.spaceGroteskTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.spaceMono(
          fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary),
      labelSmall: GoogleFonts.spaceMono(
          fontSize: 10, fontWeight: FontWeight.w400, color: textMuted),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.spaceGrotesk(
          fontSize: 10,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? green600 : textMuted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(color: selected ? green600 : textMuted, size: 22);
      }),
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
  );
}
