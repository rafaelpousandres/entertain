import 'package:supabase_flutter/supabase_flutter.dart';

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
          'supplier_category_id, sort_order, event_dishes!inner(event_id)',
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
}
