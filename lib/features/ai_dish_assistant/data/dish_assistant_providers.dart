import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../events/data/events_providers.dart' show currentGroupIdProvider;
import '../../stock_photos/data/quota.dart' show QuotaStatus;
import 'dish_assistant_repository.dart';

/// Spec 020 — the dish-assistant repository (Anthropic via the Edge Function).
final dishAssistantRepositoryProvider = Provider<DishAssistantRepository>((ref) {
  return DishAssistantRepository(Supabase.instance.client);
});

/// The current group's dish-assistant usage for this month. Invalidated after a
/// successful save so the "N de 3" header updates live.
final dishAssistantQuotaProvider = FutureProvider<QuotaStatus>((ref) async {
  final groupId = await ref.watch(currentGroupIdProvider.future);
  return ref.watch(dishAssistantRepositoryProvider).fetchQuota(groupId);
});
