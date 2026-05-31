/// Read model for an `event_dishes` row — the per-event snapshot of a
/// catalog dish (the "copy on add" decision, data model §3.3).
///
/// `sourceDishId` is provenance only: it records which catalog dish the copy
/// came from (used by the picker to flag dishes already in the menu), but is
/// never followed to re-read or sync — the snapshot is independent of the
/// catalog from the moment it is created.
library;

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
  });

  final String id;
  final String name;
  final DishCategory category;
  final int servings;
  final int sortOrder;

  /// Catalog dish this copy originated from. Nullable — the FK is
  /// `on delete set null`, and a soft-deleted catalog dish keeps it.
  final String? sourceDishId;

  factory EventDish.fromRow(Map<String, dynamic> row) {
    return EventDish(
      id: row['id'] as String,
      name: row['dish_name'] as String,
      category: DishCategoryWire.parse(row['category'] as String),
      servings: (row['servings'] as num?)?.toInt() ?? 0,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      sourceDishId: row['source_dish_id'] as String?,
    );
  }

  static const String selectColumns =
      'id, dish_name, category, servings, sort_order, source_dish_id';
}
