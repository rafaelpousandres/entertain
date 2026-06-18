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
import 'package:flutter_test/flutter_test.dart';

/// Specification 014 — prepared dishes and drinks. Pure-logic acceptance:
/// the bought-item purchase quantity (ceil with a unit, scaled servings
/// without), drinks scaling to guests, food totals counting bought dishes
/// while drinks are excluded, and purchase lines flowing through shopping as
/// one line per item, grouped by supplier and never merged.

void main() {
  group('purchaseLineQuantity', () {
    test('with unit + servings-per-unit → ceil of units', () {
      // 8 servings, 6 per tray → 2 trays.
      final q = purchaseLineQuantity(
        servings: 8,
        purchaseUnit: 'safata',
        servingsPerUnit: 6,
      );
      expect(q.quantity, 2);
      expect(q.unitLabel, 'safata');
    });

    test('exact division does not over-round', () {
      final q = purchaseLineQuantity(
        servings: 12,
        purchaseUnit: 'ampolla',
        servingsPerUnit: 6,
      );
      expect(q.quantity, 2);
    });

    test('without a unit → scaled servings, no unit label', () {
      final q = purchaseLineQuantity(
        servings: 12,
        purchaseUnit: null,
        servingsPerUnit: null,
      );
      expect(q.quantity, 12);
      expect(q.unitLabel, isNull);
    });

    test('unit without servings-per-unit falls back to servings', () {
      final q = purchaseLineQuantity(
        servings: 5,
        purchaseUnit: 'unitat',
        servingsPerUnit: null,
      );
      expect(q.quantity, 5);
      expect(q.unitLabel, isNull);
    });
  });

  group('defaultEventDrinkServings (scales to guests)', () {
    test('uses the guest count when set', () {
      expect(defaultEventDrinkServings(10, 4), 10);
    });
    test('falls back to base servings with no guests', () {
      expect(defaultEventDrinkServings(0, 6), 6);
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
        purchaseShoppingLine(
          id: id,
          kind: ShoppingLineKind.preparedDish,
          name: name,
          supplierCategoryId: category,
          servings: 8,
          purchaseUnit: 'safata',
          servingsPerUnit: 6,
          state: IngredientState.toOrder,
        );

    test('two identical-looking prepared dishes stay separate', () {
      final lines = [
        prepared('a', 'Canelons', 'cat-prepared'),
        prepared('b', 'Canelons', 'cat-prepared'),
      ];
      final aggregated = aggregateShoppingLines(lines);
      expect(aggregated.length, 2);
      expect(aggregated.every((l) => l.kind == ShoppingLineKind.preparedDish),
          isTrue);
    });

    test('purchase lines group by their supplier category', () {
      final lines = [
        prepared('a', 'Canelons', 'cat-prepared'),
        purchaseShoppingLine(
          id: 'c',
          kind: ShoppingLineKind.drink,
          name: 'Vi negre',
          supplierCategoryId: 'cat-beverages',
          servings: 10,
          purchaseUnit: 'ampolla',
          servingsPerUnit: 5,
          state: IngredientState.toOrder,
        ),
      ];
      final byCat = linesByCategory(lines);
      expect(byCat['cat-prepared']!.length, 1);
      expect(byCat['cat-beverages']!.length, 1);
      // The drink computes 2 bottles for 10 servings at 5 per bottle.
      expect(byCat['cat-beverages']!.first.quantity, 2);
    });
  });
}
