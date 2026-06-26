import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../events/data/events_providers.dart' show currentGroupIdProvider;
import 'catalog_repository.dart';
import 'diet.dart';
import 'dish.dart';
import 'drink.dart';
import 'ingredient.dart';
import 'reference_data.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(Supabase.instance.client);
});

/// Spec 025 A.4 — the app's display locale code, clamped to the three supported
/// languages (fallback `ca`). The app has no in-app language switch, so the
/// device locale is the app locale; catalog reads use this to localize names.
final localeCodeProvider = Provider<String>((ref) {
  final code = PlatformDispatcher.instance.locale.languageCode;
  return const {'ca', 'es', 'en'}.contains(code) ? code : 'ca';
});

/// System units with names translated to [localeCode] (the UI passes the
/// active locale's language code). Reference data, so it is fetched once
/// per locale and cached for the session.
final unitsProvider = FutureProvider.family<List<Unit>, String>((
  ref,
  localeCode,
) async {
  return ref.watch(catalogRepositoryProvider).listUnits(localeCode);
});

/// System supplier categories with names translated to [localeCode].
final supplierCategoriesProvider =
    FutureProvider.family<List<SupplierCategory>, String>((
      ref,
      localeCode,
    ) async {
      return ref
          .watch(catalogRepositoryProvider)
          .listSupplierCategories(localeCode);
    });

/// Active (not soft-deleted) ingredients for the current group, names localized
/// to the app locale (Spec 025). Invalidated after any ingredient mutation.
final ingredientsListProvider = FutureProvider<List<Ingredient>>((ref) async {
  final repo = ref.watch(catalogRepositoryProvider);
  final groupId = await ref.watch(currentGroupIdProvider.future);
  final locale = ref.watch(localeCodeProvider);
  return repo.listIngredients(groupId, locale);
});

final ingredientByIdProvider = FutureProvider.family<Ingredient, String>((
  ref,
  id,
) async {
  final locale = ref.watch(localeCodeProvider);
  return ref.watch(catalogRepositoryProvider).fetchIngredient(id, locale);
});

/// Active (not soft-deleted) dishes for the current group, names localized.
final dishesListProvider = FutureProvider<List<Dish>>((ref) async {
  final repo = ref.watch(catalogRepositoryProvider);
  final groupId = await ref.watch(currentGroupIdProvider.future);
  final locale = ref.watch(localeCodeProvider);
  return repo.listDishes(groupId, locale);
});

final dishByIdProvider = FutureProvider.family<Dish, String>((ref, id) async {
  final locale = ref.watch(localeCodeProvider);
  return ref.watch(catalogRepositoryProvider).fetchDish(id, locale);
});

/// Active (not soft-deleted) drinks for the current group, names localized.
final drinksListProvider = FutureProvider<List<Drink>>((ref) async {
  final repo = ref.watch(catalogRepositoryProvider);
  final groupId = await ref.watch(currentGroupIdProvider.future);
  final locale = ref.watch(localeCodeProvider);
  return repo.listDrinks(groupId, locale);
});

final drinkByIdProvider = FutureProvider.family<Drink, String>((ref, id) async {
  final locale = ref.watch(localeCodeProvider);
  return ref.watch(catalogRepositoryProvider).fetchDrink(id, locale);
});

/// Recipe lines of a dish, used to seed the dish editor in edit mode.
final dishLinesProvider = FutureProvider.family<List<DishLineDraft>, String>((
  ref,
  dishId,
) async {
  return ref.watch(catalogRepositoryProvider).listDishLines(dishId);
});

/// Spec 025 B.3/C — the derived dietary status per dish that has ingredients,
/// for the catalog filter and badges. Dishes absent here use their manual
/// fields. Invalidated alongside the dish list when recipes/ingredients change.
final dishDietMapProvider =
    FutureProvider<Map<String, ({DietLevel diet, TriState gf})>>((ref) async {
  final repo = ref.watch(catalogRepositoryProvider);
  final groupId = await ref.watch(currentGroupIdProvider.future);
  return repo.dishDietByDish(groupId);
});

/// Spec 025 Part C — the active dish-catalog filter (dietary chips + acquisition).
class CatalogFilter {
  const CatalogFilter({this.diet = const {}, this.acquisition});

  final Set<DietChip> diet;
  final DishAcquisitionMode? acquisition;

  bool get isEmpty => diet.isEmpty && acquisition == null;

  CatalogFilter copyWith({
    Set<DietChip>? diet,
    DishAcquisitionMode? acquisition,
    bool clearAcquisition = false,
  }) => CatalogFilter(
    diet: diet ?? this.diet,
    acquisition: clearAcquisition ? null : (acquisition ?? this.acquisition),
  );
}

class CatalogFilterNotifier extends Notifier<CatalogFilter> {
  @override
  CatalogFilter build() => const CatalogFilter();

  void toggleDiet(DietChip chip) {
    final next = {...state.diet};
    next.contains(chip) ? next.remove(chip) : next.add(chip);
    state = state.copyWith(diet: next);
  }

  /// Toggle the acquisition filter: tapping the active mode clears it.
  void toggleAcquisition(DishAcquisitionMode mode) {
    state = state.acquisition == mode
        ? state.copyWith(clearAcquisition: true)
        : state.copyWith(acquisition: mode);
  }

  void clear() => state = const CatalogFilter();
}

final catalogFilterProvider =
    NotifierProvider<CatalogFilterNotifier, CatalogFilter>(
  CatalogFilterNotifier.new,
);
