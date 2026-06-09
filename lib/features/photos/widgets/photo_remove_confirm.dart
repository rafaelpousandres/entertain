import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';

/// Confirmation dialog before removing a photo (Spec 009 §2.2.4 / §2.2.5).
/// Returns true when the user confirms. Shared by the single-photo viewer and
/// the event carousel.
Future<bool> showPhotoRemoveConfirm(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(l10n.photoRemoveConfirmTitle, style: AppTypography.sectionTitle),
      content: Text(
        l10n.photoRemoveConfirmBody,
        style: AppTypography.body.copyWith(color: AppColors.textSecondary),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            l10n.cancelAction,
            style: AppTypography.button.copyWith(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            l10n.deleteAction,
            style: AppTypography.button.copyWith(color: AppColors.danger),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}
