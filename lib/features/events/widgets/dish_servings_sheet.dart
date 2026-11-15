import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/app_form_field.dart';
import '../../../ui/primary_button.dart';
import '../../../ui/stepper_field.dart';

/// Spec 034 §A1 — the servings step of adding a dish to an event menu. Shown
/// *before* the dish is inserted, pre-filled with the default the repository
/// would have applied, so the dish lands already with the chosen servings.
///
/// When the dish is [alreadyInMenu] the sheet also carries the "another
/// independent copy" notice that used to be a separate confirmation dialog, so
/// re-adding a dish is still one step. Resolves to the chosen servings, or null
/// when dismissed (nothing is added).
Future<int?> showDishServingsSheet(
  BuildContext context, {
  required String dishName,
  required int initialServings,
  bool alreadyInMenu = false,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _DishServingsSheet(
      dishName: dishName,
      initialServings: initialServings,
      alreadyInMenu: alreadyInMenu,
    ),
  );
}

class _DishServingsSheet extends StatefulWidget {
  const _DishServingsSheet({
    required this.dishName,
    required this.initialServings,
    required this.alreadyInMenu,
  });

  final String dishName;
  final int initialServings;
  final bool alreadyInMenu;

  @override
  State<_DishServingsSheet> createState() => _DishServingsSheetState();
}

class _DishServingsSheetState extends State<_DishServingsSheet> {
  late int _servings = widget.initialServings < 1 ? 1 : widget.initialServings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final secondary = AppTypography.body.copyWith(
      color: AppColors.textSecondary,
    );
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.dishName,
              style: AppTypography.sectionTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.alreadyInMenu) ...[
              const SizedBox(height: 6),
              Text(
                l10n.addDuplicateDishConfirmBody(widget.dishName),
                style: secondary,
              ),
            ],
            const SizedBox(height: 16),
            FieldLabel(
              label: l10n.eventDishServingsLabel,
              child: StepperField(
                value: _servings,
                onChanged: (value) => setState(() => _servings = value),
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.addDishServingsHint, style: AppTypography.caption),
            const SizedBox(height: 16),
            PrimaryButton(
              label: widget.alreadyInMenu
                  ? l10n.addDuplicateDishConfirmButton
                  : l10n.addDishServingsConfirm,
              icon: Icons.add,
              onPressed: () => Navigator.of(context).pop(_servings),
            ),
          ],
        ),
      ),
    );
  }
}
