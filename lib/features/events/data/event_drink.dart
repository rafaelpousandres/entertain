/// Read model for an `event_drinks` row — the per-event snapshot of a catalog
/// drink (Spec 014 §2.3, refined by Spec 016 §3). Units-only: a drink does not
/// have servings and does not scale by guests. The user sets the **quantity of
/// units** directly; it becomes a single purchase line in Shopping.
///
/// `sourceDrinkId` is provenance only (used to flag a drink already in the
/// menu); the snapshot never re-reads the catalog.
library;

import '../../catalog/data/denomination.dart';

/// The default unit quantity for a drink added to an event (no guest scaling —
/// Spec 016 §3.1). Matches the `event_drinks.quantity` column default.
const int defaultEventDrinkQuantity = 1;

class EventDrink {
  const EventDrink({
    required this.id,
    required this.name,
    required this.quantity,
    required this.sortOrder,
    this.sourceDrinkId,
    this.supplierCategoryId,
    this.denomination = 'bottle',
  });

  final String id;
  final String name;

  /// Number of units to buy, set manually (no guest scaling, Spec 016 §3.1).
  final int quantity;
  final int sortOrder;
  final String? sourceDrinkId;

  /// Snapshot of the drink's supplier category (resolved to a concrete supplier
  /// at order time, Spec 013) and its denomination code.
  final String? supplierCategoryId;
  final String denomination;

  factory EventDrink.fromRow(Map<String, dynamic> row) {
    return EventDrink(
      id: row['id'] as String,
      name: row['drink_name'] as String,
      quantity: (row['quantity'] as num?)?.toInt() ?? defaultEventDrinkQuantity,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      sourceDrinkId: row['source_drink_id'] as String?,
      supplierCategoryId: row['supplier_category_id'] as String?,
      denomination: parseDenomination(row['denomination'] as String?).wire,
    );
  }

  static const String selectColumns =
      'id, drink_name, quantity, sort_order, source_drink_id, '
      'supplier_category_id, denomination';
}
