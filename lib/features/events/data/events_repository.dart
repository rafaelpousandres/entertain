import 'package:supabase_flutter/supabase_flutter.dart';

import 'event.dart';
import 'event_dish.dart';
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

  /// Dishes attached to an event. Spec 003 only reads them — adding /
  /// editing belongs to screen group 2.
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
}
