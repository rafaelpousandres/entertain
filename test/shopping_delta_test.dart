import 'package:entertain/features/shopping/data/shopping_delta.dart';
import 'package:entertain/features/shopping/data/shopping_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests the delta mechanism of Specification 005 §2.4 — the rule that drives
/// successive sends so a category never re-sends already-sent items.

ShoppingLine line(
  String id,
  String name,
  double qty, {
  String unit = 'u-g',
  String? ingredientId,
}) {
  return ShoppingLine(
    id: id,
    ingredientId: ingredientId,
    ingredientName: name,
    quantity: qty,
    unitId: unit,
    supplierCategoryId: 'cat-fish',
  );
}

/// Builds an order whose frozen items mirror the given lines (the copy made
/// at send time).
SupplierOrder orderFrom(String id, List<ShoppingLine> lines) {
  return SupplierOrder(
    id: id,
    supplierCategoryId: 'cat-fish',
    sentAt: DateTime(2026, 6, 1),
    items: [
      for (final l in lines)
        OrderItem(
          id: 'oi-${l.id}',
          ingredientId: l.ingredientId,
          ingredientName: l.ingredientName,
          quantity: l.quantity,
          unitId: l.unitId,
        ),
    ],
  );
}

void main() {
  group('deltaForCategory', () {
    test('with no orders, the delta is every line', () {
      final lines = [line('a', 'gambes', 2), line('b', 'cloïsses', 1)];
      expect(deltaForCategory(lines, const []).map((l) => l.id), ['a', 'b']);
    });

    test('after sending everything, the delta is empty', () {
      final lines = [line('a', 'gambes', 2), line('b', 'cloïsses', 1)];
      final orders = [orderFrom('o1', lines)];
      expect(deltaForCategory(lines, orders), isEmpty);
    });

    test('a line added after a send appears alone in the delta', () {
      final firstBatch = [line('a', 'gambes', 2)];
      final orders = [orderFrom('o1', firstBatch)];
      final lines = [...firstBatch, line('b', 'cloïsses', 1)];
      expect(deltaForCategory(lines, orders).map((l) => l.id), ['b']);
    });

    test('a second send freezes only the delta and leaves the first intact', () {
      final firstBatch = [line('a', 'gambes', 2)];
      final order1 = orderFrom('o1', firstBatch);

      // Menu grows; the delta is just the new line, which gets sent.
      final lines = [...firstBatch, line('b', 'cloïsses', 1)];
      final delta1 = deltaForCategory(lines, [order1]);
      expect(delta1.map((l) => l.id), ['b']);

      final order2 = orderFrom('o2', delta1);
      // After both sends, nothing remains; order1 still holds only line a.
      expect(deltaForCategory(lines, [order1, order2]), isEmpty);
      expect(order1.items.map((i) => i.ingredientName), ['gambes']);
    });

    test('duplicate identical lines are matched as a multiset', () {
      // Two identical lines, only one already sent → one remains unsent.
      final sent = [line('a', 'gambes', 2)];
      final lines = [line('a', 'gambes', 2), line('b', 'gambes', 2)];
      final delta = deltaForCategory(lines, [orderFrom('o1', sent)]);
      expect(delta.length, 1);
    });

    test('adding more of an already-sent ingredient surfaces the extra line', () {
      final sent = [line('a', 'gambes', 2)];
      final lines = [
        line('a', 'gambes', 2), // already sent
        line('c', 'gambes', 2), // a second identical portion, not yet sent
      ];
      expect(deltaForCategory(lines, [orderFrom('o1', sent)]).length, 1);
    });
  });
}
