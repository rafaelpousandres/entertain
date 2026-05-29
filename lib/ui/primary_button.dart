import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Primary action button per design system §5.
///
/// `accent` fill, `on-accent` text, radius 12, height 48. Designed for the
/// bottom action bar — defaults to full width inside its parent.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final fill = enabled ? AppColors.accent : AppColors.disabled;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: AppColors.onAccent, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(label, style: AppTypography.button),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
