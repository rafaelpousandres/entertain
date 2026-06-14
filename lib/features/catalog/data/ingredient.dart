/// Domain model and draft for a catalog `ingredients` row.
///
/// Only the fields exercised by this screen group are modelled. The package
/// equivalence pair (`package_equiv_value` / `package_equiv_unit_id`) is out
/// of scope (Specification 004 §4) and intentionally absent.
library;

class Ingredient {
  const Ingredient({
    required this.id,
    required this.groupId,
    required this.name,
    required this.defaultUnitId,
    this.defaultSupplierCategoryId,
    this.prepDescription,
  });

  final String id;
  final String groupId;
  final String name;
  final String defaultUnitId;
  final String? defaultSupplierCategoryId;
  final String? prepDescription;

  // Spec 010 §2.4: the ingredient's photos now live in the polymorphic `media`
  // table, not a `photo_path` column — the cover is read via
  // entityCoverPathsProvider and the editor uses the shared
  // PhotoCarouselSection. The old `photo_path` column was dropped in Wave 2
  // (Spec 011 §2.2), so it is absent here.

  factory Ingredient.fromRow(Map<String, dynamic> row) {
    return Ingredient(
      id: row['id'] as String,
      groupId: row['group_id'] as String,
      name: row['name'] as String,
      defaultUnitId: row['default_unit_id'] as String,
      defaultSupplierCategoryId: row['default_supplier_category_id'] as String?,
      prepDescription: row['prep_description'] as String?,
    );
  }

  static const String selectColumns =
      'id, group_id, name, default_unit_id, '
      'default_supplier_category_id, prep_description';
}

/// Mutable editor view of an ingredient. Converted to a row payload at save
/// time; `group_id` is added by the repository to keep this struct UI-only.
class IngredientDraft {
  IngredientDraft({
    required this.name,
    this.defaultUnitId,
    this.defaultSupplierCategoryId,
    this.prepDescription,
  });

  factory IngredientDraft.empty() => IngredientDraft(name: '');

  factory IngredientDraft.fromIngredient(Ingredient ingredient) =>
      IngredientDraft(
        name: ingredient.name,
        defaultUnitId: ingredient.defaultUnitId,
        defaultSupplierCategoryId: ingredient.defaultSupplierCategoryId,
        prepDescription: ingredient.prepDescription,
      );

  String name;
  String? defaultUnitId;
  String? defaultSupplierCategoryId;
  String? prepDescription;

  Map<String, dynamic> toRow() {
    return {
      'name': name.trim(),
      'default_unit_id': defaultUnitId,
      'default_supplier_category_id': defaultSupplierCategoryId,
      'prep_description': _nullIfBlank(prepDescription),
    };
  }
}

String? _nullIfBlank(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
