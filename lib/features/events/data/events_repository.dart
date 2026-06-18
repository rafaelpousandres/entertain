import 'package:supabase_flutter/supabase_flutter.dart';

import 'event.dart';
import 'event_dish.dart';
import 'event_dish_line.dart';
import 'event_draft.dart';
import 'event_drink.dart';

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

  /// Per-event ingredient readiness for the group (Spec 008 §2.4), used to
  /// derive each event's status without an N+1 of per-event queries. Returns a
  /// map of event id → (total lines, lines not yet at_home/received). Events
  /// with no lines are simply absent from the map. RLS already scopes the rows
  /// to the caller; the explicit group filter keeps it consistent with
  /// [listEventsForGroup].
  Future<Map<String, ({int total, int notReady})>> eventReadiness(
    String groupId,
  ) async {
    final rows = await _client
        .from('event_dish_ingredients')
        .select('state, event_dishes!inner(event_id, events!inner(group_id))')
        .eq('event_dishes.events.group_id', groupId)
        // Spec 011 §2.11: extras (the phantom dish) carry no status, so they
        // never contribute to an event's readiness.
        .eq('event_dishes.is_extras', false);

    final result = <String, ({int total, int notReady})>{};
    for (final r in rows as List) {
      final row = r as Map<String, dynamic>;
      final eventDish = row['event_dishes'] as Map<String, dynamic>?;
      final eventId = eventDish?['event_id'] as String?;
      if (eventId == null) continue;
      final state = row['state'] as String?;
      final ready = state == 'at_home' || state == 'received';
      final current = result[eventId] ?? (total: 0, notReady: 0);
      result[eventId] = (
        total: current.total + 1,
        notReady: current.notReady + (ready ? 0 : 1),
      );
    }
    return result;
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
  ///
  /// The event's `media` rows (Spec 010 §2.4) are removed by the caller via
  /// [MediaRepository.deleteForEntity] before the soft delete, which also
  /// returns the blob paths to purge — the AFTER DELETE cleanup trigger never
  /// fires on a soft delete, so the rows must be cleared explicitly.
  Future<void> deleteEvent(String id) async {
    await _client
        .from('events')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  /// Dishes attached to an event, ordered by `sort_order`. Spec 011 §2.11: the
  /// phantom "extras" dish is excluded — it is never shown in the Menu.
  Future<List<EventDish>> listEventDishes(String eventId) async {
    final rows = await _client
        .from('event_dishes')
        .select(EventDish.selectColumns)
        .eq('event_id', eventId)
        .eq('is_extras', false)
        .order('sort_order', ascending: true);
    return (rows as List)
        .map((r) => EventDish.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// Spec 011 §2.11 — the event's phantom "extras" dish, created lazily on first
  /// use. It holds extra shopping ingredients (items not tied to any real dish)
  /// through the normal `event_dish_ingredients` mechanism, but is hidden from
  /// the Menu and excluded from status. Returns its id, creating it if absent.
  ///
  /// `servings` is fixed at 1 (with extra lines stored against a reference of 1)
  /// so an extra's quantity is taken exactly as entered, never servings-scaled.
  Future<String> ensureExtrasDish(String eventId) async {
    final existing = await _client
        .from('event_dishes')
        .select('id')
        .eq('event_id', eventId)
        .eq('is_extras', true)
        .limit(1)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;
    final created = await _client
        .from('event_dishes')
        .insert({
          'event_id': eventId,
          'dish_name': '__extras__',
          'category': 'other',
          'servings': 1,
          'sort_order': 0,
          'is_extras': true,
        })
        .select('id')
        .single();
    return created['id'] as String;
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
        .select('guest_count, format')
        .eq('id', eventId)
        .single();
    final dish = await _client
        .from('dishes')
        .select(
          'name, category, base_servings, acquisition_mode, '
          'supplier_category_id',
        )
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

    // Spec 008 §2.10: the default servings depend on the event format —
    // seated events default to the guest count, buffet / other carry over the
    // master dish's own servings.
    final baseServings = (dish['base_servings'] as num?)?.toInt() ?? 4;
    final guestCount = (event['guest_count'] as num).toInt();
    final servings = (event['format'] as String?) == 'seated'
        ? guestCount
        : baseServings;
    final isBought = (dish['acquisition_mode'] as String?) == 'bought';

    final eventDish = await _client
        .from('event_dishes')
        .insert({
          'event_id': eventId,
          'source_dish_id': dishId,
          'dish_name': dish['name'],
          'category': dish['category'],
          'servings': servings,
          'sort_order': (existing as List).length,
          // Spec 014 §2.3: snapshot how the dish is obtained. A bought dish has
          // no ingredient lines, so the copy below is a no-op for it; its single
          // purchase line is derived in Shopping from these snapshot fields.
          'acquisition_mode': dish['acquisition_mode'],
          'supplier_category_id': dish['supplier_category_id'],
          // Spec 016 §2.1: freeze the per-unit value (base_servings = "servings
          // one unit provides") as the immutable snapshot, so the bought line's
          // units = ceil(servings / servings_per_unit) survive catalog edits.
          // Null for cooked dishes (they explode into ingredient lines instead).
          'servings_per_unit': isBought ? baseServings : null,
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
            // Spec 008 §2.10: the copied quantity is the immutable base, valid
            // for the master dish's base_servings; the effective quantity is
            // scaled to the event-dish servings at read time.
            'quantity': line['quantity'],
            'unit_id': line['unit_id'],
            'prep_note': line['prep_note'],
            'supplier_category_id': ingredient?['default_supplier_category_id'],
            'sort_order': line['sort_order'],
            'reference_servings': baseServings,
          };
        }(),
    ];
    await _client.from('event_dish_ingredients').insert(payload);
  }

  // --- Drinks on an event (Spec 014 §2.3) -------------------------------

  /// Drinks attached to an event, ordered by `sort_order`.
  Future<List<EventDrink>> listEventDrinks(String eventId) async {
    final rows = await _client
        .from('event_drinks')
        .select(EventDrink.selectColumns)
        .eq('event_id', eventId)
        .order('sort_order', ascending: true);
    return (rows as List)
        .map((r) => EventDrink.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<EventDrink> fetchEventDrink(String eventDrinkId) async {
    final row = await _client
        .from('event_drinks')
        .select(EventDrink.selectColumns)
        .eq('id', eventDrinkId)
        .maybeSingle();
    if (row == null) {
      throw StateError('Event drink not found.');
    }
    return EventDrink.fromRow(row);
  }

  /// Copy on add for a drink (mirror of [addDishToEvent], no ingredients).
  /// Spec 016 §3: a drink is units-only — no servings, no guest scaling. The
  /// quantity defaults to [defaultEventDrinkQuantity] and is edited per event.
  Future<void> addDrinkToEvent({
    required String eventId,
    required String drinkId,
  }) async {
    final drink = await _client
        .from('drinks')
        .select('name, supplier_category_id, denomination')
        .eq('id', drinkId)
        .single();
    final existing = await _client
        .from('event_drinks')
        .select('id')
        .eq('event_id', eventId);

    await _client.from('event_drinks').insert({
      'event_id': eventId,
      'source_drink_id': drinkId,
      'drink_name': drink['name'],
      'supplier_category_id': drink['supplier_category_id'],
      'denomination': drink['denomination'],
      'quantity': defaultEventDrinkQuantity,
      'sort_order': (existing as List).length,
    });
  }

  Future<void> updateEventDrinkQuantity(
    String eventDrinkId,
    int quantity,
  ) async {
    await _client
        .from('event_drinks')
        .update({'quantity': quantity})
        .eq('id', eventDrinkId);
  }

  Future<void> deleteEventDrink(String eventDrinkId) async {
    await _client.from('event_drinks').delete().eq('id', eventDrinkId);
  }

  /// Duplicates an event as a starting point for a new one (Spec 009 §2.1).
  ///
  /// Copies the **menu structure** — every `event_dishes` row (with its
  /// `servings`, category and dish-name snapshot) and every
  /// `event_dish_ingredients` line (ingredient reference and name snapshot,
  /// `quantity`, the immutable `reference_servings` base per Spec 008 §2.10,
  /// `prep_note`, per-line `supplier_category_id` override and `sort_order`) —
  /// while **resetting** the fields that should start fresh:
  ///
  /// - the new event has **no date** and inherits only `type`, `format` and
  ///   `guest_count`; `status` falls back to its column default;
  /// - every line is reset to its **initial state**: `to_order` for ordinary
  ///   categories, `missing` for the Rebost (pantry). The state is written
  ///   explicitly so the copy never carries over a procured `received` /
  ///   `at_home` / `ordered` value — the duplicate starts as if nothing had
  ///   been procured yet. (The BEFORE INSERT default-state trigger only acts
  ///   on the inserted default `to_order`, so the explicit values pass through
  ///   untouched.)
  /// - **no orders** and **no photos** are copied — orders belong to the source
  ///   event and the new event generates its own.
  ///
  /// The localized name ("Copia de …") is built by the caller, which has the
  /// l10n context, and passed in as [newTitle]. Returns the new event id so the
  /// caller can navigate to it. The inserts mirror the non-transactional
  /// client-side pattern used by [addDishToEvent].
  Future<String> duplicateEvent({
    required String sourceEventId,
    required String newTitle,
    required String groupId,
  }) async {
    final source = await _client
        .from('events')
        .select('type, format, guest_count')
        .eq('id', sourceEventId)
        .single();

    final newEvent = await _client
        .from('events')
        .insert({
          'group_id': groupId,
          'title': newTitle,
          'type': source['type'],
          'format': source['format'],
          'guest_count': source['guest_count'],
          // event_date left null (§2.1): the user picks one on the copy.
        })
        .select('id')
        .single();
    final newEventId = newEvent['id'] as String;

    // Pantry category ids, so the lines that resolve to the Rebost reset to
    // `missing` rather than `to_order` (§2.1). `code = 'pantry'` is shared
    // system content; a group could only ever resolve to the one system row,
    // but a set keeps the membership test robust.
    final pantryRows = await _client
        .from('supplier_categories')
        .select('id')
        .eq('code', 'pantry');
    final pantryIds = {
      for (final r in pantryRows as List) (r as Map<String, dynamic>)['id'],
    };

    final dishes = await _client
        .from('event_dishes')
        .select('source_dish_id, dish_name, category, servings, sort_order, id')
        .eq('event_id', sourceEventId)
        // Spec 011 §2.11: the phantom "extras" dish is per-event shopping state,
        // not menu structure, so a duplicate starts without the source's extras.
        .eq('is_extras', false)
        .order('sort_order', ascending: true);

    for (final raw in dishes as List) {
      final dish = raw as Map<String, dynamic>;
      final newDish = await _client
          .from('event_dishes')
          .insert({
            'event_id': newEventId,
            'source_dish_id': dish['source_dish_id'],
            'dish_name': dish['dish_name'],
            'category': dish['category'],
            'servings': dish['servings'],
            'sort_order': dish['sort_order'],
          })
          .select('id')
          .single();
      final newDishId = newDish['id'] as String;

      final lines = await _client
          .from('event_dish_ingredients')
          .select(
            'ingredient_id, ingredient_name, quantity, unit_id, prep_note, '
            'supplier_category_id, sort_order, reference_servings',
          )
          .eq('event_dish_id', dish['id'])
          .order('sort_order', ascending: true);

      final list = lines as List;
      if (list.isEmpty) continue;
      final payload = [
        for (final lineRaw in list)
          () {
            final line = lineRaw as Map<String, dynamic>;
            final categoryId = line['supplier_category_id'];
            final isPantry =
                categoryId != null && pantryIds.contains(categoryId);
            return {
              'event_dish_id': newDishId,
              'ingredient_id': line['ingredient_id'],
              'ingredient_name': line['ingredient_name'],
              'quantity': line['quantity'],
              'unit_id': line['unit_id'],
              'prep_note': line['prep_note'],
              'supplier_category_id': categoryId,
              'sort_order': line['sort_order'],
              'reference_servings': line['reference_servings'],
              // §2.1 reset: fresh procurement state regardless of the source.
              'state': isPantry ? 'missing' : 'to_order',
            };
          }(),
      ];
      await _client.from('event_dish_ingredients').insert(payload);
    }

    return newEventId;
  }

  /// Updates an event-dish's servings (Spec 008 §2.10). The per-line quantities
  /// are not rewritten — they are immutable bases scaled to this value on read —
  /// so a round-trip of the servings returns the exact original quantities.
  Future<void> updateEventDishServings(String eventDishId, int servings) async {
    await _client
        .from('event_dishes')
        .update({'servings': servings})
        .eq('id', eventDishId);
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
    required int referenceServings,
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
      // Spec 008 §2.10: an ad-hoc line's base quantity is the value typed for
      // the event-dish's servings at the time it is added — its own reference.
      'quantity': quantity,
      'unit_id': unitId,
      'prep_note': prepNote,
      'supplier_category_id': supplierCategoryId,
      'sort_order': nextOrder,
      'reference_servings': referenceServings,
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
    required int referenceServings,
  }) async {
    await _client
        .from('event_dish_ingredients')
        .update({
          'ingredient_id': ingredientId,
          'ingredient_name': ingredientName,
          // Spec 008 §2.10: a manual quantity edit rebases the line to the
          // current servings, which become its new scaling reference.
          'quantity': quantity,
          'unit_id': unitId,
          'prep_note': prepNote,
          'supplier_category_id': supplierCategoryId,
          'reference_servings': referenceServings,
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
