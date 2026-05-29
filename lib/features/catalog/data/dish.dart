/// Domain model and drafts for a catalog `dishes` row and its
/// `dish_ingredients` lines.
///
/// The dish editor works on an in-memory [DishDraft]: the dish fields and
/// the full list of [DishLineDraft] lines are held in memory while editing
/// and committed in one go on save (new lines inserted, an existing dish's
/// lines replaced). Nothing is written line-by-line, so backing out of an
/// unsaved new dish leaves no orphan rows.
library;

import 'dish_category.dart';

class Dish {
  const Dish({
    required this.id,
    required this.groupId,
    required this.name,
    required this.category,
    required this.baseServings,
    this.description,
  });

  final String id;
  final String groupId;
  final String name;
  final DishCategory category;
  final int baseServings;
  final String? description;

  factory Dish.fromRow(Map<String, dynamic> row) {
    return Dish(
      id: row['id'] as String,
      groupId: row['group_id'] as String,
      name: row['name'] as String,
      category: DishCategoryWire.parse(row['category'] as String),
      baseServings: (row['base_servings'] as num?)?.toInt() ?? 4,
      description: row['description'] as String?,
    );
  }

  static const String selectColumns =
      'id, group_id, name, category, base_servings, description';
}

/// One in-memory recipe line being edited inside the dish editor. Maps to a
/// `dish_ingredients` row on save. `sort_order` is not stored here — it is
/// derived from the line's position in the list at save time.
class DishLineDraft {
  DishLineDraft({
    required this.ingredientId,
    required this.ingredientName,
    required this.quantity,
    required this.unitId,
    this.prepNote,
  });

  /// Reference to the catalog ingredient.
  String ingredientId;

  /// Current ingredient name, carried for display in the dish editor list
  /// (the `dish_ingredients` row itself has no name column).
  String ingredientName;

  double quantity;
  String unitId;
  String? prepNote;

  DishLineDraft copy() => DishLineDraft(
    ingredientId: ingredientId,
    ingredientName: ingredientName,
    quantity: quantity,
    unitId: unitId,
    prepNote: prepNote,
  );

  factory DishLineDraft.fromRow(Map<String, dynamic> row) {
    // `ingredients` is an embedded relation (may be null if the referenced
    // ingredient was soft-deleted); fall back gracefully.
    final ingredient = row['ingredients'] as Map<String, dynamic>?;
    return DishLineDraft(
      ingredientId: row['ingredient_id'] as String,
      ingredientName: (ingredient?['name'] as String?) ?? '',
      quantity: (row['quantity'] as num).toDouble(),
      unitId: row['unit_id'] as String,
      prepNote: row['prep_note'] as String?,
    );
  }

  /// Row payload for inserting into `dish_ingredients`. `dish_id` is added
  /// by the repository; `sort_order` is passed in from the list position.
  Map<String, dynamic> toRow({required int sortOrder}) {
    return {
      'ingredient_id': ingredientId,
      'quantity': quantity,
      'unit_id': unitId,
      'prep_note': _nullIfBlank(prepNote),
      'sort_order': sortOrder,
    };
  }

  /// Columns + embedded ingredient name read when loading a dish for edit.
  static const String selectColumns =
      'id, ingredient_id, quantity, unit_id, prep_note, sort_order, '
      'ingredients(name)';
}

/// Mutable editor view of a dish and its lines.
class DishDraft {
  DishDraft({
    required this.name,
    required this.category,
    required this.baseServings,
    this.description,
    List<DishLineDraft>? lines,
  }) : lines = lines ?? [];

  /// Defaults for a brand-new dish: no name, `main` category, 4 servings
  /// (the data model default for `base_servings`).
  factory DishDraft.empty() =>
      DishDraft(name: '', category: DishCategory.main, baseServings: 4);

  factory DishDraft.fromDish(Dish dish, List<DishLineDraft> lines) => DishDraft(
    name: dish.name,
    category: dish.category,
    baseServings: dish.baseServings,
    description: dish.description,
    lines: lines,
  );

  String name;
  DishCategory category;
  int baseServings;
  String? description;
  final List<DishLineDraft> lines;

  /// Row payload for the `dishes` table. `group_id` is added by the
  /// repository; the lines are persisted separately.
  Map<String, dynamic> toRow() {
    return {
      'name': name.trim(),
      'category': category.wire,
      'base_servings': baseServings,
      'description': _nullIfBlank(description),
    };
  }
}

String? _nullIfBlank(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Formats a numeric quantity for display, dropping a redundant `.0` so
/// "200" reads cleanly while "0.5" keeps its decimals.
String formatQuantity(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value
      .toString()
      .replaceAll(RegExp(r'0+$'), '')
      .replaceAll(RegExp(r'\.$'), '');
}
