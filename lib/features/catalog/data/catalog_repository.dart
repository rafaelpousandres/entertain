import 'package:supabase_flutter/supabase_flutter.dart';

import 'dish.dart';
import 'ingredient.dart';
import 'reference_data.dart';

/// Data-access wrapper for the menu catalog: the system reference tables
/// (`units`, `supplier_categories`), the group's `ingredients`, and the
/// group's `dishes` with their `dish_ingredients` lines.
///
/// Row-level security (spec 002) scopes every group table to the caller's
/// group; system reference rows (`group_id` null) are readable by any
/// authenticated user. Display names for the system catalogs come from the
/// `translations` table in the requested locale.
class CatalogRepository {
  CatalogRepository(this._client);

  final SupabaseClient _client;

  // --- Reference catalogs (system content) -------------------------------

  /// Units with their translated name in [localeCode] (e.g. "g", "unitat").
  /// Falls back to the unit code if a translation is missing.
  Future<List<Unit>> listUnits(String localeCode) async {
    final rows = await _client.from('units').select(Unit.selectColumns);
    final names = await _translationNames('unit', localeCode);

    return (rows as List).map((r) {
      final row = r as Map<String, dynamic>;
      final id = row['id'] as String;
      final code = row['code'] as String;
      return Unit(
        id: id,
        code: code,
        magnitude: UnitMagnitudeWire.parse(row['magnitude'] as String),
        name: names[id] ?? code,
        omitInDisplay: row['omit_in_display'] as bool? ?? false,
      );
    }).toList();
  }

  /// Supplier categories visible to the caller: the system seed (shared) plus
  /// the caller's own user categories (RLS gates the rows). System rows take
  /// their display name from `translations` in [localeCode]; user rows take it
  /// from their monolingual `name` column (Spec 007 §2.3).
  Future<List<SupplierCategory>> listSupplierCategories(
    String localeCode,
  ) async {
    final rows = await _client
        .from('supplier_categories')
        .select(SupplierCategory.selectColumns);
    final names = await _translationNames('supplier_category', localeCode);

    return (rows as List).map((r) {
      final row = r as Map<String, dynamic>;
      final id = row['id'] as String;
      final code = row['code'] as String;
      final isSystem = row['is_system'] as bool? ?? false;
      final groupId = row['group_id'] as String?;
      final userName = (row['name'] as String?)?.trim();
      final display = (userName != null && userName.isNotEmpty)
          ? userName
          : (names[id] ?? code);
      return SupplierCategory(
        id: id,
        code: code,
        name: display,
        isSystem: isSystem,
        groupId: groupId,
      );
    }).toList();
  }

  /// Creates a user supplier category for the group (Spec 007 §2.3). The name
  /// is monolingual (the locale the user typed it in). `code` must be unique
  /// within the group but is never shown — the `name` column drives display —
  /// so a timestamp-based code is sufficient.
  Future<void> createUserSupplierCategory({
    required String groupId,
    required String name,
  }) async {
    await _client.from('supplier_categories').insert({
      'group_id': groupId,
      'code': 'user_${DateTime.now().microsecondsSinceEpoch}',
      'is_system': false,
      'name': name.trim(),
    });
  }

  /// Renames a user category (current-locale-only monolingual name).
  Future<void> updateUserSupplierCategoryName(String id, String name) async {
    await _client
        .from('supplier_categories')
        .update({'name': name.trim()})
        .eq('id', id);
  }

  /// Deletes a user category (Spec 007 §2.3). `event_dish_ingredients`
  /// references it with `on delete restrict`, so the assignments are cleared to
  /// null first (RLS scopes the update to the caller's own events — those lines
  /// then surface under "Sense categoria"). `ingredients.default_supplier_
  /// category_id` is `on delete set null` and `group_supplier_settings`
  /// cascades, so neither needs manual cleanup.
  Future<void> deleteUserSupplierCategory(String id) async {
    await _client
        .from('event_dish_ingredients')
        .update({'supplier_category_id': null})
        .eq('supplier_category_id', id);
    await _client.from('supplier_categories').delete().eq('id', id);
  }

  /// entity_id → translated text map for a translation entity type and
  /// locale, restricted to the `name` field.
  Future<Map<String, String>> _translationNames(
    String entityType,
    String localeCode,
  ) async {
    final rows = await _client
        .from('translations')
        .select('entity_id, text')
        .eq('entity_type', entityType)
        .eq('locale', localeCode)
        .eq('field', 'name');
    return {
      for (final r in rows as List)
        (r as Map<String, dynamic>)['entity_id'] as String:
            r['text'] as String,
    };
  }

  // --- Ingredients -------------------------------------------------------

  Future<List<Ingredient>> listIngredients(String groupId) async {
    final rows = await _client
        .from('ingredients')
        .select(Ingredient.selectColumns)
        .eq('group_id', groupId)
        .filter('deleted_at', 'is', null)
        .order('name', ascending: true);
    return (rows as List)
        .map((r) => Ingredient.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<Ingredient> fetchIngredient(String id) async {
    final row = await _client
        .from('ingredients')
        .select(Ingredient.selectColumns)
        .eq('id', id)
        .filter('deleted_at', 'is', null)
        .maybeSingle();
    if (row == null) {
      throw StateError('Ingredient not found.');
    }
    return Ingredient.fromRow(row);
  }

  Future<Ingredient> createIngredient(
    IngredientDraft draft, {
    required String groupId,
  }) async {
    final row = await _client
        .from('ingredients')
        .insert({...draft.toRow(), 'group_id': groupId})
        .select(Ingredient.selectColumns)
        .single();
    return Ingredient.fromRow(row);
  }

  Future<Ingredient> updateIngredient(String id, IngredientDraft draft) async {
    final row = await _client
        .from('ingredients')
        .update(draft.toRow())
        .eq('id', id)
        .select(Ingredient.selectColumns)
        .single();
    return Ingredient.fromRow(row);
  }

  /// Sets an ingredient's default supplier category (Spec 008 §2.5). The
  /// catalog model holds the supplier category on the `ingredients` row, not per
  /// dish line, so setting it from the line editor is catalog-wide: it affects
  /// every dish and future event that uses this ingredient. Passing null clears
  /// it ("Sense categoria").
  Future<void> updateIngredientDefaultSupplierCategory(
    String id,
    String? supplierCategoryId,
  ) async {
    await _client
        .from('ingredients')
        .update({'default_supplier_category_id': supplierCategoryId})
        .eq('id', id);
  }

  /// Records (or clears, when [path] is null) the ingredient's main photo path
  /// after the blob has been uploaded to / removed from the `ingredient-photos`
  /// bucket (Spec 009 §2.2).
  Future<void> setIngredientPhotoPath(String id, String? path) async {
    await _client
        .from('ingredients')
        .update({'photo_path': path})
        .eq('id', id);
  }

  /// Soft delete — `ingredients` is marked 🗑 in the data model, and catalog
  /// rows are referenced from event snapshots, so the row is kept.
  Future<void> deleteIngredient(String id) async {
    await _client
        .from('ingredients')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  // --- Dishes ------------------------------------------------------------

  Future<List<Dish>> listDishes(String groupId) async {
    final rows = await _client
        .from('dishes')
        .select(Dish.selectColumns)
        .eq('group_id', groupId)
        .filter('deleted_at', 'is', null)
        .order('name', ascending: true);
    return (rows as List)
        .map((r) => Dish.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<Dish> fetchDish(String id) async {
    final row = await _client
        .from('dishes')
        .select(Dish.selectColumns)
        .eq('id', id)
        .filter('deleted_at', 'is', null)
        .maybeSingle();
    if (row == null) {
      throw StateError('Dish not found.');
    }
    return Dish.fromRow(row);
  }

  /// Recipe lines of a dish, ordered by `sort_order`, with the current
  /// ingredient name embedded for display.
  Future<List<DishLineDraft>> listDishLines(String dishId) async {
    final rows = await _client
        .from('dish_ingredients')
        .select(DishLineDraft.selectColumns)
        .eq('dish_id', dishId)
        .order('sort_order', ascending: true);
    return (rows as List)
        .map((r) => DishLineDraft.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<Dish> createDish(DishDraft draft, {required String groupId}) async {
    final row = await _client
        .from('dishes')
        .insert({...draft.toRow(), 'group_id': groupId})
        .select(Dish.selectColumns)
        .single();
    final dish = Dish.fromRow(row);
    await _replaceLines(dish.id, draft.lines);
    return dish;
  }

  Future<Dish> updateDish(String id, DishDraft draft) async {
    final row = await _client
        .from('dishes')
        .update(draft.toRow())
        .eq('id', id)
        .select(Dish.selectColumns)
        .single();
    await _replaceLines(id, draft.lines);
    return Dish.fromRow(row);
  }

  /// Records (or clears, when [path] is null) the dish's main photo path after
  /// the blob has been uploaded to / removed from the `dish-photos` bucket
  /// (Spec 009 §2.2).
  Future<void> setDishPhotoPath(String id, String? path) async {
    await _client.from('dishes').update({'photo_path': path}).eq('id', id);
  }

  /// Soft delete the dish. Its `dish_ingredients` are left in place — they
  /// are not exposed once the dish is hidden, and event snapshots are
  /// independent copies, so there is nothing to cascade.
  Future<void> deleteDish(String id) async {
    await _client
        .from('dishes')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  /// Appends a single line to a catalog dish's recipe (Spec 006 §2.2, the
  /// "promote to recipe" path). Used when the user adds an ad-hoc line to an
  /// event's copy of a dish and ticks the checkbox to also write it to the
  /// catalog recipe pointed to by `event_dishes.source_dish_id`. The new
  /// `sort_order` appends after the existing lines.
  Future<void> addDishIngredientLine(
    String dishId, {
    required String ingredientId,
    required double quantity,
    required String unitId,
    String? prepNote,
  }) async {
    final existing = await _client
        .from('dish_ingredients')
        .select('sort_order')
        .eq('dish_id', dishId);
    var nextOrder = 0;
    for (final r in existing as List) {
      final so = ((r as Map<String, dynamic>)['sort_order'] as num?)?.toInt();
      if (so != null && so >= nextOrder) nextOrder = so + 1;
    }
    await _client.from('dish_ingredients').insert({
      'dish_id': dishId,
      'ingredient_id': ingredientId,
      'quantity': quantity,
      'unit_id': unitId,
      'prep_note': prepNote,
      'sort_order': nextOrder,
    });
  }

  /// Replaces a dish's recipe lines with the draft's lines. `dish_ingredients`
  /// is not soft-deleted and is referenced by nothing in this screen group
  /// (event copies are independent), so a delete-and-reinsert keyed off the
  /// list position is the simplest correct way to persist edits, additions
  /// and removals in one pass.
  Future<void> _replaceLines(String dishId, List<DishLineDraft> lines) async {
    await _client.from('dish_ingredients').delete().eq('dish_id', dishId);
    if (lines.isEmpty) return;
    final payload = [
      for (var i = 0; i < lines.length; i++)
        {...lines[i].toRow(sortOrder: i), 'dish_id': dishId},
    ];
    await _client.from('dish_ingredients').insert(payload);
  }
}
