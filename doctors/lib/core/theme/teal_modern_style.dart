import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme.dart';

/// Green/teal “3D” affordances: soft gradient, stacked shadow, rounded shape.
abstract final class TealModernStyle {
  static const Color deepTeal = Color(0xFF004D40);
  static const Color midTeal = Color(0xFF00897B);
  static const Color highlightTeal = Color(0xFF26A69A);

  static BoxDecoration primaryButtonDecoration({bool pressed = false}) {
    final dy = pressed ? 1.0 : 3.0;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [highlightTeal, midTeal, deepTeal],
        stops: [0.0, 0.45, 1.0],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          offset: Offset(0, dy + 2),
          blurRadius: 6,
        ),
        BoxShadow(
          color: deepTeal.withValues(alpha: 0.35),
          offset: Offset(0, dy),
          blurRadius: 0,
        ),
      ],
    );
  }

  static ButtonStyle filledButtonStyle() {
    return ButtonStyle(
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      backgroundColor: WidgetStateProperty.all(Colors.transparent),
      shadowColor: WidgetStateProperty.all(Colors.transparent),
      elevation: WidgetStateProperty.all(0),
      foregroundColor: WidgetStateProperty.all(Colors.white),
      textStyle: WidgetStateProperty.all(
        GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return Colors.white.withValues(alpha: 0.12);
        }
        return Colors.white.withValues(alpha: 0.06);
      }),
    );
  }

  /// Use with [Ink] + [decorator]: primary gradient pill.
  static Widget primaryButton({
    required VoidCallback? onPressed,
    required Widget child,
    bool loading = false,
  }) {
    return _GradientSurfaceButton(
      onPressed: onPressed,
      loading: loading,
      child: child,
    );
  }

  static InputDecoration inputDecoration(
    BuildContext context, {
    required String labelText,
    String? hintText,
    int maxLines = 1,
  }) {
    final r = BorderRadius.circular(12);
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
      border: OutlineInputBorder(borderRadius: r),
      enabledBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: BorderSide(color: AppTheme.primaryTeal.withValues(alpha: 0.35)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: r,
        borderSide: const BorderSide(color: AppTheme.primaryTeal, width: 2),
      ),
    );
  }
}

class _GradientSurfaceButton extends StatefulWidget {
  const _GradientSurfaceButton({
    required this.onPressed,
    required this.child,
    this.loading = false,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool loading;

  @override
  State<_GradientSurfaceButton> createState() => _GradientSurfaceButtonState();
}

class _GradientSurfaceButtonState extends State<_GradientSurfaceButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      decoration: TealModernStyle.primaryButtonDecoration(pressed: _pressed && enabled),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? widget.onPressed : null,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Center(
              child: widget.loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : DefaultTextStyle.merge(
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                      child: widget.child,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
