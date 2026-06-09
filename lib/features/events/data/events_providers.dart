import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../photos/data/event_photo.dart';
import 'event.dart';
import 'event_dish.dart';
import 'event_dish_line.dart';
import 'events_repository.dart';

final _supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  return EventsRepository(ref.watch(_supabaseClientProvider));
});

/// The current user's group. Resolved once per session via the auto-
/// provisioned membership created by the spec 002 trigger.
final currentGroupIdProvider = FutureProvider<String>((ref) async {
  final repo = ref.watch(eventsRepositoryProvider);
  return repo.currentGroupId();
});

/// Active events for the current group. The list is invalidated after
/// any mutation so the home reflects the latest state without a restart.
final eventsListProvider = FutureProvider<List<Event>>((ref) async {
  final repo = ref.watch(eventsRepositoryProvider);
  final groupId = await ref.watch(currentGroupIdProvider.future);
  return repo.listEventsForGroup(groupId);
});

/// Per-event ingredient readiness for the current group (Spec 008 §2.4), used
/// to derive each event's status on the list and detail header. Invalidated by
/// the same mutations that change ingredient states or the menu.
final eventReadinessProvider =
    FutureProvider<Map<String, ({int total, int notReady})>>((ref) async {
  final repo = ref.watch(eventsRepositoryProvider);
  final groupId = await ref.watch(currentGroupIdProvider.future);
  return repo.eventReadiness(groupId);
});

final eventByIdProvider = FutureProvider.family<Event, String>((ref, id) async {
  final repo = ref.watch(eventsRepositoryProvider);
  return repo.fetchEvent(id);
});

final eventDishesProvider = FutureProvider.family<List<EventDish>, String>((
  ref,
  eventId,
) async {
  final repo = ref.watch(eventsRepositoryProvider);
  return repo.listEventDishes(eventId);
});

/// A single per-event dish (snapshot fields) for the per-event dish detail.
final eventDishByIdProvider = FutureProvider.family<EventDish, String>((
  ref,
  eventDishId,
) async {
  return ref.watch(eventsRepositoryProvider).fetchEventDish(eventDishId);
});

/// The editable ingredient lines of a per-event dish. Invalidated after any
/// per-event line mutation.
final eventDishLinesProvider =
    FutureProvider.family<List<EventDishLine>, String>((ref, eventDishId) async {
      return ref
          .watch(eventsRepositoryProvider)
          .listEventDishLines(eventDishId);
    });

/// An event's photo album in carousel order (Spec 009 §2.2). Invalidated after
/// adding or removing a photo.
final eventPhotosProvider = FutureProvider.family<List<EventPhoto>, String>((
  ref,
  eventId,
) async {
  return ref.watch(eventsRepositoryProvider).listEventPhotos(eventId);
});

/// The first photo (object path) of every event in the current group that has
/// one (Spec 009 §6.2), for the recall thumbnail on the events-list cards.
/// Fetched in a single query (no N+1) and invalidated whenever an album changes
/// (add / remove / reorder), since the first photo may have changed.
final eventFirstPhotosProvider = FutureProvider<Map<String, String>>((
  ref,
) async {
  final repo = ref.watch(eventsRepositoryProvider);
  final groupId = await ref.watch(currentGroupIdProvider.future);
  return repo.firstPhotoPathByEvent(groupId);
});
