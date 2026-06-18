import 'package:entertain/features/catalog/data/denomination.dart';
import 'package:entertain/features/catalog/data/dish.dart'
    show DishAcquisitionMode;
import 'package:entertain/features/events/data/event_dish.dart';
import 'package:entertain/features/events/data/event_drink.dart';
import 'package:entertain/features/events/data/menu_totals.dart';
import 'package:entertain/features/shopping/data/ingredient_state.dart';
import 'package:entertain/features/shopping/data/purchase_line.dart';
import 'package:entertain/features/shopping/data/shopping_aggregation.dart';
import 'package:entertain/features/shopping/data/shopping_delta.dart';
import 'package:entertain/features/shopping/data/shopping_models.dart';
import 'package:entertain/l10n/app_localizations_ca.dart';
import 'package:entertain/l10n/app_localizations_en.dart';
import 'package:entertain/l10n/app_localizations_es.dart';
import 'package:flutter_test/flutter_test.dart';

/// Specification 016 — prepared dishes & drinks refinements. Pure-logic
/// acceptance: a bought dish's units = ceil(servings / servings-per-unit); a
/// drink's unit quantity is manual (no guest scaling); the denomination plural
/// renders per locale and count; food totals count bought dishes while drinks
/// are excluded; purchase lines flow through shopping as one line per item,
/// grouped by supplier and never merged.

void main() {
  group('boughtDishUnits (ceil of servings / servings-per-unit)', () {
    test('rounds up to the next whole unit', () {
      // 8 servings, 6 per unit → 2 units.
      expect(boughtDishUnits(8, 6), 2);
    });

    test('exact division does not over-round', () {
      expect(boughtDishUnits(12, 6), 2);
    });

    test('falls back to servings with no per-unit snapshot', () {
      expect(boughtDishUnits(5, null), 5);
      expect(boughtDishUnits(5, 0), 5);
    });

    test('EventDish.units computes from the snapshot alone', () {
      const dish = EventDish(
        id: 'd',
        name: 'Canelons',
        category: DishCategory.main,
        servings: 8,
        sortOrder: 0,
        acquisitionMode: DishAcquisitionMode.bought,
        servingsPerUnit: 6,
      );
      expect(dish.units, 2);
    });
  });

  group('drink quantity is manual (no guest scaling)', () {
    test('the default unit quantity is 1', () {
      expect(defaultEventDrinkQuantity, 1);
    });

    test('EventDrink keeps the quantity as set, regardless of any guest count',
        () {
      const drink = EventDrink(
        id: 'x',
        name: 'Vi negre',
        quantity: 3,
        sortOrder: 0,
        denomination: 'bottle',
      );
      expect(drink.quantity, 3);
    });
  });

  group('denomination plural rendering (ca/es/en)', () {
    test('Catalan singular vs plural', () {
      final ca = AppLocalizationsCa();
      expect(denominationCount(ca, 'bottle', 1), '1 ampolla');
      expect(denominationCount(ca, 'bottle', 2), '2 ampolles');
      expect(denominationUnitNoun(ca, 'bottle', 1), 'ampolla');
      expect(denominationUnitNoun(ca, 'bottle', 2), 'ampolles');
      expect(denominationName(ca, 'can'), 'llauna');
    });

    test('Spanish singular vs plural', () {
      final es = AppLocalizationsEs();
      expect(denominationCount(es, 'unit', 1), '1 unidad');
      expect(denominationCount(es, 'unit', 3), '3 unidades');
    });

    test('English singular vs plural', () {
      final en = AppLocalizationsEn();
      expect(denominationCount(en, 'litre', 1), '1 litre');
      expect(denominationCount(en, 'litre', 4), '4 litres');
    });

    test('unknown code falls back to bottle', () {
      expect(parseDenomination('nope'), Denomination.bottle);
    });
  });

  group('MenuTotals counts dishes (bought + cooked), excludes drinks', () {
    EventDish dish(int servings, DishAcquisitionMode mode) => EventDish(
      id: 'd$servings$mode',
      name: 'x',
      category: DishCategory.main,
      servings: servings,
      sortOrder: 0,
      acquisitionMode: mode,
    );

    test('a bought dish contributes its servings like a cooked one', () {
      final totals = MenuTotals.from([
        dish(4, DishAcquisitionMode.cooked),
        dish(8, DishAcquisitionMode.bought),
      ], guestCount: 6);
      expect(totals.dishCount, 2);
      expect(totals.servingsTotal, 12);
      expect(totals.servingsPerGuest, closeTo(2.0, 1e-9));
    });

    // Drinks are not a parameter of MenuTotals.from — they live in event_drinks
    // and never reach the food totals — so they are excluded by construction.
  });

  group('purchase lines in shopping: one per item, by supplier, never merge', () {
    ShoppingLine prepared(String id, String name, String category) =>
        boughtDishShoppingLine(
          id: id,
          name: name,
          supplierCategoryId: category,
          servings: 8,
          servingsPerUnit: 6,
          state: IngredientState.toOrder,
        );

    test('a bought dish line carries its units and no denomination', () {
      final line = prepared('a', 'Canelons', 'cat-prepared');
      expect(line.quantity, 2); // ceil(8 / 6)
      expect(line.kind, ShoppingLineKind.preparedDish);
      expect(line.denomination, isNull);
    });

    test('two identical-looking prepared dishes stay separate', () {
      final lines = [
        prepared('a', 'Canelons', 'cat-prepared'),
        prepared('b', 'Canelons', 'cat-prepared'),
      ];
      final aggregated = aggregateShoppingLines(lines);
      expect(aggregated.length, 2);
      expect(
        aggregated.every((l) => l.kind == ShoppingLineKind.preparedDish),
        isTrue,
      );
    });

    test('purchase lines group by their supplier category', () {
      final lines = [
        prepared('a', 'Canelons', 'cat-prepared'),
        drinkShoppingLine(
          id: 'c',
          name: 'Vi negre',
          supplierCategoryId: 'cat-beverages',
          quantity: 2,
          denomination: 'bottle',
          state: IngredientState.toOrder,
        ),
      ];
      final byCat = linesByCategory(lines);
      expect(byCat['cat-prepared']!.length, 1);
      expect(byCat['cat-beverages']!.length, 1);
      // The drink line carries its manual unit quantity and denomination.
      expect(byCat['cat-beverages']!.first.quantity, 2);
      expect(byCat['cat-beverages']!.first.denomination, 'bottle');
    });
  });
}
