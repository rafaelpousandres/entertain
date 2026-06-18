/// Read model for an `event_dishes` row — the per-event snapshot of a
/// catalog dish (the "copy on add" decision, data model §3.3).
///
/// `sourceDishId` is provenance only: it records which catalog dish the copy
/// came from (used by the picker to flag dishes already in the menu), but is
/// never followed to re-read or sync — the snapshot is independent of the
/// catalog from the moment it is created.
library;

import '../../catalog/data/dish.dart' show DishAcquisitionMode, DishAcquisitionModeWire;
import '../../catalog/data/dish_category.dart';

export '../../catalog/data/dish_category.dart'
    show DishCategory, DishCategoryWire, dishCategoryOrder;

class EventDish {
  const EventDish({
    required this.id,
    required this.name,
    required this.category,
    required this.servings,
    required this.sortOrder,
    this.sourceDishId,
    this.acquisitionMode = DishAcquisitionMode.cooked,
    this.supplierCategoryId,
    this.servingsPerUnit,
  });

  final String id;
  final String name;
  final DishCategory category;

  /// The servings this dish is to serve at the event (scales with guest count
  /// for a seated event, like cooked dishes).
  final int servings;
  final int sortOrder;

  /// Catalog dish this copy originated from. Nullable — the FK is
  /// `on delete set null`, and a soft-deleted catalog dish keeps it.
  final String? sourceDishId;

  /// Spec 014 §2.1: snapshot of how the dish is obtained. A `bought` event-dish
  /// is a single purchase line in Shopping; a `cooked` one explodes into its
  /// ingredient lines as before (these bought-only fields stay null).
  final DishAcquisitionMode acquisitionMode;
  final String? supplierCategoryId;

  /// Spec 016 §2.1: the per-unit snapshot for a bought dish (a frozen copy of
  /// the catalog dish's `base_servings` at add time — "servings one unit
  /// provides"). Distinct from [servings] (the to-serve total) and NOT
  /// redundant: the event copy must freeze it so later catalog edits don't
  /// mutate a planned event. Null for cooked dishes.
  final double? servingsPerUnit;

  bool get isBought => acquisitionMode == DishAcquisitionMode.bought;

  /// Units to buy for a bought dish = ceil(to-serve servings / per-unit
  /// servings), computed from the snapshot alone. Falls back to [servings] if
  /// no per-unit snapshot is present (defensive; bought dishes always have one).
  int get units {
    final perUnit = servingsPerUnit;
    if (perUnit == null || perUnit <= 0) return servings;
    return (servings / perUnit).ceil();
  }

  factory EventDish.fromRow(Map<String, dynamic> row) {
    return EventDish(
      id: row['id'] as String,
      name: row['dish_name'] as String,
      category: DishCategoryWire.parse(row['category'] as String),
      servings: (row['servings'] as num?)?.toInt() ?? 0,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      sourceDishId: row['source_dish_id'] as String?,
      acquisitionMode: DishAcquisitionModeWire.parse(
        row['acquisition_mode'] as String?,
      ),
      supplierCategoryId: row['supplier_category_id'] as String?,
      servingsPerUnit: (row['servings_per_unit'] as num?)?.toDouble(),
    );
  }

  static const String selectColumns =
      'id, dish_name, category, servings, sort_order, source_dish_id, '
      'acquisition_mode, supplier_category_id, servings_per_unit';
}
