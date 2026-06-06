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
      );
    }).toList();
  }

  /// Supplier categories (system rows in the MVP) with their translated
  /// name in [localeCode]. Group-created rows, if any, fall back to code.
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
      return SupplierCategory(id: id, code: code, name: names[id] ?? code);
    }).toList();
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
