/// Read model for an `event_drinks` row — the per-event snapshot of a catalog
/// drink (Spec 014 §2.3). Mirror of [EventDish] for drinks: an immutable copy,
/// scaled to the guest count, that becomes a single purchase line in Shopping.
///
/// `sourceDrinkId` is provenance only (used to flag a drink already in the
/// menu); the snapshot never re-reads the catalog.
library;

/// §2.3: a drink added to an event scales to the **guest count** by default
/// (everyone drinks; the seated/buffet distinction is a food concept), falling
/// back to the catalog drink's base servings when the event has no guests yet.
int defaultEventDrinkServings(int guestCount, int baseServings) =>
    guestCount > 0 ? guestCount : baseServings;

class EventDrink {
  const EventDrink({
    required this.id,
    required this.name,
    required this.servings,
    required this.sortOrder,
    this.sourceDrinkId,
    this.supplierCategoryId,
    this.purchaseUnit,
    this.servingsPerUnit,
  });

  final String id;
  final String name;
  final int servings;
  final int sortOrder;
  final String? sourceDrinkId;

  /// Snapshot of the drink's supplier category (resolved to a concrete supplier
  /// at order time, Spec 013) and its optional purchase unit / servings-per-unit.
  final String? supplierCategoryId;
  final String? purchaseUnit;
  final double? servingsPerUnit;

  factory EventDrink.fromRow(Map<String, dynamic> row) {
    return EventDrink(
      id: row['id'] as String,
      name: row['drink_name'] as String,
      servings: (row['servings'] as num?)?.toInt() ?? 0,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      sourceDrinkId: row['source_drink_id'] as String?,
      supplierCategoryId: row['supplier_category_id'] as String?,
      purchaseUnit: row['purchase_unit'] as String?,
      servingsPerUnit: (row['servings_per_unit'] as num?)?.toDouble(),
    );
  }

  static const String selectColumns =
      'id, drink_name, servings, sort_order, source_drink_id, '
      'supplier_category_id, purchase_unit, servings_per_unit';
}
