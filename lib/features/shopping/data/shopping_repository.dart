import 'package:supabase_flutter/supabase_flutter.dart';

import 'ingredient_state.dart';
import 'message_channel.dart';
import 'shopping_models.dart';

/// Data-access wrapper for the event shopping panel and supplier messages
/// (Specification 005). Reads the event's ingredient lines and materialised
/// orders, and writes a new order with its frozen item snapshot on send.
///
/// Row-level security (spec 002) scopes `event_dish_ingredients`, `orders`
/// and `order_items` to the caller's group through their parent event.
class ShoppingRepository {
  ShoppingRepository(this._client);

  final SupabaseClient _client;

  /// All `event_dish_ingredients` of an event, across every dish, carrying
  /// the effective `supplier_category_id`. The event link is expressed
  /// through an inner join on `event_dishes`.
  Future<List<ShoppingLine>> listEventLines(String eventId) async {
    final rows = await _client
        .from('event_dish_ingredients')
        .select(
          'id, ingredient_id, ingredient_name, quantity, unit_id, prep_note, '
          'supplier_category_id, state, sort_order, event_dishes!inner(event_id)',
        )
        .eq('event_dishes.event_id', eventId)
        .order('sort_order', ascending: true);
    return [
      for (final r in rows as List)
        ShoppingLine.fromRow(r as Map<String, dynamic>),
    ];
  }

  /// Materialised orders for an event with their frozen items.
  Future<List<SupplierOrder>> listEventOrders(String eventId) async {
    final rows = await _client
        .from('orders')
        .select(
          'id, supplier_category_id, sent_at, sent_channel, sent_address, '
          'needed_by_date, '
          'order_items(id, ingredient_id, ingredient_name, quantity, '
          'unit_id, prep_note)',
        )
        .eq('event_id', eventId);
    return [
      for (final r in rows as List)
        SupplierOrder.fromRow(r as Map<String, dynamic>),
    ];
  }

  /// Copy-on-send (Spec §2.4, analogous to copy-on-add of Spec 004).
  ///
  /// Creates one `orders` row for `(eventId, supplierCategoryId)` stamped as
  /// sent, then one `order_items` row per delta line — a true snapshot, so
  /// later menu edits never reach the order. The actual channel / address
  /// used (configured, overridden, or whatever the share sheet handled) is
  /// persisted on the order.
  Future<void> createSentOrder({
    required String eventId,
    required String supplierCategoryId,
    required MessageChannel? channel,
    required String? address,
    required DateTime sentAt,
    required DateTime? neededByDate,
    required List<ShoppingLine> items,
  }) async {
    final order = await _client
        .from('orders')
        .insert({
          'event_id': eventId,
          'supplier_category_id': supplierCategoryId,
          'status': 'sent',
          'sent_at': sentAt.toUtc().toIso8601String(),
          'sent_channel': channel?.wire,
          'sent_address': address,
          // Date-only column (Fixes §2.6): send just the calendar date, with no
          // time or zone, so it is not shifted by UTC conversion.
          'needed_by_date': neededByDate == null
              ? null
              : _dateOnly(neededByDate),
        })
        .select('id')
        .single();
    final orderId = order['id'] as String;

    if (items.isEmpty) return;
    final payload = [
      for (var i = 0; i < items.length; i++)
        {
          'order_id': orderId,
          'ingredient_id': items[i].ingredientId,
          'ingredient_name': items[i].ingredientName,
          'quantity': items[i].quantity,
          'unit_id': items[i].unitId,
          'prep_note': items[i].prepNote,
          'sort_order': i,
        },
    ];
    await _client.from('order_items').insert(payload);
  }

  /// Moves one ingredient line to a new state (Spec 007 §3.3). A direct
  /// update on `event_dish_ingredients`; RLS scopes it to the caller's group
  /// through the parent event.
  Future<void> updateLineState(
    String lineId,
    IngredientState state,
  ) async {
    await _client
        .from('event_dish_ingredients')
        .update({'state': state.wire})
        .eq('id', lineId);
  }

  /// Moves a set of lines to a new state in one round-trip — used by the
  /// "send → ordered" transition (Spec 007 §3.2) and the per-supplier bulk
  /// "mark all as received" action (Spec 007 §3.3). No-op for an empty list.
  Future<void> updateLineStates(
    List<String> lineIds,
    IngredientState state,
  ) async {
    if (lineIds.isEmpty) return;
    await _client
        .from('event_dish_ingredients')
        .update({'state': state.wire})
        .inFilter('id', lineIds);
  }

  /// `YYYY-MM-DD` for a `date` column, taking the local calendar date.
  static String _dateOnly(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
