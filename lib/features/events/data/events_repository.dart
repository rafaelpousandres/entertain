import 'package:supabase_flutter/supabase_flutter.dart';

import 'event.dart';
import 'event_dish.dart';
import 'event_dish_line.dart';
import 'event_draft.dart';

/// Thin data-access wrapper around the `events` table. Keeps the Supabase
/// SDK calls in one place so screens and providers can stay declarative.
///
/// Every method relies on the row-level security set up in spec 002: the
/// authenticated anonymous user only sees / mutates rows belonging to
/// groups they are a member of.
class EventsRepository {
  EventsRepository(this._client);

  final SupabaseClient _client;

  /// Returns the group id the current user owns. With Phase 0 auto-
  /// provisioning, every authenticated user has exactly one membership;
  /// taking the first row is correct here.
  Future<String> currentGroupId() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user.');
    }
    final row = await _client
        .from('memberships')
        .select('group_id')
        .eq('user_id', user.id)
        .limit(1)
        .maybeSingle();
    if (row == null) {
      throw StateError('No membership for the current user.');
    }
    return row['group_id'] as String;
  }

  /// Active events (not soft-deleted) for the given group, sorted so the
  /// list screen can render the agreed order — upcoming events ascending,
  /// past events descending, dateless events at the end by created_at desc.
  /// Sorting is finished client-side because Postgres can't express the
  /// "split by today and reverse one side" rule in a single `order by`.
  Future<List<Event>> listEventsForGroup(String groupId) async {
    final rows = await _client
        .from('events')
        .select(Event.selectColumns)
        .eq('group_id', groupId)
        .filter('deleted_at', 'is', null);

    final events = (rows as List)
        .map((r) => Event.fromRow(r as Map<String, dynamic>))
        .toList();

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    int order(Event a, Event b) {
      final aDate = a.eventDate;
      final bDate = b.eventDate;

      // Dateless events sink to the bottom, then ordered by created_at desc.
      if (aDate == null && bDate == null) {
        return b.createdAt.compareTo(a.createdAt);
      }
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      final aUpcoming = !aDate.isBefore(todayDate);
      final bUpcoming = !bDate.isBefore(todayDate);

      if (aUpcoming && !bUpcoming) return -1;
      if (!aUpcoming && bUpcoming) return 1;

      // Upcoming: soonest first. Past: most recent first.
      return aUpcoming ? aDate.compareTo(bDate) : bDate.compareTo(aDate);
    }

    events.sort(order);
    return events;
  }

  Future<Event> fetchEvent(String id) async {
    final row = await _client
        .from('events')
        .select(Event.selectColumns)
        .eq('id', id)
        .filter('deleted_at', 'is', null)
        .maybeSingle();
    if (row == null) {
      throw StateError('Event not found.');
    }
    return Event.fromRow(row);
  }

  Future<Event> createEvent(EventDraft draft, {required String groupId}) async {
    final row = await _client
        .from('events')
        .insert({...draft.toRow(), 'group_id': groupId})
        .select(Event.selectColumns)
        .single();
    return Event.fromRow(row);
  }

  Future<Event> updateEvent(String id, EventDraft draft) async {
    final row = await _client
        .from('events')
        .update(draft.toRow())
        .eq('id', id)
        .select(Event.selectColumns)
        .single();
    return Event.fromRow(row);
  }

  /// Soft delete. The data model marks `events` with 🗑, so deletion sets
  /// `deleted_at` rather than removing the row.
  Future<void> deleteEvent(String id) async {
    await _client
        .from('events')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  /// Dishes attached to an event, ordered by `sort_order`.
  Future<List<EventDish>> listEventDishes(String eventId) async {
    final rows = await _client
        .from('event_dishes')
        .select(EventDish.selectColumns)
        .eq('event_id', eventId)
        .order('sort_order', ascending: true);
    return (rows as List)
        .map((r) => EventDish.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<EventDish> fetchEventDish(String eventDishId) async {
    final row = await _client
        .from('event_dishes')
        .select(EventDish.selectColumns)
        .eq('id', eventDishId)
        .maybeSingle();
    if (row == null) {
      throw StateError('Event dish not found.');
    }
    return EventDish.fromRow(row);
  }

  Future<List<EventDishLine>> listEventDishLines(String eventDishId) async {
    final rows = await _client
        .from('event_dish_ingredients')
        .select(EventDishLine.selectColumns)
        .eq('event_dish_id', eventDishId)
        .order('sort_order', ascending: true);
    return (rows as List)
        .map((r) => EventDishLine.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// Copy on add (Specification 004 §3.7 / data model §3.3). Materialises an
  /// independent per-event copy of a catalog dish:
  ///
  /// - one `event_dishes` row snapshotting the dish `name` and `category`,
  ///   with `servings` initialised from the event's `guest_count` and
  ///   `source_dish_id` kept as provenance only;
  /// - one `event_dish_ingredients` row per `dish_ingredients` line of the
  ///   source dish, snapshotting the current ingredient name and the
  ///   ingredient's `default_supplier_category_id`, and copying quantity,
  ///   unit, prep note and sort order.
  ///
  /// Every value is read fresh here so the snapshot reflects the catalog at
  /// the moment of adding; nothing is read back afterwards, so later catalog
  /// edits never propagate to the event. The inserts mirror the catalog
  /// dish editor's non-transactional client-side pattern.
  Future<void> addDishToEvent({
    required String eventId,
    required String dishId,
  }) async {
    final event = await _client
        .from('events')
        .select('guest_count')
        .eq('id', eventId)
        .single();
    final dish = await _client
        .from('dishes')
        .select('name, category')
        .eq('id', dishId)
        .single();
    final sourceLines = await _client
        .from('dish_ingredients')
        .select(
          'ingredient_id, quantity, unit_id, prep_note, sort_order, '
          'ingredients(name, default_supplier_category_id)',
        )
        .eq('dish_id', dishId)
        .order('sort_order', ascending: true);
    final existing = await _client
        .from('event_dishes')
        .select('id')
        .eq('event_id', eventId);

    final eventDish = await _client
        .from('event_dishes')
        .insert({
          'event_id': eventId,
          'source_dish_id': dishId,
          'dish_name': dish['name'],
          'category': dish['category'],
          'servings': (event['guest_count'] as num).toInt(),
          'sort_order': (existing as List).length,
        })
        .select('id')
        .single();
    final eventDishId = eventDish['id'] as String;

    final lines = sourceLines as List;
    if (lines.isEmpty) return;
    final payload = [
      for (final raw in lines)
        () {
          final line = raw as Map<String, dynamic>;
          final ingredient = line['ingredients'] as Map<String, dynamic>?;
          return {
            'event_dish_id': eventDishId,
            'ingredient_id': line['ingredient_id'],
            'ingredient_name': (ingredient?['name'] as String?) ?? '',
            'quantity': line['quantity'],
            'unit_id': line['unit_id'],
            'prep_note': line['prep_note'],
            'supplier_category_id':
                ingredient?['default_supplier_category_id'],
            'sort_order': line['sort_order'],
          };
        }(),
    ];
    await _client.from('event_dish_ingredients').insert(payload);
  }

  /// Adds a brand-new ad-hoc ingredient line to a per-event dish (Spec 006
  /// §2.2). Unlike [addDishToEvent], which copies the catalog recipe, this is
  /// a standalone line the user adds directly to this event's copy. The new
  /// `sort_order` appends after the existing lines so the line lands at the
  /// bottom of the list.
  Future<void> addEventDishLine(
    String eventDishId, {
    required String ingredientId,
    required String ingredientName,
    required double quantity,
    required String unitId,
    String? prepNote,
    String? supplierCategoryId,
  }) async {
    final existing = await _client
        .from('event_dish_ingredients')
        .select('sort_order')
        .eq('event_dish_id', eventDishId);
    var nextOrder = 0;
    for (final r in existing as List) {
      final so = ((r as Map<String, dynamic>)['sort_order'] as num?)?.toInt();
      if (so != null && so >= nextOrder) nextOrder = so + 1;
    }
    await _client.from('event_dish_ingredients').insert({
      'event_dish_id': eventDishId,
      'ingredient_id': ingredientId,
      'ingredient_name': ingredientName,
      'quantity': quantity,
      'unit_id': unitId,
      'prep_note': prepNote,
      'supplier_category_id': supplierCategoryId,
      'sort_order': nextOrder,
    });
  }

  Future<void> updateEventDishLine(
    String lineId, {
    required String ingredientId,
    required String ingredientName,
    required double quantity,
    required String unitId,
    String? prepNote,
    String? supplierCategoryId,
  }) async {
    await _client
        .from('event_dish_ingredients')
        .update({
          'ingredient_id': ingredientId,
          'ingredient_name': ingredientName,
          'quantity': quantity,
          'unit_id': unitId,
          'prep_note': prepNote,
          'supplier_category_id': supplierCategoryId,
        })
        .eq('id', lineId);
  }

  /// Physical delete — `event_dish_ingredients` is a per-event copy with no
  /// `deleted_at` (data model §3.3).
  Future<void> deleteEventDishLine(String lineId) async {
    await _client.from('event_dish_ingredients').delete().eq('id', lineId);
  }

  /// Removes a dish from an event's menu (Fixes §2.2).
  ///
  /// The schema declares `event_dish_ingredients.event_dish_id` with
  /// `on delete cascade`, so deleting the `event_dishes` row should remove its
  /// lines too. On-device validation, however, surfaced duplicate
  /// `event_dish_ingredients` rows after a remove-and-re-add cycle — the
  /// hallmark of a parent delete that did not take its children with it. To
  /// make cleanup independent of whether the cascade actually fires on the
  /// remote project, we delete the lines explicitly first and the parent
  /// after: if the cascade works the line delete is a harmless no-op; if it
  /// is somehow ineffective (a constraint that differs from the migration, an
  /// `on delete restrict` left in place) this both clears the children and
  /// removes the FK obstacle that would otherwise make the parent delete fail
  /// silently and leave a stale dish in the menu.
  Future<void> removeEventDish(String eventDishId) async {
    await _client
        .from('event_dish_ingredients')
        .delete()
        .eq('event_dish_id', eventDishId);
    await _client.from('event_dishes').delete().eq('id', eventDishId);
  }
}
