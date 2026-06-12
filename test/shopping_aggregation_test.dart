import 'package:entertain/features/shopping/data/ingredient_state.dart';
import 'package:entertain/features/shopping/data/shopping_aggregation.dart';
import 'package:entertain/features/shopping/data/shopping_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Specification 010 §2.1 — presentation-layer aggregation of repeated
/// ingredients on the shopping panel. Rows fold together only when all five key
/// components match — (ingredient_id, unit_id, state, supplier_category_id,
/// prep_note) — and the folded quantity is the sum of the (already scaled)
/// per-row quantities.

ShoppingLine line(
  String id, {
  String name = 'spring onions',
  double qty = 1,
  IngredientState state = IngredientState.toOrder,
  String unit = 'u-bunch',
  String? category = 'cat-greengrocer',
  String? ingredientId = 'ing-onion',
  String? prepNote,
}) {
  return ShoppingLine(
    id: id,
    ingredientId: ingredientId,
    ingredientName: name,
    quantity: qty,
    unitId: unit,
    state: state,
    supplierCategoryId: category,
    prepNote: prepNote,
  );
}

void main() {
  group('aggregateShoppingLines (§2.1)', () {
    test('matching rows fold into one line with summed quantity (criterion 1)',
        () {
      final result = aggregateShoppingLines([
        line('a', qty: 1),
        line('b', qty: 2),
      ]);
      expect(result, hasLength(1));
      expect(result.single.quantity, 3);
      expect(result.single.isAggregate, isTrue);
      expect(result.single.sourceIds, ['a', 'b']);
      expect(result.single.ingredientName, 'spring onions');
    });

    test('different units stay separate (criterion 2)', () {
      final result = aggregateShoppingLines([
        line('a', qty: 1, unit: 'u-bunch'),
        line('b', qty: 2, unit: 'u-g'),
      ]);
      expect(result, hasLength(2));
      expect(result.every((l) => !l.isAggregate), isTrue);
    });

    test('different states stay separate (criterion 3)', () {
      final result = aggregateShoppingLines([
        line('a', state: IngredientState.toOrder),
        line('b', state: IngredientState.ordered),
      ]);
      expect(result, hasLength(2));
    });

    test('different prep_notes stay separate (criterion 4)', () {
      final result = aggregateShoppingLines([
        line('a', prepNote: 'finely diced'),
        line('b', prepNote: 'whole'),
      ]);
      expect(result, hasLength(2));
    });

    test('null and empty prep_note are treated as the same "no note"', () {
      final result = aggregateShoppingLines([
        line('a', prepNote: null),
        line('b', prepNote: '   '),
      ]);
      expect(result, hasLength(1));
      expect(result.single.sourceIds, ['a', 'b']);
    });

    test('different supplier categories stay separate (criterion 5)', () {
      final result = aggregateShoppingLines([
        line('a', category: 'cat-greengrocer'),
        line('b', category: 'cat-supermarket'),
      ]);
      expect(result, hasLength(2));
    });

    test('different ingredients stay separate', () {
      final result = aggregateShoppingLines([
        line('a', ingredientId: 'ing-onion'),
        line('b', ingredientId: 'ing-garlic', name: 'garlic'),
      ]);
      expect(result, hasLength(2));
    });

    test('ad-hoc lines with no ingredient_id never fold, even by name', () {
      final result = aggregateShoppingLines([
        line('a', ingredientId: null),
        line('b', ingredientId: null),
      ]);
      expect(result, hasLength(2));
    });

    test('sums effective scaled quantities, not bases', () {
      // The repository already scaled each row; aggregation just adds them.
      final result = aggregateShoppingLines([
        line('a', qty: 0.5),
        line('b', qty: 0.25),
        line('c', qty: 0.25),
      ]);
      expect(result.single.quantity, 1.0);
      expect(result.single.sourceIds, ['a', 'b', 'c']);
    });

    test('preserves first-occurrence order across mixed groups', () {
      final result = aggregateShoppingLines([
        line('a', ingredientId: 'ing-onion'),
        line('b', ingredientId: 'ing-garlic', name: 'garlic'),
        line('c', ingredientId: 'ing-onion'),
      ]);
      expect(result.map((l) => l.ingredientName), ['spring onions', 'garlic']);
      expect(result.first.sourceIds, ['a', 'c']);
    });

    test('a single unmatched row is a non-aggregate line', () {
      final result = aggregateShoppingLines([line('a', qty: 2)]);
      expect(result.single.isAggregate, isFalse);
      expect(result.single.quantity, 2);
      expect(result.single.sourceIds, ['a']);
    });
  });
}
