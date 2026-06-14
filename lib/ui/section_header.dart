import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'icon_circle.dart';

/// Collapsible section header per design system §5.
///
/// Layout: leading icon circle, label in `accent-secondary` weight 500,
/// optional count, trailing chevron — up when expanded, down when
/// collapsed. Tapping the whole row toggles the section.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.icon,
    required this.label,
    required this.expanded,
    required this.onToggle,
    this.count,
    this.trailing,
    this.iconBackgroundColor,
    this.iconColor,
    this.iconRingColor,
  });

  final IconData icon;
  final String label;
  final int? count;
  final bool expanded;
  final VoidCallback onToggle;

  /// Optional widget shown between the label and the chevron — used by the
  /// shopping panel for the per-supplier status counters (Spec 011 §2.9).
  final Widget? trailing;

  /// Optional tint for the leading [IconCircle] (Spec 011 §2.10). When null the
  /// circle keeps its default accent-secondary look.
  final Color? iconBackgroundColor;
  final Color? iconColor;
  final Color? iconRingColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            IconCircle(
              icon: icon,
              backgroundColor: iconBackgroundColor,
              iconColor: iconColor,
              ringColor: iconRingColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTypography.label.copyWith(
                  color: AppColors.accentSecondary,
                ),
              ),
            ),
            if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
            if (count != null) ...[
              Text(
                '$count',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(
              expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: AppColors.accentSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
