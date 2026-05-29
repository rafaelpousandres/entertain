import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../events/data/events_providers.dart' show currentGroupIdProvider;
import 'catalog_repository.dart';
import 'dish.dart';
import 'ingredient.dart';
import 'reference_data.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(Supabase.instance.client);
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

/// Active (not soft-deleted) ingredients for the current group, by name.
/// Invalidated after any ingredient mutation.
final ingredientsListProvider = FutureProvider<List<Ingredient>>((ref) async {
  final repo = ref.watch(catalogRepositoryProvider);
  final groupId = await ref.watch(currentGroupIdProvider.future);
  return repo.listIngredients(groupId);
});

final ingredientByIdProvider = FutureProvider.family<Ingredient, String>((
  ref,
  id,
) async {
  return ref.watch(catalogRepositoryProvider).fetchIngredient(id);
});

/// Active (not soft-deleted) dishes for the current group, by name.
final dishesListProvider = FutureProvider<List<Dish>>((ref) async {
  final repo = ref.watch(catalogRepositoryProvider);
  final groupId = await ref.watch(currentGroupIdProvider.future);
  return repo.listDishes(groupId);
});

final dishByIdProvider = FutureProvider.family<Dish, String>((ref, id) async {
  return ref.watch(catalogRepositoryProvider).fetchDish(id);
});

/// Recipe lines of a dish, used to seed the dish editor in edit mode.
final dishLinesProvider = FutureProvider.family<List<DishLineDraft>, String>((
  ref,
  dishId,
) async {
  return ref.watch(catalogRepositoryProvider).listDishLines(dishId);
});
