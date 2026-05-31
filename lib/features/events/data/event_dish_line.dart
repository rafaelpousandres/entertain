/// Read model for an `event_dish_ingredients` row — the editable per-event
/// copy of a recipe line (data model §3.3).
///
/// Every display field is a snapshot taken when the dish was added, so the
/// line renders independently of the catalog: `ingredientName` is a real
/// column (not a join), and `ingredientId` / `supplierCategoryId` are kept
/// for shopping-list aggregation and the per-event supplier override. Editing
/// a line writes back only to `event_dish_ingredients`, never to the catalog.
library;

class EventDishLine {
  const EventDishLine({
    required this.id,
    required this.ingredientName,
    required this.quantity,
    required this.unitId,
    required this.sortOrder,
    this.ingredientId,
    this.prepNote,
    this.supplierCategoryId,
  });

  final String id;

  /// Provenance reference to the catalog ingredient. Nullable — the FK is
  /// `on delete set null`; display never depends on it.
  final String? ingredientId;

  /// Snapshot of the ingredient name at add time (a real column).
  final String ingredientName;

  final double quantity;
  final String unitId;
  final String? prepNote;

  /// Per-event supplier assignment. Snapshotted from the ingredient's default
  /// on add, overridable here (e.g. marking the line as pantry / "Rebost").
  final String? supplierCategoryId;

  final int sortOrder;

  factory EventDishLine.fromRow(Map<String, dynamic> row) {
    return EventDishLine(
      id: row['id'] as String,
      ingredientId: row['ingredient_id'] as String?,
      ingredientName: row['ingredient_name'] as String,
      quantity: (row['quantity'] as num).toDouble(),
      unitId: row['unit_id'] as String,
      prepNote: row['prep_note'] as String?,
      supplierCategoryId: row['supplier_category_id'] as String?,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  static const String selectColumns =
      'id, ingredient_id, ingredient_name, quantity, unit_id, prep_note, '
      'supplier_category_id, sort_order';
}
