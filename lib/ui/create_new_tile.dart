import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Spec 018 §3: the inline "create new" affordance shown at the top of the
/// add-to-menu lists (dishes and drinks). A tappable accent row mirroring the
/// shape of the catalog/menu item rows, with a leading "+" and a label.
class CreateNewTile extends StatelessWidget {
  const CreateNewTile({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = Icons.add,
  });

  final String label;
  final VoidCallback? onTap;

  /// Leading icon. Defaults to "+"; the AI entry (Spec 034 §A2) passes the AI
  /// symbol used on every AI-driven action.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accentSecondarySoft,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.accentSecondary),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.accentSecondary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.body.copyWith(
                    color: AppColors.accentSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
