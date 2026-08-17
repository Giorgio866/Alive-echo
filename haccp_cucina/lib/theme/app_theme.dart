import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette cucina professionale: teal igiene + ambra allarmi, niente viola/crema AI-default.
class AppColors {
  static const Color teal = Color(0xFF0B6E6A);
  static const Color tealDark = Color(0xFF084E4B);
  static const Color tealSoft = Color(0xFFD7EFED);
  static const Color amber = Color(0xFFC47A12);
  static const Color amberSoft = Color(0xFFF8E8CF);
  static const Color coral = Color(0xFFC44536);
  static const Color slate = Color(0xFF1C2B33);
  static const Color slateMuted = Color(0xFF5A6B74);
  static const Color surface = Color(0xFFF3F6F8);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color ok = Color(0xFF2F7D4A);
  static const Color warn = Color(0xFFC47A12);
  static const Color danger = Color(0xFFC44536);
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.teal,
        primary: AppColors.teal,
        secondary: AppColors.amber,
        error: AppColors.coral,
        surface: AppColors.surfaceElevated,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.surface,
    );

    final display = GoogleFonts.frauncesTextTheme(base.textTheme).apply(
      bodyColor: AppColors.slate,
      displayColor: AppColors.slate,
    );
    final body = GoogleFonts.manropeTextTheme(base.textTheme).apply(
      bodyColor: AppColors.slate,
      displayColor: AppColors.slate,
    );

    return base.copyWith(
      textTheme: body.copyWith(
        displayLarge: display.displayLarge?.copyWith(fontWeight: FontWeight.w700),
        displayMedium: display.displayMedium?.copyWith(fontWeight: FontWeight.w700),
        displaySmall: display.displaySmall?.copyWith(fontWeight: FontWeight.w700),
        headlineLarge: display.headlineLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 28),
        headlineMedium: display.headlineMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 24),
        headlineSmall: display.headlineSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 20),
        titleLarge: body.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: body.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: body.labelLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.2),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.slate,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.slate,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceElevated,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.slate.withValues(alpha: 0.08)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.tealDark,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: AppColors.teal, width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceElevated,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.slate.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.teal, width: 1.6),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        indicatorColor: AppColors.tealSoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.manrope(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.tealSoft,
        selectedColor: AppColors.teal,
        labelStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
