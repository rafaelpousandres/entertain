import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../events/data/events_providers.dart';
import 'suggestions_repository.dart';

final _supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final suggestionsRepositoryProvider = Provider<SuggestionsRepository>((ref) {
  return SuggestionsRepository(ref.watch(_supabaseClientProvider));
});

/// The authenticated user's id, stamped on each suggestion. Exposed as a
/// provider (rather than read from `Supabase.instance` inline) so the screen
/// stays testable without an initialised Supabase singleton.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(_supabaseClientProvider).auth.currentUser?.id;
});

/// Number of suggestions the current group has sent ("N suggeriments enviats").
/// Invalidated after a successful send so the counter bumps without a restart.
final suggestionsCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(suggestionsRepositoryProvider);
  final groupId = await ref.watch(currentGroupIdProvider.future);
  return repo.countForGroup(groupId);
});
