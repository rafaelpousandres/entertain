/// Grouping and delta helpers for the shopping surfaces.
///
/// Spec 005 computed the unsent delta by matching current lines against the
/// frozen items of past orders (a content key, since `order_items` does not
/// store the originating line id). Spec 007 §3.4 replaces that with the state
/// machine: the delta to send for a category is simply its lines in state
/// `to_order`. Sending moves those exact lines to `ordered` (their ids are
/// known), so the next delta naturally excludes them and successive sends
/// never duplicate — the multi-order behaviour of Spec 005 is preserved
/// without content matching. The orders / order_items snapshot is still
/// written on send as immutable history.
library;

import 'ingredient_state.dart';
import 'shopping_models.dart';

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
/// message screen renders the send history in chronological order.
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

/// The unsent delta for a category (Spec 007 §3.4): its lines still in state
/// `to_order`. These are exactly the lines a "send message" would carry, and
/// the lines whose state moves to `ordered` once the send is confirmed.
List<ShoppingLine> deltaForCategory(List<ShoppingLine> categoryLines) => [
  for (final line in categoryLines)
    if (line.state == IngredientState.toOrder) line,
];
