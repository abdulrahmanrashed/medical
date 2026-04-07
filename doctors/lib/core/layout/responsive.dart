import 'package:flutter/widgets.dart';

abstract final class Responsive {
  static bool isTablet(double width) => width >= 768;

  static EdgeInsets screenPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1200) return const EdgeInsets.all(28);
    if (width >= 768) return const EdgeInsets.all(22);
    return const EdgeInsets.all(16);
  }

  static double titleSize(BuildContext context, {double base = 22}) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    return base * textScale.clamp(0.9, 1.2);
  }
}
