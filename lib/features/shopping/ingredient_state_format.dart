/// Presentation helpers for the ingredient state machine (Spec 007 §3.4):
/// the colour dot and the localised label shown on the summary header, the
/// per-line indicator, and the state-change sheet.
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import 'data/ingredient_state.dart';

/// Dot / accent colour for a state, drawn from the design-system tokens:
/// to_order → warning (needs action), ordered → teal (in transit),
/// received → success, missing → danger, at_home → neutral (already have it).
Color ingredientStateColor(IngredientState state) => switch (state) {
  IngredientState.toOrder => AppColors.warning,
  IngredientState.ordered => AppColors.accentSecondary,
  IngredientState.received => AppColors.success,
  IngredientState.missing => AppColors.danger,
  IngredientState.atHome => AppColors.textTertiary,
};

/// Canonical, sentence-case label for a state (used in sub-group headers and
/// the state-change sheet).
String ingredientStateLabel(AppLocalizations l10n, IngredientState state) =>
    switch (state) {
      IngredientState.toOrder => l10n.shoppingStateToOrder,
      IngredientState.ordered => l10n.shoppingStateOrdered,
      IngredientState.received => l10n.shoppingStateReceived,
      IngredientState.missing => l10n.shoppingStateMissing,
      IngredientState.atHome => l10n.shoppingStateAtHome,
    };
