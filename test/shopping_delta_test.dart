import 'package:entertain/features/shopping/data/ingredient_state.dart';
import 'package:entertain/features/shopping/data/shopping_delta.dart';
import 'package:entertain/features/shopping/data/shopping_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests the delta mechanism after Specification 007 §3.4: the delta to send
/// for a category is its lines still in state `to_order`. Sending moves those
/// lines to `ordered`, so the next delta naturally excludes them — the
/// multi-order behaviour of Spec 005 is preserved without content matching.

ShoppingLine line(
  String id,
  String name,
  double qty, {
  IngredientState state = IngredientState.toOrder,
  String unit = 'u-g',
  String? category = 'cat-fish',
}) {
  return ShoppingLine(
    id: id,
    ingredientName: name,
    quantity: qty,
    unitId: unit,
    state: state,
    supplierCategoryId: category,
  );
}

void main() {
  group('deltaForCategory (state-based)', () {
    test('every to_order line is in the delta', () {
      final lines = [line('a', 'gambes', 2), line('b', 'cloïsses', 1)];
      expect(deltaForCategory(lines).map((l) => l.id), ['a', 'b']);
    });

    test('lines in other states are excluded', () {
      final lines = [
        line('a', 'gambes', 2, state: IngredientState.ordered),
        line('b', 'cloïsses', 1, state: IngredientState.received),
        line('c', 'sípia', 1, state: IngredientState.missing),
        line('d', 'musclos', 1, state: IngredientState.atHome),
        line('e', 'lluç', 1), // to_order
      ];
      expect(deltaForCategory(lines).map((l) => l.id), ['e']);
    });

    test('once everything is ordered the delta is empty', () {
      final lines = [
        line('a', 'gambes', 2, state: IngredientState.ordered),
        line('b', 'cloïsses', 1, state: IngredientState.ordered),
      ];
      expect(deltaForCategory(lines), isEmpty);
    });

    test('a line added after a send (still to_order) appears alone', () {
      final lines = [
        line('a', 'gambes', 2, state: IngredientState.ordered), // sent
        line('b', 'cloïsses', 1), // newly added, to_order
      ];
      expect(deltaForCategory(lines).map((l) => l.id), ['b']);
    });
  });

  group('linesByCategory', () {
    test('groups by supplier category and drops null-category lines', () {
      final lines = [
        line('a', 'gambes', 2, category: 'cat-fish'),
        line('b', 'pollastre', 1, category: 'cat-meat'),
        line('c', 'sal', 1, category: null),
        line('d', 'lluç', 1, category: 'cat-fish'),
      ];
      final byCat = linesByCategory(lines);
      expect(byCat['cat-fish']!.map((l) => l.id), ['a', 'd']);
      expect(byCat['cat-meat']!.map((l) => l.id), ['b']);
      expect(byCat.containsKey(null), isFalse);
    });
  });
}
