/// Read models for the event shopping panel (Specification 005 §2.3–§2.4).
///
/// A [ShoppingLine] is one of an event's `event_dish_ingredients` rows seen
/// through the shopping lens — only the fields the panel and the message
/// composer need, carrying the effective `supplierCategoryId` (the snapshot
/// value at the line, including any per-event override from Spec 004).
///
/// A [SupplierOrder] is a materialised `orders` row with its frozen
/// [OrderItem] snapshot. Orders are immutable history here: once sent, later
/// menu edits never touch them (the copy-on-send pattern, analogous to the
/// copy-on-add of Spec 004).
library;

import 'ingredient_state.dart';
import 'message_channel.dart';

/// What an event item is, for the shopping pipeline (Spec 014 §2.5). An
/// `ingredient` line comes from `event_dish_ingredients` and scales/aggregates
/// as before; `preparedDish` and `drink` are single purchase lines built from a
/// bought `event_dishes` / an `event_drinks` row, never decomposed or merged.
enum ShoppingLineKind { ingredient, preparedDish, drink }

/// A row id paired with its [ShoppingLineKind], so a state change knows which
/// table to update: `event_dish_ingredients` (ingredient) or the bought
/// `event_dishes` / `event_drinks` row (purchase lines, Spec 014).
class ShoppingLineRef {
  const ShoppingLineRef(this.id, this.kind);
  final String id;
  final ShoppingLineKind kind;
}

class ShoppingLine {
  const ShoppingLine({
    required this.id,
    required this.ingredientName,
    required this.quantity,
    required this.state,
    this.unitId,
    this.kind = ShoppingLineKind.ingredient,
    this.denomination,
    this.ingredientId,
    this.prepNote,
    this.supplierCategoryId,
    this.isExtra = false,
  });

  /// The originating row id: `event_dish_ingredients.id` for ingredients, or the
  /// `event_dishes` / `event_drinks` id for a purchase line.
  final String id;
  final String? ingredientId;
  final String ingredientName;
  final double quantity;

  /// `units.id` for ingredient lines; null for purchase lines, which carry a
  /// free-text [purchaseUnitLabel] instead (or none, showing scaled servings).
  final String? unitId;

  final ShoppingLineKind kind;

  /// Denomination code for a drink line (Spec 016 §3.3), rendered to a localised
  /// noun by [denominationUnitNoun]. Null for ingredient and prepared-dish lines
  /// (a prepared dish shows a bare count, "3 × name").
  final String? denomination;

  final String? prepNote;

  /// Effective supplier assignment for this line; null lines are not part of
  /// any supplier section (they have no destination yet).
  final String? supplierCategoryId;

  /// Where this line is in the shopping process (Spec 007 §3.1). For an extra
  /// (Spec 011 §2.11) the state is not meaningful — extras carry no status.
  final IngredientState state;

  /// Spec 011 §2.11 — true when this line belongs to the event's phantom
  /// "extras" dish: an item piggybacked onto a supplier's order that is not part
  /// of any real dish. Extras never aggregate (with managed lines or each
  /// other), are excluded from status counters, and render with an "Extra"
  /// badge instead of a state.
  final bool isExtra;

  /// A prepared-dish / drink purchase line (vs. an ingredient line).
  bool get isPurchaseItem => kind != ShoppingLineKind.ingredient;

  factory ShoppingLine.fromRow(Map<String, dynamic> row) {
    return ShoppingLine(
      id: row['id'] as String,
      ingredientId: row['ingredient_id'] as String?,
      ingredientName: row['ingredient_name'] as String,
      quantity: (row['quantity'] as num).toDouble(),
      unitId: row['unit_id'] as String,
      prepNote: row['prep_note'] as String?,
      supplierCategoryId: row['supplier_category_id'] as String?,
      state: IngredientState.parse(row['state'] as String?),
    );
  }
}

class OrderItem {
  const OrderItem({
    required this.id,
    required this.ingredientName,
    required this.quantity,
    required this.unitId,
    this.ingredientId,
    this.prepNote,
  });

  final String id;
  final String? ingredientId;
  final String ingredientName;
  final double quantity;
  final String unitId;
  final String? prepNote;

  factory OrderItem.fromRow(Map<String, dynamic> row) {
    return OrderItem(
      id: row['id'] as String,
      ingredientId: row['ingredient_id'] as String?,
      ingredientName: row['ingredient_name'] as String,
      quantity: (row['quantity'] as num).toDouble(),
      unitId: row['unit_id'] as String,
      prepNote: row['prep_note'] as String?,
    );
  }
}

class SupplierOrder {
  const SupplierOrder({
    required this.id,
    required this.supplierCategoryId,
    required this.items,
    this.sentAt,
    this.sentChannel,
    this.sentAddress,
    this.neededByDate,
  });

  final String id;
  final String supplierCategoryId;
  final DateTime? sentAt;
  final MessageChannel? sentChannel;
  final String? sentAddress;

  /// Date the goods are required by (Spec 005 §2.6). A date-only value; used to
  /// derive the "Retrassat" overlay (Fixes round 2 §2.2).
  final DateTime? neededByDate;
  final List<OrderItem> items;

  factory SupplierOrder.fromRow(Map<String, dynamic> row) {
    final rawItems = (row['order_items'] as List?) ?? const [];
    return SupplierOrder(
      id: row['id'] as String,
      supplierCategoryId: row['supplier_category_id'] as String,
      sentAt: row['sent_at'] == null
          ? null
          : DateTime.parse(row['sent_at'] as String),
      sentChannel: MessageChannelWire.parse(row['sent_channel'] as String?),
      sentAddress: row['sent_address'] as String?,
      // `date` column comes back as 'YYYY-MM-DD'; parse to a local date-only.
      neededByDate: row['needed_by_date'] == null
          ? null
          : DateTime.parse(row['needed_by_date'] as String),
      items: [
        for (final r in rawItems) OrderItem.fromRow(r as Map<String, dynamic>),
      ],
    );
  }
}

/// The full shopping picture for one event: every line (across all dishes)
/// and every materialised order. Grouping by category and delta computation
/// are derived from this in [shopping_delta.dart], so the panel and the
/// message composer share one source of truth.
class EventShopping {
  const EventShopping({required this.lines, required this.orders});

  final List<ShoppingLine> lines;
  final List<SupplierOrder> orders;
}
