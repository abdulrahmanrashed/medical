import 'package:flutter/widgets.dart';

abstract final class Responsive {
  /// Material “medium” breakpoint — persistent rail + master layouts start here.
  static const double breakpointMasterLayout = 600;

  static const double breakpointTablet = 768;
  static const double breakpointLarge = 1100;

  /// Sidebar / navigation rail + split master–detail layouts (width ≥ 600dp).
  static bool useMasterLayout(double width) => width >= breakpointMasterLayout;

  static bool isTablet(double width) => width >= breakpointTablet;

  /// Wide desktop / large tablet — use 3-column grids.
  static bool isLargeWidth(double width) => width >= breakpointLarge;

  /// 1 = phone, 2 = tablet, 3 = large.
  static int gridColumnCount(double width) {
    if (width >= breakpointLarge) return 3;
    if (width >= breakpointTablet) return 2;
    return 1;
  }

  /// Keeps main content readable on ultra-wide displays.
  static double contentMaxWidth(double width) {
    if (width >= 1400) return 1200;
    if (width >= breakpointTablet) return 960;
    return double.infinity;
  }

  static EdgeInsets screenPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1200) return const EdgeInsets.all(28);
    if (width >= breakpointTablet) return const EdgeInsets.all(22);
    return const EdgeInsets.all(16);
  }

  static double titleSize(BuildContext context, {double base = 22}) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    return base * textScale.clamp(0.9, 1.2);
  }
}
