import 'package:entertain/features/shopping/data/ingredient_state.dart';
import 'package:entertain/features/shopping/data/purchase_line.dart';
import 'package:entertain/features/shopping/data/shopping_aggregation.dart';
import 'package:entertain/features/shopping/data/shopping_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 028 §B — the in-person checklist maps onto the existing state machine.
void main() {
  // Spec 028 §C — purchase lines (bought dishes / drinks) carry their CATALOG
  // source id so the shopping row can resolve a cover photo (the gap that left
  // drink/bought-dish rows photoless). Ingredient covers already worked.
  group('purchase-line cover source id', () {
    test('bought dish carries its source dish id', () {
      final line = boughtDishShoppingLine(
        id: 'ed1',
        name: 'Canelons',
        supplierCategoryId: null,
        servings: 8,
        servingsPerUnit: 4,
        state: IngredientState.toOrder,
        sourceCatalogId: 'catalog-dish-1',
      );
      expect(line.kind, ShoppingLineKind.preparedDish);
      expect(line.sourceCatalogId, 'catalog-dish-1');
    });

    test('drink carries its source drink id', () {
      final line = drinkShoppingLine(
        id: 'edr1',
        name: 'Orxata',
        supplierCategoryId: null,
        quantity: 2,
        denomination: 'bottle',
        state: IngredientState.toOrder,
        sourceCatalogId: 'catalog-drink-1',
      );
      expect(line.kind, ShoppingLineKind.drink);
      expect(line.sourceCatalogId, 'catalog-drink-1');
    });

    test('aggregation preserves the source id (purchase lines never fold)', () {
      final line = drinkShoppingLine(
        id: 'edr1',
        name: 'Orxata',
        supplierCategoryId: 'cat',
        quantity: 2,
        denomination: 'bottle',
        state: IngredientState.toOrder,
        sourceCatalogId: 'catalog-drink-1',
      );
      final agg = aggregateShoppingLines([line]);
      expect(agg, hasLength(1));
      expect(agg.single.sourceCatalogId, 'catalog-drink-1');
    });
  });

  group('isCheckedShoppingState', () {
    test('received / at-home read as checked', () {
      expect(isCheckedShoppingState(IngredientState.received), isTrue);
      expect(isCheckedShoppingState(IngredientState.atHome), isTrue);
    });

    test('every other state reads as unchecked', () {
      expect(isCheckedShoppingState(IngredientState.toOrder), isFalse);
      expect(isCheckedShoppingState(IngredientState.ordered), isFalse);
      expect(isCheckedShoppingState(IngredientState.missing), isFalse);
    });
  });

  group('toggledShoppingState', () {
    test('non-pantry: check → received, uncheck → to-order', () {
      // Unchecked → check sets received.
      expect(toggledShoppingState(IngredientState.toOrder, isPantry: false),
          IngredientState.received);
      expect(toggledShoppingState(IngredientState.ordered, isPantry: false),
          IngredientState.received);
      // Checked → uncheck sets to-order.
      expect(toggledShoppingState(IngredientState.received, isPantry: false),
          IngredientState.toOrder);
    });

    test('pantry: binary at-home ↔ missing', () {
      expect(toggledShoppingState(IngredientState.missing, isPantry: true),
          IngredientState.atHome);
      expect(toggledShoppingState(IngredientState.atHome, isPantry: true),
          IngredientState.missing);
    });

    test('round-trips back to an unchecked state', () {
      final checked = toggledShoppingState(IngredientState.toOrder, isPantry: false);
      expect(isCheckedShoppingState(checked), isTrue);
      final back = toggledShoppingState(checked, isPantry: false);
      expect(isCheckedShoppingState(back), isFalse);
      expect(back, IngredientState.toOrder);
    });
  });
}
