/// Quantity rule for a prepared-dish / drink purchase line (Spec 014 §2.5).
///
/// A bought item is one shopping line. If it defines a purchase unit and how
/// many servings that unit provides, the line shows **units to buy** =
/// `ceil(scaledServings / servingsPerUnit)` (e.g. "3 safates"); otherwise it
/// shows the **scaled servings** and the user judges how much to ask for.
library;

import 'ingredient_state.dart';
import 'shopping_models.dart';

class PurchaseQuantity {
  const PurchaseQuantity(this.quantity, this.unitLabel);

  /// Units to buy when [unitLabel] is set, else the scaled servings.
  final double quantity;

  /// The free-text purchase unit (e.g. "safates"), or null when the quantity
  /// is expressed in servings — the UI then appends a localised "racions".
  final String? unitLabel;
}

PurchaseQuantity purchaseLineQuantity({
  required int servings,
  required String? purchaseUnit,
  required double? servingsPerUnit,
}) {
  final unit = purchaseUnit?.trim();
  if (unit != null &&
      unit.isNotEmpty &&
      servingsPerUnit != null &&
      servingsPerUnit > 0) {
    final units = (servings / servingsPerUnit).ceil();
    return PurchaseQuantity(units.toDouble(), unit);
  }
  return PurchaseQuantity(servings.toDouble(), null);
}

/// Builds the single purchase [ShoppingLine] for a bought dish or a drink from
/// its already-scaled [servings] snapshot. `ingredientId` is left null so the
/// aggregation key falls back to the unique line id — a purchase line never
/// merges with another item.
ShoppingLine purchaseShoppingLine({
  required String id,
  required ShoppingLineKind kind,
  required String name,
  required String? supplierCategoryId,
  required int servings,
  required String? purchaseUnit,
  required double? servingsPerUnit,
  required IngredientState state,
}) {
  final q = purchaseLineQuantity(
    servings: servings,
    purchaseUnit: purchaseUnit,
    servingsPerUnit: servingsPerUnit,
  );
  return ShoppingLine(
    id: id,
    ingredientName: name,
    quantity: q.quantity,
    kind: kind,
    purchaseUnitLabel: q.unitLabel,
    supplierCategoryId: supplierCategoryId,
    state: state,
  );
}
