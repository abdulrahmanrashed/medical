import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/layout/responsive.dart';
import '../../core/theme/app_theme.dart';

/// Clinic Management (ClinicAdmin) — matches global [AppTheme] teal on mobile and tablet.
abstract final class ClinicOwnerUi {
  static const Color primary = AppTheme.primaryTeal;
  static const Color surface = Color(0xFFF5F5F7);
  static const Color onSurfaceTitle = AppTheme.textPrimary;
  static const Color onSurfaceMuted = Color(0xFF616161);

  static BoxDecoration premiumCardDecoration({Color? color}) => BoxDecoration(
        color: color ?? AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  static TextStyle welcomeTitle(double width) => GoogleFonts.inter(
        fontSize: width >= Responsive.breakpointMasterLayout ? 30 : 26,
        fontWeight: FontWeight.w800,
        color: onSurfaceTitle,
        height: 1.15,
      );

  static TextStyle welcomeSubtitle() => GoogleFonts.inter(
        fontSize: 15,
        height: 1.4,
        color: onSurfaceMuted,
      );
}
