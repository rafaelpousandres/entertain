/// Presentation helpers for the ingredient state machine (Spec 007 §3.4):
/// the colour dot and the localised label shown on the summary header, the
/// per-line indicator, and the state-change sheet.
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import 'data/ingredient_state.dart';

/// Dot / accent colour for a state. Spec 007 Fixes round 2 §2.1 recolours the
/// indicators by **availability** rather than by stage: green for "I have it"
/// (at_home, received), red for "I don't" (to_order, missing), amber/yellow for
/// "in transit" (ordered). The label next to the dot still disambiguates which
/// exact state a line is in, so the two same-colour pairs lose no information.
Color ingredientStateColor(IngredientState state) => switch (state) {
  IngredientState.atHome => AppColors.success,
  IngredientState.received => AppColors.success,
  IngredientState.toOrder => AppColors.danger,
  IngredientState.missing => AppColors.danger,
  IngredientState.ordered => AppColors.warning,
};

/// Canonical, sentence-case label for a state (used in the state-change sheet
/// and wherever a persisted [IngredientState] is shown directly).
String ingredientStateLabel(AppLocalizations l10n, IngredientState state) =>
    switch (state) {
      IngredientState.toOrder => l10n.shoppingStateToOrder,
      IngredientState.ordered => l10n.shoppingStateOrdered,
      IngredientState.received => l10n.shoppingStateReceived,
      IngredientState.missing => l10n.shoppingStateMissing,
      IngredientState.atHome => l10n.shoppingStateAtHome,
    };

/// Dot / accent colour for a [DisplayState] — the §2.1 availability palette
/// plus the derived "Retrassat" overlay in burnt orange (§2.2), positioned
/// between the amber of `ordered` and the red of the "I don't have it" states.
Color displayStateColor(DisplayState state) => switch (state) {
  DisplayState.atHome => AppColors.success,
  DisplayState.received => AppColors.success,
  DisplayState.toOrder => AppColors.danger,
  DisplayState.missing => AppColors.danger,
  DisplayState.ordered => AppColors.warning,
  DisplayState.delayed => AppColors.delayed,
};

/// Sentence-case label for a [DisplayState] — the five persisted labels plus
/// "Retrassat" / "Retrasado" / "Delayed" for the derived delayed overlay.
String displayStateLabel(AppLocalizations l10n, DisplayState state) =>
    switch (state) {
      DisplayState.toOrder => l10n.shoppingStateToOrder,
      DisplayState.ordered => l10n.shoppingStateOrdered,
      DisplayState.delayed => l10n.shoppingStateDelayed,
      DisplayState.received => l10n.shoppingStateReceived,
      DisplayState.missing => l10n.shoppingStateMissing,
      DisplayState.atHome => l10n.shoppingStateAtHome,
    };
