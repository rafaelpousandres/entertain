/// Minimal read-only view of an `event_dishes` row. Adding / editing
/// dishes belongs to screen group 2; this struct exists only so the
/// detail screen can render the grouped-by-category menu structure when
/// the next group populates it.
library;

enum DishCategory { aperitif, starter, main, dessert, drink, other }

extension DishCategoryWire on DishCategory {
  static DishCategory parse(String value) => switch (value) {
    'aperitif' => DishCategory.aperitif,
    'starter' => DishCategory.starter,
    'main' => DishCategory.main,
    'dessert' => DishCategory.dessert,
    'drink' => DishCategory.drink,
    _ => DishCategory.other,
  };
}

/// Canonical order used to render section headers. Mirrors a typical
/// menu flow rather than the enum's declaration order — both happen to
/// agree today, but the explicit list keeps the UI from drifting if the
/// enum is reordered for storage reasons later.
const List<DishCategory> dishCategoryOrder = [
  DishCategory.aperitif,
  DishCategory.starter,
  DishCategory.main,
  DishCategory.dessert,
  DishCategory.drink,
  DishCategory.other,
];

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
