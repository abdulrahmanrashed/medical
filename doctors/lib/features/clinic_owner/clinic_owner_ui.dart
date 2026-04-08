import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/layout/responsive.dart';

/// Clinic Management (ClinicAdmin) — consistent with app teal primary.
abstract final class ClinicOwnerUi {
  static const Color primary = Color(0xFF004D40);
  static const Color surface = Color(0xFFF5F5F5);
  static const Color onSurfaceTitle = Color(0xFF1A1A1A);
  static const Color onSurfaceMuted = Color(0xFF616161);

  static BoxDecoration premiumCardDecoration({Color? color}) => BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      );

  static TextStyle welcomeTitle(double width) => GoogleFonts.inter(
        fontSize: width >= Responsive.breakpointTablet ? 32 : 28,
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
