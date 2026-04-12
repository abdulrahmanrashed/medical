import 'package:flutter/widgets.dart';

import 'responsive.dart';

/// Centers shell body and caps width on large viewports so content does not
/// stretch edge-to-edge on ultra-wide screens.
class ResponsiveMainContent extends StatelessWidget {
  const ResponsiveMainContent({
    super.key,
    required this.width,
    required this.child,
    this.alignment = Alignment.topCenter,
  });

  final double width;
  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final maxW = Responsive.contentMaxWidth(width);
    if (maxW.isInfinite) {
      return child;
    }
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: child,
      ),
    );
  }
}
