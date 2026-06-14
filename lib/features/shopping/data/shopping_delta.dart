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
import 'shopping_aggregation.dart';
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

/// Aggregated lines that carry a supplier category, grouped by it (Spec 010
/// §2.1). Same contract as [linesByCategory] but over already-aggregated lines,
/// so the shopping panel groups the §2.1-folded lines into supplier sections.
Map<String, List<AggregatedShoppingLine>> aggregatedLinesByCategory(
  List<AggregatedShoppingLine> lines,
) {
  final map = <String, List<AggregatedShoppingLine>>{};
  for (final line in lines) {
    final category = line.supplierCategoryId;
    if (category == null) continue;
    map.putIfAbsent(category, () => []).add(line);
  }
  return map;
}

/// Spec 011 §2.11 — the managed (dish-derived) lines of an event, excluding the
/// phantom-dish extras. Managed lines feed aggregation, the summary, the status
/// counters and the state machine; extras are handled separately.
List<ShoppingLine> managedShoppingLines(List<ShoppingLine> lines) => [
  for (final line in lines)
    if (!line.isExtra) line,
];

/// Spec 011 §2.11 — extras grouped by their supplier category, raw and never
/// aggregated, in their stored order. An extra with no category is dropped (an
/// extra always carries a supplier).
Map<String, List<ShoppingLine>> extrasByCategory(List<ShoppingLine> lines) {
  final map = <String, List<ShoppingLine>>{};
  for (final line in lines) {
    if (!line.isExtra) continue;
    final category = line.supplierCategoryId;
    if (category == null) continue;
    map.putIfAbsent(category, () => []).add(line);
  }
  return map;
}

/// Spec 011 §2.9 — the red/yellow/green status trio for a supplier section,
/// over its managed aggregated lines (a folded ingredient counts once). Red =
/// still to act (`to_order` + `missing`); yellow = waiting (`ordered`); green =
/// resolved (`received` + `at_home`). Extras are excluded by construction —
/// callers pass managed lines only.
({int red, int yellow, int green}) supplierStatusCounts(
  Iterable<AggregatedShoppingLine> lines,
) {
  var red = 0;
  var yellow = 0;
  var green = 0;
  for (final line in lines) {
    switch (line.state) {
      case IngredientState.toOrder:
      case IngredientState.missing:
        red++;
      case IngredientState.ordered:
        yellow++;
      case IngredientState.received:
      case IngredientState.atHome:
        green++;
    }
  }
  return (red: red, yellow: yellow, green: green);
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

/// Content key matching an ordered line to the frozen order items that ordered
/// it (Fixes round 2 §2.2). Scoped to the category, then keyed by the catalog
/// ingredient id when present, falling back to the (frozen) ingredient name for
/// ad-hoc lines without a catalog id. `order_items` carry no back-reference to
/// the originating line, so this content key is how Spec 005's snapshot is
/// re-associated — the same approach the delta logic used before the state
/// machine replaced it.
String _itemKey(String? categoryId, String? ingredientId, String name) =>
    '${categoryId ?? ''}|${ingredientId ?? 'name:$name'}';

/// The operative needed-by date per ordered ingredient (Fixes round 2 §2.2),
/// keyed by [_itemKey]. Only orders that carry a `needed_by_date` contribute;
/// when an ingredient was sent across several orders the latest send (by
/// `sent_at`) wins, since that is the user's most recent commitment.
Map<String, DateTime> neededByByItem(List<SupplierOrder> orders) {
  final winners = <String, ({DateTime needed, DateTime sent})>{};
  for (final order in orders) {
    final needed = order.neededByDate;
    if (needed == null) continue;
    // A sent order always has a sent_at; guard with the epoch so an unstamped
    // row still participates without ever beating a real send.
    final sent = order.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    for (final item in order.items) {
      final key = _itemKey(
        order.supplierCategoryId,
        item.ingredientId,
        item.ingredientName,
      );
      final current = winners[key];
      if (current == null || sent.isAfter(current.sent)) {
        winners[key] = (needed: needed, sent: sent);
      }
    }
  }
  return {for (final e in winners.entries) e.key: e.value.needed};
}

/// Whether a line renders as "Retrassat" (Fixes round 2 §2.2): it is still
/// `ordered` and the [today] calendar date is strictly past the needed-by date
/// of the most recent order that ordered it. [today] must be a date-only value
/// (local midnight) so the comparison is purely by calendar day.
bool lineIsDelayed(
  ShoppingLine line,
  Map<String, DateTime> neededByItem,
  DateTime today,
) => _isDelayed(
  state: line.state,
  supplierCategoryId: line.supplierCategoryId,
  ingredientId: line.ingredientId,
  ingredientName: line.ingredientName,
  neededByItem: neededByItem,
  today: today,
);

/// [lineIsDelayed] for an aggregated line (Spec 010 §2.1): the folded rows share
/// the state, supplier category, ingredient id and name the delay key uses, so
/// the overlay is uniform across the aggregate and derives from those shared
/// values.
bool aggregatedLineIsDelayed(
  AggregatedShoppingLine line,
  Map<String, DateTime> neededByItem,
  DateTime today,
) => _isDelayed(
  state: line.state,
  supplierCategoryId: line.supplierCategoryId,
  ingredientId: line.ingredientId,
  ingredientName: line.ingredientName,
  neededByItem: neededByItem,
  today: today,
);

bool _isDelayed({
  required IngredientState state,
  required String? supplierCategoryId,
  required String? ingredientId,
  required String ingredientName,
  required Map<String, DateTime> neededByItem,
  required DateTime today,
}) {
  if (state != IngredientState.ordered) return false;
  final needed =
      neededByItem[_itemKey(supplierCategoryId, ingredientId, ingredientName)];
  if (needed == null) return false;
  return today.isAfter(needed);
}
