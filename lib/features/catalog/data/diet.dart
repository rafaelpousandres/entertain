/// Spec 025 Part B/C — dietary attributes (ingredients) + derivation (dishes) +
/// the catalog filter predicates. All the dietary logic is pure and lives here
/// so it is unit-testable and shared by the editors, the derivation, and the
/// filter. Mirrors the enum+helpers shape of [dish_category.dart].
library;

import '../../../l10n/app_localizations.dart';
import 'dish.dart' show DishAcquisitionMode;

/// Ordered dietary level. The order is meaningful: vegan/vegetarian are levels
/// on ONE axis, so `vegan ⇒ vegetarian` is structural and "vegan but not
/// vegetarian" cannot be represented. `unknown` = not yet classified.
enum DietLevel { unknown, none, vegetarian, vegan }

extension DietLevelWire on DietLevel {
  String get wire => switch (this) {
    DietLevel.unknown => 'unknown',
    DietLevel.none => 'none',
    DietLevel.vegetarian => 'vegetarian',
    DietLevel.vegan => 'vegan',
  };

  static DietLevel parse(String? value) => switch (value) {
    'none' => DietLevel.none,
    'vegetarian' => DietLevel.vegetarian,
    'vegan' => DietLevel.vegan,
    _ => DietLevel.unknown,
  };
}

/// Independent tri-state (gluten-free axis, and the generic yes/no/unknown).
enum TriState { unknown, yes, no }

extension TriStateWire on TriState {
  String get wire => switch (this) {
    TriState.unknown => 'unknown',
    TriState.yes => 'yes',
    TriState.no => 'no',
  };

  static TriState parse(String? value) => switch (value) {
    'yes' => TriState.yes,
    'no' => TriState.no,
    _ => TriState.unknown,
  };
}

/// Editor option order (Unknown first as the explicit default).
const List<DietLevel> dietLevelOrder = [
  DietLevel.unknown,
  DietLevel.none,
  DietLevel.vegetarian,
  DietLevel.vegan,
];

const List<TriState> triStateOrder = [
  TriState.unknown,
  TriState.yes,
  TriState.no,
];

String dietLevelLabel(AppLocalizations l10n, DietLevel d) => switch (d) {
  DietLevel.unknown => l10n.dietLevelUnknown,
  DietLevel.none => l10n.dietLevelNone,
  DietLevel.vegetarian => l10n.dietLevelVegetarian,
  DietLevel.vegan => l10n.dietLevelVegan,
};

/// Label for the gluten-free axis (tri-state reads as gluten-free / contains /
/// unknown, not a bare yes/no).
String glutenFreeLabel(AppLocalizations l10n, TriState g) => switch (g) {
  TriState.unknown => l10n.glutenFreeUnknown,
  TriState.yes => l10n.glutenFreeYes,
  TriState.no => l10n.glutenFreeNo,
};

// ── Derivation (dishes from ingredients) — pure, conservative ───────────────

/// Derives a dish's `diet` from its ingredients' diets (Spec 025 B.3):
/// any `none` settles it (even amid unknowns); else any `unknown` → unknown;
/// else all `vegan` → vegan; else vegetarian. Empty list → unknown (the caller
/// uses the dish's manual value when there are no ingredients).
DietLevel deriveDishDiet(List<DietLevel> ingredientDiets) {
  if (ingredientDiets.isEmpty) return DietLevel.unknown;
  if (ingredientDiets.contains(DietLevel.none)) return DietLevel.none;
  if (ingredientDiets.contains(DietLevel.unknown)) return DietLevel.unknown;
  if (ingredientDiets.every((d) => d == DietLevel.vegan)) return DietLevel.vegan;
  return DietLevel.vegetarian;
}

/// Derives a dish's gluten-free status: any `no` settles it; else any `unknown`
/// → unknown; else (all `yes`) → yes. Empty → unknown.
TriState deriveDishGlutenFree(List<TriState> ingredientGf) {
  if (ingredientGf.isEmpty) return TriState.unknown;
  if (ingredientGf.contains(TriState.no)) return TriState.no;
  if (ingredientGf.contains(TriState.unknown)) return TriState.unknown;
  return TriState.yes;
}

/// A dish's effective `diet`: derived from ingredients when it has any, else the
/// dish's manual field (Spec 025 B.4). Never stored — always computed on read.
DietLevel effectiveDishDiet({
  required bool hasIngredients,
  required DietLevel manual,
  required List<DietLevel> ingredientDiets,
}) => hasIngredients ? deriveDishDiet(ingredientDiets) : manual;

TriState effectiveDishGlutenFree({
  required bool hasIngredients,
  required TriState manual,
  required List<TriState> ingredientGf,
}) => hasIngredients ? deriveDishGlutenFree(ingredientGf) : manual;

// ── Filter predicates — pure (Spec 025 Part C) ──────────────────────────────

/// The dietary filter chips (AND semantics across selected chips).
enum DietChip { vegan, vegetarian, glutenFree }

String dietChipLabel(AppLocalizations l10n, DietChip c) => switch (c) {
  DietChip.vegan => l10n.filterVegan,
  DietChip.vegetarian => l10n.filterVegetarian,
  DietChip.glutenFree => l10n.filterGlutenFree,
};

/// Whether a dish's effective dietary status matches ALL selected chips.
/// `unknown` never matches a positive chip (we only show what we can vouch for);
/// vegetarian matches vegan too (vegan ⇒ vegetarian).
bool dishMatchesDietary(DietLevel diet, TriState gf, Set<DietChip> chips) {
  for (final c in chips) {
    final ok = switch (c) {
      DietChip.vegan => diet == DietLevel.vegan,
      DietChip.vegetarian =>
        diet == DietLevel.vegetarian || diet == DietLevel.vegan,
      DietChip.glutenFree => gf == TriState.yes,
    };
    if (!ok) return false;
  }
  return true;
}

/// Whether a dish matches the acquisition filter (null = no filter).
bool dishMatchesAcquisition(
  DishAcquisitionMode mode,
  DishAcquisitionMode? filter,
) => filter == null || mode == filter;

// ── Dietary badges (Spec 026 Part C, extended in Spec 030 §C) ────────────────

/// A dietary badge shown as a compact colour-coded text pill. Spec 030 §C
/// extends the original positive-only set to express ALL three states per axis,
/// so an unclassified aspect is visible at a glance (the black "?") and the user
/// can complete it. Background colour encodes the state; the letter colour is
/// chosen per badge for legibility (set in the widget / PDF, not here).
enum DietBadge {
  /// Diet axis, positive: "VGN", dark-green bg / white text.
  vegan,

  /// Diet axis, positive: "VGT", light-green bg / dark-green text.
  vegetarian,

  /// Diet axis, known-negative (not vegetarian/vegan): "VGT", grey.
  dietNegative,

  /// Gluten axis, positive (gluten-free): "SG", orange bg / white text.
  glutenFree,

  /// Gluten axis, known-negative (contains gluten): "SG", grey.
  glutenNegative,

  /// Transversal: at least one axis is unknown → a single "?", black bg / white.
  unknown,
}

/// The badges for an (effective) dietary status (Spec 030 §C): two axes, **at
/// most one badge each → max 2 badges**. Each known axis shows its badge
/// (positive colour or grey negative); each unknown axis is replaced by the
/// transversal **"?"**, which appears **once** even when both axes are unknown.
///
/// Exact combinatorics: both unknown → `["?"]`; diet known + gluten unknown →
/// `[diet, "?"]`; diet unknown + gluten known → `["?", gluten]`; both known →
/// `[diet, gluten]`. Vegan still emits a single diet badge (vegan ⇒ vegetarian).
List<DietBadge> dietaryBadgesFor(DietLevel diet, TriState glutenFree) {
  final DietBadge? dietBadge = switch (diet) {
    DietLevel.vegan => DietBadge.vegan,
    DietLevel.vegetarian => DietBadge.vegetarian,
    DietLevel.none => DietBadge.dietNegative,
    DietLevel.unknown => null,
  };
  final DietBadge? glutenBadge = switch (glutenFree) {
    TriState.yes => DietBadge.glutenFree,
    TriState.no => DietBadge.glutenNegative,
    TriState.unknown => null,
  };
  // Both axes unknown → one transversal "?" (not two).
  if (dietBadge == null && glutenBadge == null) {
    return const [DietBadge.unknown];
  }
  // One badge per axis, in order; an unknown axis shows the "?".
  return [dietBadge ?? DietBadge.unknown, glutenBadge ?? DietBadge.unknown];
}

/// The badge whose colour represents a SINGLE diet level on a choose-pill —
/// every state maps (unknown → "?", none → grey negative, veg/vegan → green), so
/// the colour a user picks matches the badge later shown. (Distinct from
/// [dietaryBadgesFor], which collapses the two axes for the read-only display.)
DietBadge dietLevelBadge(DietLevel d) => switch (d) {
  DietLevel.unknown => DietBadge.unknown,
  DietLevel.none => DietBadge.dietNegative,
  DietLevel.vegetarian => DietBadge.vegetarian,
  DietLevel.vegan => DietBadge.vegan,
};

/// The badge whose colour represents a single gluten state on a choose-pill.
DietBadge glutenStateBadge(TriState g) => switch (g) {
  TriState.unknown => DietBadge.unknown,
  TriState.yes => DietBadge.glutenFree,
  TriState.no => DietBadge.glutenNegative,
};

/// The abbreviation shown inside the pill: the positive and negative states of
/// an axis share a letter (the colour distinguishes them), and "?" is literal.
/// VGN/VGT/SG are locale-aware (ARB), so they follow the app language.
String dietBadgeAbbrev(AppLocalizations l10n, DietBadge b) => switch (b) {
  DietBadge.vegan => l10n.dietBadgeVegan,
  DietBadge.vegetarian || DietBadge.dietNegative => l10n.dietBadgeVegetarian,
  DietBadge.glutenFree || DietBadge.glutenNegative => l10n.dietBadgeGlutenFree,
  DietBadge.unknown => '?',
};
