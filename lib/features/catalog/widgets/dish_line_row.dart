import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../data/dish.dart';
import '../data/reference_data.dart';

/// One recipe line in the dish editor: ingredient name over
/// "quantity · prep note · supplier".
///
/// Spec 034 §B2: a line whose ingredient is no longer in the catalog
/// ([DishLineDraft.ingredientDeleted]) is flagged — warning border, warning
/// icon and a "Not in the catalog" caption — so the user can spot and fix it.
class DishLineRow extends StatelessWidget {
  const DishLineRow({
    super.key,
    required this.line,
    required this.unit,
    required this.supplierCategory,
    required this.onTap,
  });

  final DishLineDraft line;
  final Unit? unit;
  final SupplierCategory? supplierCategory;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final qty = formatQuantity(
      line.quantity,
      decimalSeparator: quantityDecimalSeparator(
        Localizations.localeOf(context).languageCode,
      ),
    );
    final measure = unit == null ? qty : '$qty ${unit!.name}';
    final hasNote = line.prepNote != null && line.prepNote!.trim().isNotEmpty;
    // Same layout as the event-dish ingredient card: quantity · prep · supplier.
    final parts = <String>[
      measure,
      if (hasNote) line.prepNote!.trim(),
      if (supplierCategory != null) supplierCategory!.name,
    ];
    final missing = line.ingredientDeleted;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: missing ? AppColors.warning : AppColors.border,
              width: missing ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              if (missing) ...[
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  size: 22,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      line.ingredientName,
                      style: AppTypography.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      parts.join(l10n.metadataSeparator),
                      style: AppTypography.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (missing) ...[
                      const SizedBox(height: 2),
                      Text(
                        l10n.dishLineNotInCatalogLabel,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: AppColors.disabled,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How the user chose to fix a line whose ingredient left the catalog.
enum MissingIngredientFix { restore, replace }

/// Spec 034 §B2 — the fix sheet for a not-in-catalog line: restore the
/// ingredient to the catalog, or replace it with another one. Resolves to null
/// when dismissed.
Future<MissingIngredientFix?> showMissingIngredientSheet(
  BuildContext context, {
  required String ingredientName,
}) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<MissingIngredientFix>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.dishLineFixTitle(ingredientName),
              style: AppTypography.sectionTitle,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.dishLineFixBody,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.restore,
                color: AppColors.accentSecondary,
              ),
              title: Text(
                l10n.dishLineRestoreAction,
                style: AppTypography.body,
              ),
              onTap: () =>
                  Navigator.of(sheetContext).pop(MissingIngredientFix.restore),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.swap_horiz,
                color: AppColors.accentSecondary,
              ),
              title: Text(
                l10n.dishLineReplaceAction,
                style: AppTypography.body,
              ),
              onTap: () =>
                  Navigator.of(sheetContext).pop(MissingIngredientFix.replace),
            ),
          ],
        ),
      ),
    ),
  );
}
