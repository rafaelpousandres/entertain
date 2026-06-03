/// Delta computation — the central mechanism of Specification 005 §2.4.
///
/// A category may accumulate several orders as the user adds items between
/// sends. The *delta* for a category is the set of current event lines that
/// have not yet been included in any sent order for the same (event,
/// category). Sending freezes only that delta, so successive sends never
/// duplicate already-sent items and the second send carries only what is new
/// (acceptance criterion 8).
///
/// Matching strategy. The ideal key is the originating
/// `event_dish_ingredients.id`, but `order_items` does not store it and the
/// Spec fixes the schema changes to `orders` / the companion table with "no
/// other structural changes" — so the id is not available on the order side.
/// We therefore fall back to the Spec's sanctioned alternative: a stable key
/// "composed of the ingredient and the line's identity", reconstructable from
/// the snapshot fields present on both `event_dish_ingredients` and the
/// frozen `order_items` (ingredient identity + quantity + unit + prep note).
/// Matching is multiset-based so that two identical lines, or adding more of
/// an already-sent ingredient, correctly surface the extra line in the delta.
library;

import 'shopping_models.dart';

/// Stable key identifying a line by its content. Ingredient identity prefers
/// the catalog id (survives a rename) and falls back to the snapshot name.
String _key({
  String? ingredientId,
  required String ingredientName,
  required double quantity,
  required String unitId,
  String? prepNote,
}) {
  final identity = ingredientId != null
      ? 'id:$ingredientId'
      : 'name:${ingredientName.trim().toLowerCase()}';
  final note = (prepNote ?? '').trim();
  // quantity comes from `numeric` parsed identically on both sides, so its
  // toString() is deterministic for equal stored values.
  return '$identity|$quantity|$unitId|$note';
}

String lineKey(ShoppingLine line) => _key(
  ingredientId: line.ingredientId,
  ingredientName: line.ingredientName,
  quantity: line.quantity,
  unitId: line.unitId,
  prepNote: line.prepNote,
);

String orderItemKey(OrderItem item) => _key(
  ingredientId: item.ingredientId,
  ingredientName: item.ingredientName,
  quantity: item.quantity,
  unitId: item.unitId,
  prepNote: item.prepNote,
);

/// Lines that carry a supplier category, grouped by it. Lines with no
/// category are excluded — they have no destination section.
Map<String, List<ShoppingLine>> linesByCategory(List<ShoppingLine> lines) {
  final map = <String, List<ShoppingLine>>{};
  for (final line in lines) {
    final category = line.supplierCategoryId;
    if (category == null) continue;
    map.putIfAbsent(category, () => []).add(line);
  }
  return map;
}

/// Orders grouped by category, each list ordered oldest-send first so the
/// panel renders the send history in chronological order.
Map<String, List<SupplierOrder>> ordersByCategory(List<SupplierOrder> orders) {
  final map = <String, List<SupplierOrder>>{};
  for (final order in orders) {
    map.putIfAbsent(order.supplierCategoryId, () => []).add(order);
  }
  for (final list in map.values) {
    list.sort((a, b) {
      final aAt = a.sentAt, bAt = b.sentAt;
      if (aAt == null && bAt == null) return 0;
      if (aAt == null) return 1;
      if (bAt == null) return -1;
      return aAt.compareTo(bAt);
    });
  }
  return map;
}

/// The unsent delta for a single category: the current lines minus the
/// multiset of items already frozen across [categoryOrders].
List<ShoppingLine> deltaForCategory(
  List<ShoppingLine> categoryLines,
  List<SupplierOrder> categoryOrders,
) {
  final sentCounts = <String, int>{};
  for (final order in categoryOrders) {
    for (final item in order.items) {
      final key = orderItemKey(item);
      sentCounts[key] = (sentCounts[key] ?? 0) + 1;
    }
  }

  final delta = <ShoppingLine>[];
  for (final line in categoryLines) {
    final key = lineKey(line);
    final remaining = sentCounts[key] ?? 0;
    if (remaining > 0) {
      sentCounts[key] = remaining - 1; // already covered by a sent order
    } else {
      delta.add(line);
    }
  }
  return delta;
}
