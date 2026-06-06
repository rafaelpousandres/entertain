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
  String? ingredientId,
}) {
  return ShoppingLine(
    id: id,
    ingredientId: ingredientId,
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

  group('neededByByItem / lineIsDelayed (Fixes round 2 §2.2)', () {
    OrderItem item(String name, {String? ingredientId}) => OrderItem(
          id: 'oi-$name',
          ingredientId: ingredientId,
          ingredientName: name,
          quantity: 1,
          unitId: 'u-g',
        );

    SupplierOrder order(
      String id, {
      String category = 'cat-fish',
      required DateTime sentAt,
      DateTime? neededBy,
      required List<OrderItem> items,
    }) =>
        SupplierOrder(
          id: id,
          supplierCategoryId: category,
          sentAt: sentAt,
          neededByDate: neededBy,
          items: items,
        );

    final today = DateTime(2026, 6, 7);
    final past = DateTime(2026, 6, 5);
    final future = DateTime(2026, 6, 10);

    test('an ordered line past its needed-by date is delayed', () {
      final orders = [
        order('o1',
            sentAt: DateTime(2026, 6, 1),
            neededBy: past,
            items: [item('gambes', ingredientId: 'i-gambes')]),
      ];
      final l = line('a', 'gambes', 2, state: IngredientState.ordered, ingredientId: 'i-gambes');
      expect(lineIsDelayed(l, neededByByItem(orders), today), isTrue);
    });

    test('needed-by today (not strictly past) is not delayed', () {
      final orders = [
        order('o1',
            sentAt: DateTime(2026, 6, 1),
            neededBy: today,
            items: [item('gambes', ingredientId: 'i-gambes')]),
      ];
      final l = line('a', 'gambes', 2, state: IngredientState.ordered, ingredientId: 'i-gambes');
      expect(lineIsDelayed(l, neededByByItem(orders), today), isFalse);
    });

    test('a future needed-by date is not delayed', () {
      final orders = [
        order('o1',
            sentAt: DateTime(2026, 6, 1),
            neededBy: future,
            items: [item('gambes', ingredientId: 'i-gambes')]),
      ];
      final l = line('a', 'gambes', 2, state: IngredientState.ordered, ingredientId: 'i-gambes');
      expect(lineIsDelayed(l, neededByByItem(orders), today), isFalse);
    });

    test('only ordered lines can be delayed', () {
      final orders = [
        order('o1',
            sentAt: DateTime(2026, 6, 1),
            neededBy: past,
            items: [item('gambes', ingredientId: 'i-gambes')]),
      ];
      final neededBy = neededByByItem(orders);
      for (final s in [
        IngredientState.toOrder,
        IngredientState.received,
        IngredientState.missing,
        IngredientState.atHome,
      ]) {
        final l = line('a', 'gambes', 2, state: s, ingredientId: 'i-gambes');
        expect(lineIsDelayed(l, neededBy, today), isFalse, reason: '$s');
      }
    });

    test('with multiple orders the latest send wins', () {
      final orders = [
        order('old',
            sentAt: DateTime(2026, 6, 1),
            neededBy: past, // would be delayed…
            items: [item('gambes', ingredientId: 'i-gambes')]),
        order('new',
            sentAt: DateTime(2026, 6, 4),
            neededBy: future, // …but the latest commitment is in the future
            items: [item('gambes', ingredientId: 'i-gambes')]),
      ];
      final l = line('a', 'gambes', 2, state: IngredientState.ordered, ingredientId: 'i-gambes');
      expect(lineIsDelayed(l, neededByByItem(orders), today), isFalse);
    });

    test('ad-hoc lines (no ingredient id) match by frozen name', () {
      final orders = [
        order('o1',
            sentAt: DateTime(2026, 6, 1),
            neededBy: past,
            items: [item('allioli casolà')]),
      ];
      final l = line('a', 'allioli casolà', 1, state: IngredientState.ordered);
      expect(lineIsDelayed(l, neededByByItem(orders), today), isTrue);
    });

    test('a different category never matches', () {
      final orders = [
        order('o1',
            category: 'cat-meat',
            sentAt: DateTime(2026, 6, 1),
            neededBy: past,
            items: [item('gambes', ingredientId: 'i-gambes')]),
      ];
      final l = line('a', 'gambes', 2,
              state: IngredientState.ordered,
              category: 'cat-fish',
              ingredientId: 'i-gambes');
      expect(lineIsDelayed(l, neededByByItem(orders), today), isFalse);
    });

    test('orders without a needed-by date do not contribute', () {
      final orders = [
        order('o1',
            sentAt: DateTime(2026, 6, 1),
            neededBy: null,
            items: [item('gambes', ingredientId: 'i-gambes')]),
      ];
      expect(neededByByItem(orders), isEmpty);
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
