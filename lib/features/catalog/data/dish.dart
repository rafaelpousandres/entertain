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

/// How a dish is obtained (Spec 014 §2.1). `cooked` is the existing recipe
/// path (ingredients with quantities); `bought` is a prepared dish acquired
/// from a supplier as a single purchase line — no ingredients.
enum DishAcquisitionMode { cooked, bought }

extension DishAcquisitionModeWire on DishAcquisitionMode {
  String get wire => switch (this) {
    DishAcquisitionMode.cooked => 'cooked',
    DishAcquisitionMode.bought => 'bought',
  };

  static DishAcquisitionMode parse(String? value) => value == 'bought'
      ? DishAcquisitionMode.bought
      : DishAcquisitionMode.cooked;
}

class Dish {
  const Dish({
    required this.id,
    required this.groupId,
    required this.name,
    required this.category,
    required this.baseServings,
    this.acquisitionMode = DishAcquisitionMode.cooked,
    this.supplierCategoryId,
    this.purchaseUnit,
    this.servingsPerUnit,
    this.description,
    this.preparation,
  });

  final String id;
  final String groupId;
  final String name;
  final DishCategory category;
  final int baseServings;

  /// Spec 014 §2.1: cooked (recipe) or bought (prepared). The four fields
  /// below are used only when [acquisitionMode] is bought.
  final DishAcquisitionMode acquisitionMode;

  /// The supplier category a bought dish is ordered from (resolved to a
  /// concrete supplier at order time, Spec 013).
  final String? supplierCategoryId;

  /// Optional free-text purchase unit for a bought dish (e.g. "safata").
  final String? purchaseUnit;

  /// Optional servings one purchase unit provides; with [purchaseUnit] it lets
  /// the shopping line compute units to buy = ceil(scaledServings / this).
  final double? servingsPerUnit;

  /// One-line subtitle / brief identification of the dish.
  final String? description;

  /// Multi-line recipe / cooking instructions (Spec 006 §2.1), separate from
  /// the short [description].
  final String? preparation;

  bool get isBought => acquisitionMode == DishAcquisitionMode.bought;

  // Spec 010 §2.4: the dish's photos now live in the polymorphic `media` table,
  // not a `photo_path` column — the cover is read via entityCoverPathsProvider
  // and the editor uses the shared PhotoCarouselSection. The old `photo_path`
  // column was dropped in Wave 2 (Spec 011 §2.2), so it is absent here.

  factory Dish.fromRow(Map<String, dynamic> row) {
    return Dish(
      id: row['id'] as String,
      groupId: row['group_id'] as String,
      name: row['name'] as String,
      category: DishCategoryWire.parse(row['category'] as String),
      baseServings: (row['base_servings'] as num?)?.toInt() ?? 4,
      acquisitionMode: DishAcquisitionModeWire.parse(
        row['acquisition_mode'] as String?,
      ),
      supplierCategoryId: row['supplier_category_id'] as String?,
      purchaseUnit: row['purchase_unit'] as String?,
      servingsPerUnit: (row['servings_per_unit'] as num?)?.toDouble(),
      description: row['description'] as String?,
      preparation: row['preparation'] as String?,
    );
  }

  static const String selectColumns =
      'id, group_id, name, category, base_servings, acquisition_mode, '
      'supplier_category_id, purchase_unit, servings_per_unit, description, '
      'preparation';
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
    this.acquisitionMode = DishAcquisitionMode.cooked,
    this.supplierCategoryId,
    this.purchaseUnit,
    this.servingsPerUnit,
    this.description,
    this.preparation,
    List<DishLineDraft>? lines,
  }) : lines = lines ?? [];

  /// Defaults for a brand-new dish: no name, `main` category, 4 servings
  /// (the data model default for `base_servings`), cooked.
  factory DishDraft.empty() =>
      DishDraft(name: '', category: DishCategory.main, baseServings: 4);

  factory DishDraft.fromDish(Dish dish, List<DishLineDraft> lines) => DishDraft(
    name: dish.name,
    category: dish.category,
    baseServings: dish.baseServings,
    acquisitionMode: dish.acquisitionMode,
    supplierCategoryId: dish.supplierCategoryId,
    purchaseUnit: dish.purchaseUnit,
    servingsPerUnit: dish.servingsPerUnit,
    description: dish.description,
    preparation: dish.preparation,
    lines: lines,
  );

  String name;
  DishCategory category;
  int baseServings;
  DishAcquisitionMode acquisitionMode;
  String? supplierCategoryId;
  String? purchaseUnit;
  double? servingsPerUnit;
  String? description;
  String? preparation;
  final List<DishLineDraft> lines;

  bool get isBought => acquisitionMode == DishAcquisitionMode.bought;

  /// Row payload for the `dishes` table. `group_id` is added by the
  /// repository; the lines are persisted separately. The bought-only fields
  /// are nulled when cooked so a dish switched back to cooked drops its stale
  /// supplier/unit, while its ingredient lines are preserved (§2.1).
  Map<String, dynamic> toRow() {
    final bought = isBought;
    return {
      'name': name.trim(),
      'category': category.wire,
      'base_servings': baseServings,
      'acquisition_mode': acquisitionMode.wire,
      'supplier_category_id': bought ? supplierCategoryId : null,
      'purchase_unit': bought ? _nullIfBlank(purchaseUnit) : null,
      'servings_per_unit': bought ? servingsPerUnit : null,
      'description': _nullIfBlank(description),
      'preparation': _nullIfBlank(preparation),
    };
  }
}

String? _nullIfBlank(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Trims a redundant `.0` from an integral servings-per-unit for editor fields
/// (Spec 014). Shared by the dish and drink editors.
String formatServingsPerUnit(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toString();

/// Formats a numeric quantity for display, dropping a redundant `.0` so
/// "200" reads cleanly while "0.5" keeps its decimals.
///
/// Defense-in-depth against IEEE-754 noise (Spec 008 §2.10, PR #22): this is the
/// single funnel every quantity passes through on its way to the user, so it
/// also scrubs binary-float tails. A `2.4` that materialised as
/// `2.4000000000000004`, or a `0.4` that fell out of a subtraction as
/// `0.39999999999999997`, is snapped back to its real value before formatting —
/// so even if some future quantity calc forgets to round, the user never sees a
/// long decimal tail. Upstream calls (e.g. [scaleServingQuantity]) still round
/// to their domain precision; this only guards the last mile.
///
/// Trailing zeros are dropped ("2.40" → "2.4"). [decimalSeparator] sets the
/// radix mark so comma locales (Catalan, Spanish) read "2,4" while English
/// reads "2.4"; resolve it from a locale with [quantityDecimalSeparator].
String formatQuantity(double value, {String decimalSeparator = '.'}) {
  if (!value.isFinite) return value.toString();
  // Keep 12 significant figures — far beyond any real domestic quantity — so a
  // binary-float tail in the 16th digit vanishes without touching legitimate
  // precision (a measured line is already at 2 significant figures upstream).
  final clean = double.parse(value.toStringAsPrecision(12));
  if (clean == clean.roundToDouble()) {
    return clean.toInt().toString();
  }
  final text = clean
      .toString()
      .replaceAll(RegExp(r'0+$'), '')
      .replaceAll(RegExp(r'\.$'), '');
  return decimalSeparator == '.'
      ? text
      : text.replaceFirst('.', decimalSeparator);
}

/// The decimal separator a [languageCode] expects: a comma for Catalan and
/// Spanish, a point for English (the project's three base languages). Quantity
/// input fields normalise both back to a point on parse, so a localized comma
/// round-trips safely.
String quantityDecimalSeparator(String languageCode) =>
    languageCode == 'en' ? '.' : ',';
