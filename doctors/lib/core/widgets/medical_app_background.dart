import 'package:flutter/material.dart';

/// Soft gradient plus a very subtle geometric grid for a modern clinical feel.
class MedicalAppBackground extends StatelessWidget {
  const MedicalAppBackground({super.key, required this.child});

  final Widget child;

  /// App canvas / scaffold background (off-white).
  static const Color paleMedicalBlue = Color(0xFFF5F5F7);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), paleMedicalBlue],
        ),
      ),
      child: CustomPaint(
        painter: _MedicalGeometricPainter(),
        child: child,
      ),
    );
  }
}

class _MedicalGeometricPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 44.0;
    final line = Paint()
      ..color = const Color(0xFF00A1A1).withValues(alpha: 0.045)
      ..strokeWidth = 0.6;
    final dot = Paint()
      ..color = const Color(0xFF00A1A1).withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    for (double x = spacing; x < size.width; x += spacing * 2) {
      for (double y = spacing; y < size.height; y += spacing * 2) {
        canvas.drawCircle(Offset(x, y), 1.2, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
