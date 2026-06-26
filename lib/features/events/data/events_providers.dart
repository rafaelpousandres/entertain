import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'event.dart';
import 'event_dish.dart';
import 'event_dish_line.dart';
import 'event_drink.dart';
import 'event_guest.dart';
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

/// Drinks attached to an event (Spec 014), for the Menu's Begudes section.
final eventDrinksProvider = FutureProvider.family<List<EventDrink>, String>((
  ref,
  eventId,
) async {
  return ref.watch(eventsRepositoryProvider).listEventDrinks(eventId);
});

/// Guests attached to an event (Spec 023 Layer 1), for the Convidats tab.
/// Invalidated after any guest mutation so the accordion/totals stay live.
final eventGuestsProvider = FutureProvider.family<List<EventGuest>, String>((
  ref,
  eventId,
) async {
  return ref.watch(eventsRepositoryProvider).listEventGuests(eventId);
});

final eventDrinkByIdProvider = FutureProvider.family<EventDrink, String>((
  ref,
  eventDrinkId,
) async {
  return ref.watch(eventsRepositoryProvider).fetchEventDrink(eventDrinkId);
});

/// The editable ingredient lines of a per-event dish. Invalidated after any
/// per-event line mutation.
final eventDishLinesProvider =
    FutureProvider.family<List<EventDishLine>, String>((ref, eventDishId) async {
      return ref
          .watch(eventsRepositoryProvider)
          .listEventDishLines(eventDishId);
    });
