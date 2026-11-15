import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';

/// Confirmation shown before deleting a catalog ingredient.
///
/// Spec 034 §B1: when the ingredient is used by live catalog dishes, the dialog
/// names them ([usedIn]) and spells out the consequence, so the delete is an
/// informed confirmation — never silent, never a hard block. With no usage it
/// is the plain confirmation it always was. Resolves to true on confirm.
Future<bool?> showDeleteIngredientDialog(
  BuildContext context, {
  required List<String> usedIn,
}) {
  final l10n = AppLocalizations.of(context);
  final secondary = AppTypography.body.copyWith(color: AppColors.textSecondary);
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        l10n.deleteIngredientConfirmTitle,
        style: AppTypography.sectionTitle,
      ),
      content: usedIn.isEmpty
          ? Text(l10n.deleteIngredientConfirmBody, style: secondary)
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.deleteIngredientInUseBody(usedIn.length),
                  style: secondary,
                ),
                const SizedBox(height: 8),
                // A long list scrolls inside the dialog instead of pushing the
                // actions off-screen.
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final name in usedIn)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text('• $name', style: AppTypography.body),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(l10n.deleteIngredientInUseConsequence, style: secondary),
              ],
            ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            l10n.cancelAction,
            style: AppTypography.button.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            l10n.deleteIngredientConfirmButton,
            style: AppTypography.button.copyWith(color: AppColors.danger),
          ),
        ),
      ],
    ),
  );
}
