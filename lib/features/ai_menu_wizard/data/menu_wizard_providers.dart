import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../ai_dish_assistant/data/dish_assistant_providers.dart'
    show dishAssistantRepositoryProvider;
import '../../events/data/events_providers.dart'
    show currentGroupIdProvider, eventsRepositoryProvider;
import '../../stock_photos/data/quota.dart' show QuotaStatus;
import 'menu_wizard_repository.dart';

/// Spec 022 — the menu-wizard repository. Composes the `menu-wizard` Edge
/// Function (propose) with the reused dish-assistant save + events repository
/// (accept), so persistence stays in its single tested home.
final menuWizardRepositoryProvider = Provider<MenuWizardRepository>((ref) {
  return MenuWizardRepository(
    Supabase.instance.client,
    ref.watch(dishAssistantRepositoryProvider),
    ref.watch(eventsRepositoryProvider),
  );
});

/// The current group's menu-wizard usage for this month. Invalidated after a
/// successful propose so the "N de 2" header updates live.
final menuWizardQuotaProvider = FutureProvider<QuotaStatus>((ref) async {
  final groupId = await ref.watch(currentGroupIdProvider.future);
  return ref.watch(menuWizardRepositoryProvider).fetchQuota(groupId);
});
