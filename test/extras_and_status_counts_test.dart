import 'package:entertain/features/shopping/data/ingredient_state.dart';
import 'package:entertain/features/shopping/data/shopping_aggregation.dart';
import 'package:entertain/features/shopping/data/shopping_delta.dart';
import 'package:entertain/features/shopping/data/shopping_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 011 §2.9 (status counters, including extra exclusion) and §2.11
/// (extra ingredients: managed/extras split, never-aggregate, supplier grouping).

ShoppingLine line(
  String id, {
  String name = 'tomatoes',
  double qty = 1,
  IngredientState state = IngredientState.toOrder,
  String unit = 'u-kg',
  String? category = 'cat-greengrocer',
  String? ingredientId = 'ing-tomato',
  bool isExtra = false,
}) {
  return ShoppingLine(
    id: id,
    ingredientId: ingredientId,
    ingredientName: name,
    quantity: qty,
    unitId: unit,
    state: state,
    supplierCategoryId: category,
    isExtra: isExtra,
  );
}

void main() {
  group('managedShoppingLines / extrasByCategory (§2.11)', () {
    test('extras are split out of the managed lines', () {
      final lines = [
        line('a'),
        line('e1', isExtra: true, name: 'spinach'),
        line('b'),
      ];
      final managed = managedShoppingLines(lines);
      expect(managed.map((l) => l.id), ['a', 'b']);
    });

    test('extras group by their supplier category', () {
      final lines = [
        line('e1', isExtra: true, category: 'cat-greengrocer', name: 'spinach'),
        line('e2', isExtra: true, category: 'cat-greengrocer', name: 'lemons'),
        line('e3', isExtra: true, category: 'cat-butcher', name: 'sausages'),
        line('m1'), // managed, ignored
      ];
      final byCat = extrasByCategory(lines);
      expect(byCat.keys.toSet(), {'cat-greengrocer', 'cat-butcher'});
      expect(byCat['cat-greengrocer']!.map((l) => l.id), ['e1', 'e2']);
      expect(byCat['cat-butcher']!.map((l) => l.id), ['e3']);
    });

    test('two extras of the same ingredient stay as separate entries', () {
      // Extras never aggregate — even an identical ingredient is two rows.
      final lines = [
        line('e1', isExtra: true, name: 'spinach', qty: 1),
        line('e2', isExtra: true, name: 'spinach', qty: 1),
      ];
      expect(extrasByCategory(lines)['cat-greengrocer'], hasLength(2));
      // And aggregating the managed set (empty here) never folds them in.
      expect(aggregateShoppingLines(managedShoppingLines(lines)), isEmpty);
    });

    test('an extra with no supplier category is dropped', () {
      final byCat = extrasByCategory([
        line('e1', isExtra: true, category: null),
      ]);
      expect(byCat, isEmpty);
    });
  });

  group('supplierStatusCounts (§2.9)', () {
    AggregatedShoppingLine agg(String id, IngredientState state) =>
        AggregatedShoppingLine(
          ingredientId: 'ing-$id',
          ingredientName: id,
          quantity: 1,
          unitId: 'u-kg',
          state: state,
          supplierCategoryId: 'cat-greengrocer',
          prepNote: null,
          sourceIds: [id],
        );

    test('maps states to red/yellow/green (criterion 29)', () {
      final counts = supplierStatusCounts([
        agg('a', IngredientState.toOrder),
        agg('b', IngredientState.missing),
        agg('c', IngredientState.ordered),
        agg('d', IngredientState.received),
        agg('e', IngredientState.atHome),
      ]);
      expect(counts.red, 2); // to_order + missing
      expect(counts.yellow, 1); // ordered
      expect(counts.green, 2); // received + at_home
    });

    test('extras never reach the counter (criterion 30)', () {
      // The panel feeds managed aggregated lines only; an event with managed +
      // extras counts only the managed ones.
      final lines = [
        line('m1', state: IngredientState.toOrder),
        line(
          'e1',
          isExtra: true,
          name: 'spinach',
          state: IngredientState.toOrder,
        ),
      ];
      final managedAgg = aggregateShoppingLines(managedShoppingLines(lines));
      final counts = supplierStatusCounts(managedAgg);
      expect(counts.red, 1); // only m1, the extra is excluded
      expect(counts.yellow, 0);
      expect(counts.green, 0);
    });

    test('an empty section has an all-zero trio', () {
      final counts = supplierStatusCounts(const []);
      expect((counts.red, counts.yellow, counts.green), (0, 0, 0));
    });
  });
}
