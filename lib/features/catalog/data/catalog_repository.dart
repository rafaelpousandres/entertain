import 'package:supabase_flutter/supabase_flutter.dart';

import 'catalog_naming.dart';
import 'diet.dart';
import 'dish.dart';
import 'drink.dart';
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

  /// Spec 025 A.4 — the app-locale and English name maps for a catalog entity
  /// type, used to localize the display name and supply the D2 English bridge.
  /// One extra query per list (English is skipped when the locale already is en).
  Future<({Map<String, String> local, Map<String, String> en})> _nameMaps(
    String entityType,
    String localeCode,
  ) async {
    final local = await _translationNames(entityType, localeCode);
    final en = localeCode == 'en'
        ? local
        : await _translationNames(entityType, 'en');
    return (local: local, en: en);
  }

  /// Spec 025 A.2/A.3 — fire the un-metered `translate-name` Edge Function so an
  /// entity's name exists in all three locales. Best-effort: a failure never
  /// blocks the save (the typed name is the original; a later backfill fills the
  /// rest). The client cannot write `translations` directly (service-role only),
  /// so this must go through the server.
  Future<void> _ensureNameI18n(
    String entityType,
    String entityId,
    String name,
    String localeCode,
  ) async {
    try {
      await _client.functions.invoke(
        'translate-name',
        body: {
          'entity_type': entityType,
          'entity_id': entityId,
          'name': name.trim(),
          'locale': localeCode,
        },
      );
    } catch (_) {
      // Best-effort i18n; the backfill (or a later edit) can fill the gap.
    }
  }

  /// Spec 025 B.3 — derived dietary status per dish that HAS ingredients, from a
  /// single grouped read of the group's `dish_ingredients` joined to the
  /// ingredients' axes. Dishes with no ingredients are absent (the caller uses
  /// their manual fields).
  Future<Map<String, ({DietLevel diet, TriState gf})>> dishDietByDish(
    String groupId,
  ) async {
    final rows = await _client
        .from('dish_ingredients')
        .select('dish_id, ingredients!inner(diet, gluten_free, group_id)')
        .eq('ingredients.group_id', groupId);
    final diets = <String, List<DietLevel>>{};
    final gfs = <String, List<TriState>>{};
    for (final r in rows as List) {
      final row = r as Map<String, dynamic>;
      final dishId = row['dish_id'] as String;
      final ing = row['ingredients'] as Map<String, dynamic>?;
      if (ing == null) continue;
      (diets[dishId] ??= []).add(DietLevelWire.parse(ing['diet'] as String?));
      (gfs[dishId] ??= []).add(TriStateWire.parse(ing['gluten_free'] as String?));
    }
    return {
      for (final dishId in diets.keys)
        dishId: (
          diet: deriveDishDiet(diets[dishId]!),
          gf: deriveDishGlutenFree(gfs[dishId]!),
        ),
    };
  }

  // --- Ingredients -------------------------------------------------------

  Future<List<Ingredient>> listIngredients(
    String groupId,
    String localeCode,
  ) async {
    final rows = await _client
        .from('ingredients')
        .select(Ingredient.selectColumns)
        .eq('group_id', groupId)
        .filter('deleted_at', 'is', null)
        .order('name', ascending: true);
    final names = await _nameMaps('ingredient', localeCode);
    final list = (rows as List).map((r) {
      final row = r as Map<String, dynamic>;
      final id = row['id'] as String;
      return Ingredient.fromRow(
        row,
        displayName: localizedName(names.local[id], row['name'] as String),
        nameEn: names.en[id],
      );
    }).toList();
    // Sort by the localized display name (the query ordered by the raw name).
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<Ingredient> fetchIngredient(String id, String localeCode) async {
    final row = await _client
        .from('ingredients')
        .select(Ingredient.selectColumns)
        .eq('id', id)
        .filter('deleted_at', 'is', null)
        .maybeSingle();
    if (row == null) {
      throw StateError('Ingredient not found.');
    }
    final names = await _nameMaps('ingredient', localeCode);
    return Ingredient.fromRow(
      row,
      displayName: localizedName(names.local[id], row['name'] as String),
      nameEn: names.en[id],
    );
  }

  Future<Ingredient> createIngredient(
    IngredientDraft draft, {
    required String groupId,
    required String localeCode,
  }) async {
    final row = await _client
        .from('ingredients')
        .insert({
          ...draft.toRow(),
          'group_id': groupId,
          'original_locale': localeCode,
        })
        .select(Ingredient.selectColumns)
        .single();
    final ingredient = Ingredient.fromRow(row);
    await _ensureNameI18n('ingredient', ingredient.id, ingredient.name, localeCode);
    return ingredient;
  }

  Future<Ingredient> updateIngredient(
    String id,
    IngredientDraft draft, {
    required String localeCode,
    required bool nameChanged,
  }) async {
    final row = await _client
        .from('ingredients')
        .update({
          ...draft.toRow(),
          // A name edit re-establishes the editing locale as the original and
          // triggers a fresh translation (Spec 025 A.2). Dietary-only edits
          // leave the i18n untouched (no wasted AI call).
          if (nameChanged) 'original_locale': localeCode,
        })
        .eq('id', id)
        .select(Ingredient.selectColumns)
        .single();
    final ingredient = Ingredient.fromRow(row);
    if (nameChanged) {
      await _ensureNameI18n('ingredient', id, ingredient.name, localeCode);
    }
    return ingredient;
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

  /// Soft delete — `ingredients` is marked 🗑 in the data model, and catalog
  /// rows are referenced from event snapshots, so the row is kept.
  ///
  /// NOTE (Spec 025, captured for a future cleanup — not fixed here): the
  /// entity's `translations` name rows are polymorphic (no FK), so deleting an
  /// ingredient/dish/drink leaves its translation rows ORPHANED. Minor garbage;
  /// a future maintenance pass can sweep translations with no live entity.
  Future<void> deleteIngredient(String id) async {
    await _client
        .from('ingredients')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  // --- Dishes ------------------------------------------------------------

  Future<List<Dish>> listDishes(String groupId, String localeCode) async {
    final rows = await _client
        .from('dishes')
        .select(Dish.selectColumns)
        .eq('group_id', groupId)
        .filter('deleted_at', 'is', null)
        .order('name', ascending: true);
    final names = await _nameMaps('dish', localeCode);
    final list = (rows as List).map((r) {
      final row = r as Map<String, dynamic>;
      final id = row['id'] as String;
      return Dish.fromRow(
        row,
        displayName: localizedName(names.local[id], row['name'] as String),
        nameEn: names.en[id],
      );
    }).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<Dish> fetchDish(String id, String localeCode) async {
    final row = await _client
        .from('dishes')
        .select(Dish.selectColumns)
        .eq('id', id)
        .filter('deleted_at', 'is', null)
        .maybeSingle();
    if (row == null) {
      throw StateError('Dish not found.');
    }
    final names = await _nameMaps('dish', localeCode);
    return Dish.fromRow(
      row,
      displayName: localizedName(names.local[id], row['name'] as String),
      nameEn: names.en[id],
    );
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

  Future<Dish> createDish(
    DishDraft draft, {
    required String groupId,
    required String localeCode,
  }) async {
    final row = await _client
        .from('dishes')
        .insert({
          ...draft.toRow(),
          'group_id': groupId,
          'original_locale': localeCode,
        })
        .select(Dish.selectColumns)
        .single();
    final dish = Dish.fromRow(row);
    // §2.1: only a cooked dish owns ingredient lines.
    if (!draft.isBought) await _replaceLines(dish.id, draft.lines);
    await _ensureNameI18n('dish', dish.id, dish.name, localeCode);
    return dish;
  }

  Future<Dish> updateDish(
    String id,
    DishDraft draft, {
    required String localeCode,
    required bool nameChanged,
  }) async {
    final row = await _client
        .from('dishes')
        .update({
          ...draft.toRow(),
          if (nameChanged) 'original_locale': localeCode,
        })
        .eq('id', id)
        .select(Dish.selectColumns)
        .single();
    // §2.1: a bought dish keeps its (hidden) ingredient lines untouched, so
    // switching the toggle back to cooked restores them — no data loss. Only a
    // cooked dish replaces its lines from the editor.
    if (!draft.isBought) await _replaceLines(id, draft.lines);
    final dish = Dish.fromRow(row);
    if (nameChanged) await _ensureNameI18n('dish', id, dish.name, localeCode);
    return dish;
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

  // --- Drinks (Spec 014 §2.2) -------------------------------------------
  // A drink is the bought-item shape without ingredients, so its CRUD mirrors
  // dishes minus the recipe lines.

  Future<List<Drink>> listDrinks(String groupId, String localeCode) async {
    final rows = await _client
        .from('drinks')
        .select(Drink.selectColumns)
        .eq('group_id', groupId)
        .filter('deleted_at', 'is', null)
        .order('name', ascending: true);
    final names = await _nameMaps('drink', localeCode);
    final list = (rows as List).map((r) {
      final row = r as Map<String, dynamic>;
      final id = row['id'] as String;
      return Drink.fromRow(
        row,
        displayName: localizedName(names.local[id], row['name'] as String),
        nameEn: names.en[id],
      );
    }).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<Drink> fetchDrink(String id, String localeCode) async {
    final row = await _client
        .from('drinks')
        .select(Drink.selectColumns)
        .eq('id', id)
        .filter('deleted_at', 'is', null)
        .maybeSingle();
    if (row == null) {
      throw StateError('Drink not found.');
    }
    final names = await _nameMaps('drink', localeCode);
    return Drink.fromRow(
      row,
      displayName: localizedName(names.local[id], row['name'] as String),
      nameEn: names.en[id],
    );
  }

  Future<Drink> createDrink(
    DrinkDraft draft, {
    required String groupId,
    required String localeCode,
  }) async {
    final row = await _client
        .from('drinks')
        .insert({
          ...draft.toRow(),
          'group_id': groupId,
          'original_locale': localeCode,
        })
        .select(Drink.selectColumns)
        .single();
    final drink = Drink.fromRow(row);
    await _ensureNameI18n('drink', drink.id, drink.name, localeCode);
    return drink;
  }

  Future<Drink> updateDrink(
    String id,
    DrinkDraft draft, {
    required String localeCode,
    required bool nameChanged,
  }) async {
    final row = await _client
        .from('drinks')
        .update({
          ...draft.toRow(),
          if (nameChanged) 'original_locale': localeCode,
        })
        .eq('id', id)
        .select(Drink.selectColumns)
        .single();
    final drink = Drink.fromRow(row);
    if (nameChanged) await _ensureNameI18n('drink', id, drink.name, localeCode);
    return drink;
  }

  Future<void> deleteDrink(String id) async {
    await _client
        .from('drinks')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }
}
