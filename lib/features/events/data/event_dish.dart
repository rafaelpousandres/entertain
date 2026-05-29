/// Minimal read-only view of an `event_dishes` row. Adding / editing
/// dishes belongs to screen group 2; this struct exists only so the
/// detail screen can render the grouped-by-category menu structure when
/// the next group populates it.
library;

import '../../catalog/data/dish_category.dart';

export '../../catalog/data/dish_category.dart'
    show DishCategory, DishCategoryWire, dishCategoryOrder;

class EventDish {
  const EventDish({
    required this.id,
    required this.name,
    required this.category,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final DishCategory category;
  final int sortOrder;

  factory EventDish.fromRow(Map<String, dynamic> row) {
    return EventDish(
      id: row['id'] as String,
      name: row['dish_name'] as String,
      category: DishCategoryWire.parse(row['category'] as String),
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  static const String selectColumns = 'id, dish_name, category, sort_order';
}
