import 'package:flutter/material.dart';

import 'responsive.dart';

/// On master-layout widths ([Responsive.useMasterLayout]), shows a centered
/// [Dialog] with a max width instead of a full-width bottom sheet.
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext context) builder,
  double maxWidth = 560,
  double maxHeightFraction = 0.92,
  bool barrierDismissible = true,
}) async {
  final w = MediaQuery.sizeOf(context).width;
  if (Responsive.useMasterLayout(w)) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) {
        final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
        return Dialog(
          clipBehavior: Clip.antiAlias,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: MediaQuery.sizeOf(ctx).height * maxHeightFraction,
            ),
            child: Padding(
              padding: EdgeInsets.only(bottom: bottom),
              child: builder(ctx),
            ),
          ),
        );
      },
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: builder,
  );
}
