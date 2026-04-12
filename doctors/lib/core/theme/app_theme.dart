import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/medical_app_background.dart';

/// Global palette: teal accent, off-white canvas, white surfaces, gray text hierarchy.
abstract final class AppTheme {
  static const Color primaryTeal = Color(0xFF00A1A1);
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF888888);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE5E5E8);

  static ThemeData get light {
    final colorScheme = ColorScheme.light(
      primary: primaryTeal,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFBFE8E8),
      onPrimaryContainer: Color(0xFF003333),
      secondary: primaryTeal,
      onSecondary: Colors.white,
      surface: surfaceWhite,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      outline: cardBorder,
      outlineVariant: Color(0xFFF0F0F2),
      error: Color(0xFFB00020),
      onError: Colors.white,
    );

    final base = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: MedicalAppBackground.paleMedicalBlue,
    );

    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    return base.copyWith(
      textTheme: textTheme.copyWith(
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        titleSmall: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w400,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          color: textSecondary,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          color: textSecondary,
        ),
        labelMedium: textTheme.labelMedium?.copyWith(
          color: textSecondary,
        ),
        labelSmall: textTheme.labelSmall?.copyWith(
          color: textSecondary,
        ),
      ),
      primaryColor: primaryTeal,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: MedicalAppBackground.paleMedicalBlue,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: MedicalAppBackground.paleMedicalBlue,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: MedicalAppBackground.paleMedicalBlue,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surfaceWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shadowColor: const Color(0xFF000000).withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryTeal,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryTeal,
        foregroundColor: Colors.white,
        elevation: 2,
        highlightElevation: 4,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFFB00020),
        contentTextStyle: TextStyle(color: Colors.white),
      ),
      dividerTheme: const DividerThemeData(
        color: cardBorder,
        thickness: 1,
      ),
    );
  }
}
