/// Domain model and draft for a catalog `drinks` row (Spec 014 §2.2).
///
/// A drink is the same shape as a prepared (bought) dish — a non-decomposable
/// menu item bought from a supplier as a single purchase line — but lives in
/// its own catalog and its own event-menu section. No ingredients, no course
/// category, always "bought".
library;

class Drink {
  const Drink({
    required this.id,
    required this.groupId,
    required this.name,
    required this.baseServings,
    this.supplierCategoryId,
    this.purchaseUnit,
    this.servingsPerUnit,
  });

  final String id;
  final String groupId;
  final String name;
  final int baseServings;

  /// Supplier category the drink is ordered from (resolved to a concrete
  /// supplier at order time, Spec 013). Nullable.
  final String? supplierCategoryId;

  /// Optional free-text purchase unit (e.g. "ampolla").
  final String? purchaseUnit;

  /// Optional servings one purchase unit provides; with [purchaseUnit] the
  /// shopping line computes units = ceil(scaledServings / this).
  final double? servingsPerUnit;

  factory Drink.fromRow(Map<String, dynamic> row) {
    return Drink(
      id: row['id'] as String,
      groupId: row['group_id'] as String,
      name: row['name'] as String,
      baseServings: (row['base_servings'] as num?)?.toInt() ?? 4,
      supplierCategoryId: row['supplier_category_id'] as String?,
      purchaseUnit: row['purchase_unit'] as String?,
      servingsPerUnit: (row['servings_per_unit'] as num?)?.toDouble(),
    );
  }

  static const String selectColumns =
      'id, group_id, name, base_servings, supplier_category_id, '
      'purchase_unit, servings_per_unit';
}

/// Mutable editor view of a drink.
class DrinkDraft {
  DrinkDraft({
    required this.name,
    required this.baseServings,
    this.supplierCategoryId,
    this.purchaseUnit,
    this.servingsPerUnit,
  });

  factory DrinkDraft.empty() => DrinkDraft(name: '', baseServings: 4);

  factory DrinkDraft.fromDrink(Drink drink) => DrinkDraft(
    name: drink.name,
    baseServings: drink.baseServings,
    supplierCategoryId: drink.supplierCategoryId,
    purchaseUnit: drink.purchaseUnit,
    servingsPerUnit: drink.servingsPerUnit,
  );

  String name;
  int baseServings;
  String? supplierCategoryId;
  String? purchaseUnit;
  double? servingsPerUnit;

  /// Row payload for the `drinks` table. `group_id` is added by the repository.
  Map<String, dynamic> toRow() {
    final unit = purchaseUnit?.trim();
    return {
      'name': name.trim(),
      'base_servings': baseServings,
      'supplier_category_id': supplierCategoryId,
      'purchase_unit': (unit == null || unit.isEmpty) ? null : unit,
      'servings_per_unit': servingsPerUnit,
    };
  }
}
