import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'event.dart';
import 'event_dish.dart';
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
