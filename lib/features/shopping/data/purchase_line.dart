/// Single shopping line for a prepared (bought) dish or a drink (Spec 014 §2.5,
/// refined by Spec 016).
///
/// Both are one shopping line that never decomposes into ingredients and never
/// merges with another item, but they quantify differently now:
///   * a **bought dish** shows units to buy =
///     `ceil(servings / servingsPerUnit)` (e.g. "3 × Canelons");
///   * a **drink** shows a manually-set unit count with its denomination
///     (e.g. "2 ampolles de Vi negre"), no servings, no scaling.
library;

import 'ingredient_state.dart';
import 'shopping_models.dart';

/// Units to buy for a bought dish from its event snapshot:
/// `ceil(servings / servingsPerUnit)`. Falls back to [servings] when there is
/// no per-unit snapshot (defensive — bought dishes always carry one).
int boughtDishUnits(int servings, double? servingsPerUnit) {
  if (servingsPerUnit == null || servingsPerUnit <= 0) return servings;
  return (servings / servingsPerUnit).ceil();
}

/// The single purchase [ShoppingLine] for a bought dish. Shown as a bare count
/// with the dish name (no unit label), so the panel/message read "3 × Canelons"
/// / "3 canelons". `ingredientId` is null so it never aggregates.
ShoppingLine boughtDishShoppingLine({
  required String id,
  required String name,
  required String? supplierCategoryId,
  required int servings,
  required double? servingsPerUnit,
  required IngredientState state,
}) {
  return ShoppingLine(
    id: id,
    ingredientName: name,
    quantity: boughtDishUnits(servings, servingsPerUnit).toDouble(),
    kind: ShoppingLineKind.preparedDish,
    supplierCategoryId: supplierCategoryId,
    state: state,
  );
}

/// The single purchase [ShoppingLine] for a drink: the manual unit [quantity]
/// plus its [denomination] code, rendered "2 ampolles de Vi negre". Never
/// aggregates.
ShoppingLine drinkShoppingLine({
  required String id,
  required String name,
  required String? supplierCategoryId,
  required int quantity,
  required String denomination,
  required IngredientState state,
}) {
  return ShoppingLine(
    id: id,
    ingredientName: name,
    quantity: quantity.toDouble(),
    kind: ShoppingLineKind.drink,
    denomination: denomination,
    supplierCategoryId: supplierCategoryId,
    state: state,
  );
}
