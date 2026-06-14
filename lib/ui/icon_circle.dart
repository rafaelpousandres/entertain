import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Icon circle per design system §5: 34 px, `accent-secondary-soft`
/// background, `accent-secondary` icon. Used both for header actions and
/// as the leading badge inside section headers.
///
/// [backgroundColor], [iconColor] and [ringColor] override the defaults so the
/// badge can carry a status tint (Spec 011 §2.10: the supplier icon takes a pale
/// background and a saturated ring in the section's highest-priority colour).
class IconCircle extends StatelessWidget {
  const IconCircle({
    super.key,
    required this.icon,
    this.size = 34,
    this.iconSize = 18,
    this.onTap,
    this.backgroundColor,
    this.iconColor,
    this.ringColor,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? iconColor;
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.accentSecondarySoft,
        shape: BoxShape.circle,
        border: ringColor == null
            ? null
            : Border.all(color: ringColor!, width: 1.5),
      ),
      child: Icon(
        icon,
        color: iconColor ?? AppColors.accentSecondary,
        size: iconSize,
      ),
    );

    if (onTap == null) return circle;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: circle,
      ),
    );
  }
}
