import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Icon circle per design system §5: 34 px, `accent-secondary-soft`
/// background, `accent-secondary` icon. Used both for header actions and
/// as the leading badge inside section headers.
class IconCircle extends StatelessWidget {
  const IconCircle({
    super.key,
    required this.icon,
    this.size = 34,
    this.iconSize = 18,
    this.onTap,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.accentSecondarySoft,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: AppColors.accentSecondary, size: iconSize),
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
