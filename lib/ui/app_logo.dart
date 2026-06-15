import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The brand icon, loaded from the bundled launcher-icon asset (Spec 012 §2.1).
///
/// A single source for the asset path so the Settings card and header — and any
/// future surface — stay in sync. The icon is a full-bleed square, so it is
/// clipped to a rounded rectangle to match the design system's card radius.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 44, this.borderRadius = 10});

  /// Edge length of the (square) logo in logical pixels.
  final double size;

  /// Corner radius of the rounded clip.
  final double borderRadius;

  /// The bundled brand icon (the same source as the launcher icon / splash).
  static const String asset = 'assets/icon/entertain - icon legacy.png';

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // A faint border keeps the light icon edge legible on the warm surface.
        errorBuilder: (_, _, _) => Container(
          width: size,
          height: size,
          color: AppColors.surfaceSoft,
        ),
      ),
    );
  }
}
